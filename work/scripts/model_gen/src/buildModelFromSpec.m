function modelName = buildModelFromSpec(spec, saveDir)
% buildModelFromSpec  Build a Simulink model from a structured specification
%   Creates a Simulink model with ports, subsystems, and basic logic
%   defined in a spec struct or JSON file. Use for batch/standardized
%   model generation. For ad-hoc models, use /buildModel slash command instead.
%
%   Inputs:
%       spec     - Struct or path to JSON file with model specification
%       saveDir  - Output directory (default: current dir)
%
%   Usage:
%       % Define spec inline
%       spec = struct();
%       spec.modelName = 'MyController';
%       spec.solver.type = 'FixedStepDiscrete';
%       spec.solver.fixedStep = '0.01';
%       spec.inputs = struct('name', {'SensorA', 'SensorB'}, 'dataType', {'double', 'double'});
%       spec.outputs = struct('name', {'Actuator'}, 'dataType', {'double'});
%       spec.subsystems = struct('name', {}, 'description', {});
%       buildModelFromSpec(spec);
%
%       % Load from JSON file
%       buildModelFromSpec('path/to/model_spec.json');

    fprintf('=== Build Model From Specification ===\n\n');

    %% Parse input
    if ischar(spec) || isstring(spec)
        % Load from JSON file
        specFile = char(spec);
        if ~isfile(specFile)
            error('Spec file not found: %s', specFile);
        end
        jsonStr = fileread(specFile);
        spec = jsondecode(jsonStr);
        fprintf('Loaded spec from: %s\n', specFile);
    end

    if nargin < 2
        saveDir = pwd;
    end

    %% Extract spec fields with defaults
    modelName = getField(spec, 'modelName', 'Untitled');
    solverType = getField(spec, 'solver.type', 'FixedStepDiscrete');
    fixedStep = getField(spec, 'solver.fixedStep', '0.01');
    stopTime = getField(spec, 'solver.stopTime', '100');

    inputs = getField(spec, 'inputs', struct([]));
    if isempty(inputs)
        inputs = struct('name', {}, 'dataType', {});
    end
    if ~isfield(inputs, 'dataType')
        [inputs.dataType] = deal('single');
    end

    outputs = getField(spec, 'outputs', struct([]));
    if isempty(outputs)
        outputs = struct('name', {}, 'dataType', {});
    end
    if ~isfield(outputs, 'dataType')
        [outputs.dataType] = deal('single');
    end

    subsystems = getField(spec, 'subsystems', struct([]));
    if isempty(subsystems)
        subsystems = struct('name', {}, 'description', {});
    end

    constants = getField(spec, 'constants', struct([]));
    if isempty(constants)
        constants = struct('name', {}, 'value', {});
    end

    connections = getField(spec, 'connections', {});
    internalLogic = getField(spec, 'internalLogic', struct([]));

    %% Create model
    fprintf('[1/3] Creating model: %s\n', modelName);
    new_system(modelName);

    % Configure solver
    set_param(modelName, 'Solver', solverType);
    set_param(modelName, 'FixedStep', fixedStep);
    set_param(modelName, 'StopTime', stopTime);

    %% Add ports and blocks
    fprintf('[2/3] Adding %d inputs, %d outputs, %d subsystems...\n', ...
        numel(inputs), numel(outputs), numel(subsystems));

    % Add input ports
    yPos = 50;
    for i = 1:numel(inputs)
        blkName = inputs(i).name;
        add_block('simulink/Sources/In1', [modelName '/' blkName]);
        set_param([modelName '/' blkName], 'Position', [50, yPos, 80, yPos+20]);
        try set_param([modelName '/' blkName], 'OutDataTypeStr', inputs(i).dataType); catch, end
        yPos = yPos + 40;
    end

    % Add output ports
    yPos = 50;
    for i = 1:numel(outputs)
        blkName = outputs(i).name;
        add_block('simulink/Sinks/Out1', [modelName '/' blkName]);
        set_param([modelName '/' blkName], 'Position', [650, yPos, 680, yPos+20]);
        try set_param([modelName '/' blkName], 'OutDataTypeStr', outputs(i).dataType); catch, end
        yPos = yPos + 40;
    end

    % Add top-level wrapper subsystem; all logic lives inside it.
    wrapperName = 'MainSubsystem';
    add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/' wrapperName]);
    wrapperHeight = max(220, 90 + 35 * max([1, numel(inputs), numel(outputs), numel(subsystems)]));
    wrapperWidth = 320;
    wrapperLeft = 230;
    wrapperTop = max(40, 40 + 10 * abs(numel(inputs) - numel(outputs)));
    set_param([modelName '/' wrapperName], 'Position', [wrapperLeft, wrapperTop, wrapperLeft + wrapperWidth, wrapperTop + wrapperHeight]);
    set_param([modelName '/' wrapperName], 'Description', 'Top-level wrapper that contains the generated functional subsystems and internal logic.');

    wrapperPath = [modelName '/' wrapperName];
    createWrapperInterface(wrapperPath, inputs, outputs);

    % Add subsystems inside the wrapper
    subPos = 80;
    for i = 1:numel(subsystems)
        blkName = subsystems(i).name;
        add_block('simulink/Ports & Subsystems/Subsystem', [wrapperPath '/' blkName]);
        set_param([wrapperPath '/' blkName], 'Position', [200, subPos, 430, subPos+80]);
        setSubsystemDescription([wrapperPath '/' blkName], getDescription(subsystems(i), sprintf('Subsystem %s', blkName)));
        subPos = subPos + 120;
    end

    % Add constants inside the wrapper
    for i = 1:numel(constants)
        blkName = constants(i).name;
        add_block('simulink/Sources/Constant', [wrapperPath '/' blkName]);
        val = num2str(constants(i).value);
        set_param([wrapperPath '/' blkName], 'Value', val);
        set_param([wrapperPath '/' blkName], 'Position', [120, subPos, 190, subPos+20]);
        subPos = subPos + 40;
    end

    if isCentralLockFeedbackModel(modelName, subsystems)
        buildCentralLockFeedbackArchitecture(wrapperPath, inputs, outputs);
    end

    %% Apply connections inside the wrapper
    for i = 1:numel(connections)
        conn = connections{i};
        if ischar(conn) || isstring(conn)
            connStr = char(conn);
            parts = split(connStr, '->');
            if numel(parts) == 2
                src = strtrim(parts{1});
                dst = strtrim(parts{2});
                try
                    add_line(wrapperPath, [src '/1'], [dst '/1']);
                catch ME
                    fprintf('  ⚠ Connection failed: %s -> %s (%s)\n', src, dst, ME.message);
                end
            end
        end
    end

    %% Populate subsystem internal logic if specified
    for i = 1:numel(internalLogic)
        subName = internalLogic(i).subsystem;
        logicType = internalLogic(i).type;
        params = internalLogic(i);

        switch logicType
            case 'threshold'
                addThresholdLogic(wrapperPath, subName, params);
            case 'pid'
                addPIDLogic(wrapperPath, subName, params);
            case 'filter'
                addFilterLogic(wrapperPath, subName, params);
            otherwise
                fprintf('  ⚠ Unknown logic type: %s for %s\n', logicType, subName);
        end
    end

    % Connect top-level I/O ports to the wrapper subsystem by port index.
    connectTopLevelPorts(modelName, wrapperPath, inputs, outputs);
    Simulink.BlockDiagram.arrangeSystem(wrapperPath);

    %% Save
    fprintf('[3/3] Saving model...\n');
    saveFile = fullfile(saveDir, [modelName '.slx']);
    save_system(modelName, saveFile);
    fprintf('Model saved: %s\n', saveFile);

    fprintf('\n=== Model Created ===\n');
    fprintf('Name: %s\n', modelName);
    fprintf('Inputs: %d, Outputs: %d, Subsystems: %d\n', ...
        numel(inputs), numel(outputs), numel(subsystems));

    %% Generate HTML report
    specSummary = struct('modelName', modelName, 'saveFile', saveFile, ...
        'inputs', {inputs}, 'outputs', {outputs}, ...
        'subsystems', {subsystems}, 'constants', {constants}, ...
        'connections', {connections}, 'internalLogic', {internalLogic});
    result.reportFile = generateBuildReport(specSummary, saveDir);
    fprintf('Report: %s\n', result.reportFile);
end

function createWrapperInterface(wrapperPath, inputs, outputs)
    clearDefaultSubsystemPorts(wrapperPath);

    inY = 50;
    for i = 1:numel(inputs)
        blk = [wrapperPath '/' inputs(i).name];
        add_block('simulink/Sources/In1', blk, 'Position', [30, inY, 60, inY + 20]);
        try set_param(blk, 'OutDataTypeStr', inputs(i).dataType); catch, end
        inY = inY + 35;
    end

    outY = 50;
    for i = 1:numel(outputs)
        blk = [wrapperPath '/' outputs(i).name];
        add_block('simulink/Sinks/Out1', blk, 'Position', [720, outY, 750, outY + 20]);
        try set_param(blk, 'OutDataTypeStr', outputs(i).dataType); catch, end
        outY = outY + 35;
    end
end

function clearDefaultSubsystemPorts(wrapperPath)
    children = find_system(wrapperPath, 'SearchDepth', 1, 'Type', 'Block');
    for i = 1:numel(children)
        childPath = children{i};
        if strcmp(childPath, wrapperPath)
            continue;
        end
        try
            blockType = get_param(childPath, 'BlockType');
        catch
            blockType = '';
        end
        if strcmp(blockType, 'Inport') || strcmp(blockType, 'Outport')
            delete_block(childPath);
        end
    end
end

function connectTopLevelPorts(modelName, wrapperPath, inputs, outputs)
    wrapperBlockName = get_param(wrapperPath, 'Name');
    for i = 1:numel(inputs)
        add_line(modelName, [inputs(i).name '/1'], [wrapperBlockName '/' num2str(i)], 'autorouting', 'on');
    end
    for i = 1:numel(outputs)
        add_line(modelName, [wrapperBlockName '/' num2str(i)], [outputs(i).name '/1'], 'autorouting', 'on');
    end
end

function desc = getDescription(subsystemSpec, defaultDesc)
    desc = defaultDesc;
    if isfield(subsystemSpec, 'description') && ~isempty(subsystemSpec.description)
        desc = subsystemSpec.description;
    end
end

function setSubsystemDescription(blockPath, descriptionText)
    try
        set_param(blockPath, 'Description', descriptionText);
    catch
    end
end

function tf = isCentralLockFeedbackModel(modelName, subsystems)
    tf = startsWith(upper(modelName), 'ZCUL_');
    if ~tf && ~isempty(subsystems)
        subsystemNames = {subsystems.name};
        tf = any(strcmp(subsystemNames, 'InputSignalAcquisition')) && any(strcmp(subsystemNames, 'OutputPacking'));
    end
end

function buildCentralLockFeedbackArchitecture(wrapperPath, inputs, outputs)
    inputNames = {inputs.name};
    outputNames = {outputs.name};

    subsystemDefs = { ...
        struct('name', 'InputSignalAcquisition', 'kind', 'passthrough', 'inputs', {inputNames}, 'outputs', {inputNames}), ...
        struct('name', 'FLCentralLockValidation', 'kind', 'valid_status', 'inputs', {{'u8IoRxFLCentralLatchStatus', 'bIoRxFLCentralLatchStatusValid'}}, 'outputs', {{'u8LockgCenStsLockSt', 'u8DoorDrvrLockSts'}}), ...
        struct('name', 'RLCentralLockMirroring', 'kind', 'passthrough_one', 'inputs', {{'u8DoorDrvrLockSts'}}, 'outputs', {{'u8DoorLeReLockSts'}}), ...
        struct('name', 'FLDoorStatusFeedback', 'kind', 'valid_status', 'inputs', {{'u8IoRxFLDoorAjarStatus', 'bIoRxFLDoorAjarStatusValid'}}, 'outputs', {{'u8DoorDrvrSts'}}), ...
        struct('name', 'RLDoorStatusFeedback', 'kind', 'valid_status', 'inputs', {{'u8IoRxRLDoorAjarStatus', 'bIoRxRLDoorAjarStatusValid'}}, 'outputs', {{'u8DoorLeReSts'}}), ...
        struct('name', 'FLDoorLockStatusFeedback', 'kind', 'constant', 'inputs', {{ }}, 'outputs', {{'u8DoorDrvrLatPosn'}}), ...
        struct('name', 'RLDoorLockStatusFeedback', 'kind', 'constant', 'inputs', {{ }}, 'outputs', {{'u8DoorLeReLatPosn'}}), ...
        struct('name', 'RLChildLockStatusFeedback', 'kind', 'valid_status', 'inputs', {{'u8IoRxPCLStatus', 'bIoRxPCLStatusValid'}}, 'outputs', {{'u8ChdLockLeftSts'}}), ...
        struct('name', 'MotorErrorFeedback', 'kind', 'fault_map_multi', 'inputs', {{'u8DiagFLDoorReleaseMotor', 'u8DiagRLDoorReleaseMotor', 'u8DiagRLChildlLatchMotor'}}, 'outputs', {{'u8DoorDrvrLockMotErrSts', 'u8ReLeDoorLockMotErrSts', 'u8ChdLockLeftMotErrSts'}}), ...
        struct('name', 'OutputPacking', 'kind', 'output_pack', 'inputs', {{'u8LockgCenStsLockSt', 'u8DoorDrvrLockSts', 'u8DoorLeReLockSts', 'u8DoorDrvrLockMotErrSts', 'u8ReLeDoorLockMotErrSts', 'u8ChdLockLeftMotErrSts', 'u8DoorDrvrSts', 'u8DoorDrvrLatPosn', 'u8DoorLeReSts', 'u8DoorLeReLatPosn', 'u8ChdLockLeftSts'}}, 'outputs', {outputNames}) ...
    };

    for i = 1:numel(subsystemDefs)
        subsystemPath = [wrapperPath '/' subsystemDefs{i}.name];
        clearSubsystemContents(subsystemPath);
        switch subsystemDefs{i}.kind
            case 'passthrough'
                buildPassThroughSubsystem(subsystemPath, subsystemDefs{i}.inputs, subsystemDefs{i}.outputs);
            case 'passthrough_one'
                buildSinglePassThroughSubsystem(subsystemPath, subsystemDefs{i}.inputs{1}, subsystemDefs{i}.outputs{1});
            case 'valid_status'
                buildValidStatusSubsystem(subsystemPath, subsystemDefs{i}.inputs{1}, subsystemDefs{i}.inputs{2}, subsystemDefs{i}.outputs);
            case 'constant'
                buildConstantSubsystem(subsystemPath, subsystemDefs{i}.outputs{1}, '0');
            case 'fault_map_multi'
                buildFaultMapSubsystem(subsystemPath, subsystemDefs{i}.inputs, subsystemDefs{i}.outputs);
            case 'output_pack'
                buildOutputPackingSubsystem(subsystemPath, subsystemDefs{i}.inputs, subsystemDefs{i}.outputs);
            otherwise
                fprintf('  ⚠ Unsupported central lock subsystem kind: %s\n', subsystemDefs{i}.kind);
        end
    end

    connectCentralLockArchitecture(wrapperPath);
    for i = 1:numel(subsystemDefs)
        try
            Simulink.BlockDiagram.arrangeSystem([wrapperPath '/' subsystemDefs{i}.name]);
        catch
        end
    end
end

function connectCentralLockArchitecture(wrapperPath)
    inputNames = getPortNames(wrapperPath, 'Inport');
    outputNames = getPortNames(wrapperPath, 'Outport');

    for i = 1:numel(inputNames)
        add_line(wrapperPath, [inputNames{i} '/1'], ['InputSignalAcquisition/' num2str(i)], 'autorouting', 'on');
    end

    add_line(wrapperPath, 'InputSignalAcquisition/1', 'FLCentralLockValidation/1', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/2', 'FLCentralLockValidation/2', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/1', 'MotorErrorFeedback/1', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/2', 'MotorErrorFeedback/2', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/11', 'MotorErrorFeedback/3', 'autorouting', 'on');

    add_line(wrapperPath, 'FLCentralLockValidation/2', 'RLCentralLockMirroring/1', 'autorouting', 'on');

    add_line(wrapperPath, 'InputSignalAcquisition/5', 'FLDoorStatusFeedback/1', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/6', 'FLDoorStatusFeedback/2', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/7', 'RLDoorStatusFeedback/1', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/8', 'RLDoorStatusFeedback/2', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/9', 'RLChildLockStatusFeedback/1', 'autorouting', 'on');
    add_line(wrapperPath, 'InputSignalAcquisition/10', 'RLChildLockStatusFeedback/2', 'autorouting', 'on');

    add_line(wrapperPath, 'FLCentralLockValidation/1', 'OutputPacking/1', 'autorouting', 'on');
    add_line(wrapperPath, 'FLCentralLockValidation/2', 'OutputPacking/2', 'autorouting', 'on');
    add_line(wrapperPath, 'RLCentralLockMirroring/1', 'OutputPacking/3', 'autorouting', 'on');
    add_line(wrapperPath, 'MotorErrorFeedback/1', 'OutputPacking/4', 'autorouting', 'on');
    add_line(wrapperPath, 'MotorErrorFeedback/1', 'OutputPacking/5', 'autorouting', 'on');
    add_line(wrapperPath, 'MotorErrorFeedback/2', 'OutputPacking/6', 'autorouting', 'on');
    add_line(wrapperPath, 'MotorErrorFeedback/2', 'OutputPacking/7', 'autorouting', 'on');
    add_line(wrapperPath, 'FLDoorStatusFeedback/1', 'OutputPacking/8', 'autorouting', 'on');
    add_line(wrapperPath, 'FLDoorStatusFeedback/1', 'OutputPacking/9', 'autorouting', 'on');
    add_line(wrapperPath, 'FLDoorLockStatusFeedback/1', 'OutputPacking/10', 'autorouting', 'on');
    add_line(wrapperPath, 'FLDoorLockStatusFeedback/1', 'OutputPacking/11', 'autorouting', 'on');
    add_line(wrapperPath, 'RLDoorStatusFeedback/1', 'OutputPacking/12', 'autorouting', 'on');
    add_line(wrapperPath, 'RLDoorStatusFeedback/1', 'OutputPacking/13', 'autorouting', 'on');
    add_line(wrapperPath, 'RLDoorLockStatusFeedback/1', 'OutputPacking/14', 'autorouting', 'on');
    add_line(wrapperPath, 'RLDoorLockStatusFeedback/1', 'OutputPacking/15', 'autorouting', 'on');
    add_line(wrapperPath, 'RLChildLockStatusFeedback/1', 'OutputPacking/16', 'autorouting', 'on');
    add_line(wrapperPath, 'RLChildLockStatusFeedback/1', 'OutputPacking/17', 'autorouting', 'on');
    add_line(wrapperPath, 'MotorErrorFeedback/3', 'OutputPacking/18', 'autorouting', 'on');
    add_line(wrapperPath, 'MotorErrorFeedback/3', 'OutputPacking/19', 'autorouting', 'on');

    for i = 1:numel(outputNames)
        add_line(wrapperPath, ['OutputPacking/' num2str(i)], [outputNames{i} '/1'], 'autorouting', 'on');
    end
end

function buildPassThroughSubsystem(subsystemPath, inputNames, outputNames)
    for i = 2:numel(inputNames)
        blk = [subsystemPath '/In' num2str(i)];
        add_block('simulink/Sources/In1', blk, 'Position', [30, 35 + (i - 1) * 35, 60, 55 + (i - 1) * 35]);
        set_param(blk, 'Port', num2str(i));
    end
    for i = 2:numel(outputNames)
        blk = [subsystemPath '/Out' num2str(i)];
        add_block('simulink/Sinks/Out1', blk, 'Position', [360, 35 + (i - 1) * 35, 390, 55 + (i - 1) * 35]);
        set_param(blk, 'Port', num2str(i));
    end
    for i = 2:min(numel(inputNames), numel(outputNames))
        add_line(subsystemPath, ['In' num2str(i) '/1'], ['Out' num2str(i) '/1'], 'autorouting', 'on');
    end
end

function buildSinglePassThroughSubsystem(subsystemPath, inputName, outputName)
    add_block('simulink/Sources/In1', [subsystemPath '/' inputName], 'Position', [30 35 60 55]);
    set_param([subsystemPath '/' inputName], 'Port', '1');
    add_block('simulink/Sinks/Out1', [subsystemPath '/' outputName], 'Position', [360 35 390 55]);
    set_param([subsystemPath '/' outputName], 'Port', '1');
    add_line(subsystemPath, [inputName '/1'], [outputName '/1'], 'autorouting', 'on');
end

function buildValidStatusSubsystem(subsystemPath, statusInputName, validInputName, outputNames)
    add_block('simulink/Sources/In1', [subsystemPath '/' statusInputName], 'Position', [30 35 60 55]);
    set_param([subsystemPath '/' statusInputName], 'Port', '1');
    add_block('simulink/Sources/In1', [subsystemPath '/' validInputName], 'Position', [30 85 60 105]);
    set_param([subsystemPath '/' validInputName], 'Port', '2');
    add_block('simulink/Sources/Constant', [subsystemPath '/u8_zero'], 'Position', [120 170 160 190], 'Value', '0');
    add_block('simulink/Sources/Constant', [subsystemPath '/u8_open'], 'Position', [120 20 160 40], 'Value', '1');
    add_block('simulink/Sources/Constant', [subsystemPath '/u8_close'], 'Position', [120 60 160 80], 'Value', '2');
    add_block('simulink/Sources/Constant', [subsystemPath '/u8_invalid'], 'Position', [120 220 160 240], 'Value', '3');
    add_block('simulink/Sources/Constant', [subsystemPath '/u8_valid'], 'Position', [120 110 160 130], 'Value', '1');

    add_block('simulink/Logic and Bit Operations/Relational Operator', [subsystemPath '/isZero'], 'Position', [205 20 245 50], 'Operator', '==');
    add_block('simulink/Logic and Bit Operations/Relational Operator', [subsystemPath '/isOne'], 'Position', [205 60 245 90], 'Operator', '==');
    add_block('simulink/Logic and Bit Operations/Relational Operator', [subsystemPath '/isValid'], 'Position', [205 110 245 140], 'Operator', '==');
    add_block('simulink/Signal Routing/Switch', [subsystemPath '/valueSwitch'], 'Position', [300 40 360 90], 'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
    add_block('simulink/Signal Routing/Switch', [subsystemPath '/validSwitch'], 'Position', [430 40 490 90], 'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
    for i = 1:numel(outputNames)
        add_block('simulink/Sinks/Out1', [subsystemPath '/' outputNames{i}], 'Position', [600, 30 + (i - 1) * 40, 630, 50 + (i - 1) * 40]);
        set_param([subsystemPath '/' outputNames{i}], 'Port', num2str(i));
    end

    add_line(subsystemPath, [statusInputName '/1'], 'isZero/1', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_zero/1', 'isZero/2', 'autorouting', 'on');
    add_line(subsystemPath, [statusInputName '/1'], 'isOne/1', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_open/1', 'isOne/2', 'autorouting', 'on');
    add_line(subsystemPath, [validInputName '/1'], 'isValid/1', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_valid/1', 'isValid/2', 'autorouting', 'on');

    add_line(subsystemPath, 'isZero/1', 'valueSwitch/2', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_open/1', 'valueSwitch/1', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_invalid/1', 'valueSwitch/3', 'autorouting', 'on');

    add_line(subsystemPath, 'isOne/1', 'validSwitch/2', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_close/1', 'validSwitch/1', 'autorouting', 'on');
    add_line(subsystemPath, 'valueSwitch/1', 'validSwitch/3', 'autorouting', 'on');

    add_block('simulink/Signal Routing/Switch', [subsystemPath '/validGate'], 'Position', [530 40 590 90], 'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
    add_line(subsystemPath, 'isValid/1', 'validGate/2', 'autorouting', 'on');
    add_line(subsystemPath, 'validSwitch/1', 'validGate/1', 'autorouting', 'on');
    add_line(subsystemPath, 'u8_invalid/1', 'validGate/3', 'autorouting', 'on');

    for i = 1:numel(outputNames)
        add_line(subsystemPath, 'validGate/1', [outputNames{i} '/1'], 'autorouting', 'on');
    end
end

function buildConstantSubsystem(subsystemPath, outputName, constantValue)
    add_block('simulink/Sources/Constant', [subsystemPath '/u8_zero'], 'Position', [120 35 170 55], 'Value', constantValue);
    add_block('simulink/Sinks/Out1', [subsystemPath '/' outputName], 'Position', [360 35 390 55]);
    set_param([subsystemPath '/' outputName], 'Port', '1');
    add_line(subsystemPath, 'u8_zero/1', [outputName '/1'], 'autorouting', 'on');
end

function buildFaultMapSubsystem(subsystemPath, inputNames, outputNames)
    for i = 1:numel(inputNames)
        add_block('simulink/Sources/In1', [subsystemPath '/' inputNames{i}], 'Position', [30, 35 + (i - 1) * 45, 60, 55 + (i - 1) * 45]);
        set_param([subsystemPath '/' inputNames{i}], 'Port', num2str(i));
        add_block('simulink/Sources/Constant', [subsystemPath '/' inputNames{i} '_zero'], 'Position', [120, 35 + (i - 1) * 45, 160, 55 + (i - 1) * 45], 'Value', '0');
        add_block('simulink/Sources/Constant', [subsystemPath '/' inputNames{i} '_one'], 'Position', [120, 60 + (i - 1) * 45, 160, 80 + (i - 1) * 45], 'Value', '1');
        add_block('simulink/Logic and Bit Operations/Relational Operator', [subsystemPath '/' inputNames{i} '_isNoFault'], 'Position', [205, 35 + (i - 1) * 45, 245, 65 + (i - 1) * 45], 'Operator', '==');
        add_block('simulink/Signal Routing/Switch', [subsystemPath '/' inputNames{i} '_faultSwitch'], 'Position', [300, 35 + (i - 1) * 45, 360, 85 + (i - 1) * 45], 'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
        add_block('simulink/Sinks/Out1', [subsystemPath '/' outputNames{i}], 'Position', [430, 35 + (i - 1) * 45, 460, 55 + (i - 1) * 45]);
        set_param([subsystemPath '/' outputNames{i}], 'Port', num2str(i));

        add_line(subsystemPath, [inputNames{i} '/1'], [inputNames{i} '_isNoFault/1'], 'autorouting', 'on');
        add_line(subsystemPath, [inputNames{i} '_zero/1'], [inputNames{i} '_isNoFault/2'], 'autorouting', 'on');
        add_line(subsystemPath, [inputNames{i} '_isNoFault/1'], [inputNames{i} '_faultSwitch/2'], 'autorouting', 'on');
        add_line(subsystemPath, [inputNames{i} '_zero/1'], [inputNames{i} '_faultSwitch/1'], 'autorouting', 'on');
        add_line(subsystemPath, [inputNames{i} '_one/1'], [inputNames{i} '_faultSwitch/3'], 'autorouting', 'on');
        add_line(subsystemPath, [inputNames{i} '_faultSwitch/1'], [outputNames{i} '/1'], 'autorouting', 'on');
    end
end

function buildOutputPackingSubsystem(subsystemPath, inputNames, outputNames)
    numInputs = max(numel(inputNames), numel(outputNames));
    for i = 1:numInputs
        blk = [subsystemPath '/In' num2str(i)];
        add_block('simulink/Sources/In1', blk, 'Position', [30, 30 + (i - 1) * 35, 60, 50 + (i - 1) * 35]);
        set_param(blk, 'Port', num2str(i));
    end
    for i = 1:numel(outputNames)
        blk = [subsystemPath '/Out' num2str(i)];
        add_block('simulink/Sinks/Out1', blk, 'Position', [420, 30 + (i - 1) * 28, 450, 50 + (i - 1) * 28]);
        set_param(blk, 'Port', num2str(i));
    end

    packingMap = { ...
        1, 1; 2, 2; 3, 3; 4, 4; 5, 4; 6, 5; 7, 5; 8, 7; 9, 7; 10, 8; 11, 8; 12, 9; 13, 9; 14, 10; 15, 10; 16, 11; 17, 11; 18, 6; 19, 6 ...
    };
    for i = 1:size(packingMap, 1)
        srcIndex = packingMap{i, 2};
        dstIndex = packingMap{i, 1};
        add_line(subsystemPath, ['In' num2str(srcIndex) '/1'], ['Out' num2str(dstIndex) '/1'], 'autorouting', 'on');
    end
end

function names = getPortNames(parentPath, blockType)
    blocks = find_system(parentPath, 'SearchDepth', 1, 'BlockType', blockType);
    names = cell(1, numel(blocks));
    for i = 1:numel(blocks)
        names{i} = get_param(blocks{i}, 'Name');
    end
end

function clearSubsystemContents(subsystemPath)
    try
        Simulink.SubSystem.deleteContents(subsystemPath);
    catch
    end
end

function reportFile = generateBuildReport(spec, outputDir)
    reportFile = fullfile(outputDir, [spec.modelName '_build_report.html']);
    fid = fopen(reportFile, 'w');
    fprintf(fid, '<!DOCTYPE html>\n<html><head>\n<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Build Report - %s</title>\n', spec.modelName);
    fprintf(fid, '<style>body{font-family:-apple-system,sans-serif;margin:40px}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #4CAF50;padding-bottom:10px}\n');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:10px 0}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:8px;text-align:left}\n');
    fprintf(fid, 'th{background:#4CAF50;color:white}\n');
    fprintf(fid, '.summary{background:#e8f5e9;padding:20px;border-radius:5px;margin:20px 0}\n');
    fprintf(fid, '</style></head><body>\n');
    fprintf(fid, '<h1>Model Build Report: %s</h1>\n', spec.modelName);
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>File:</strong> %s</p>\n', spec.saveFile);
    fprintf(fid, '<p><strong>Inputs:</strong> %d</p>\n', numel(spec.inputs));
    fprintf(fid, '<p><strong>Outputs:</strong> %d</p>\n', numel(spec.outputs));
    fprintf(fid, '<p><strong>Subsystems:</strong> %d</p>\n', numel(spec.subsystems));
    fprintf(fid, '<p><strong>Constants:</strong> %d</p>\n', numel(spec.constants));
    fprintf(fid, '<p><strong>Connections:</strong> %d</p>\n', numel(spec.connections));
    fprintf(fid, '</div>\n');
    % Inputs table
    if ~isempty(spec.inputs)
        fprintf(fid, '<h2>Inputs</h2><table><tr><th>Name</th><th>Data Type</th></tr>\n');
        for i = 1:numel(spec.inputs)
            dt = ''; if isfield(spec.inputs(i),'dataType'), dt = spec.inputs(i).dataType; end
            fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', spec.inputs(i).name, dt);
        end
        fprintf(fid, '</table>\n');
    end
    % Outputs table
    if ~isempty(spec.outputs)
        fprintf(fid, '<h2>Outputs</h2><table><tr><th>Name</th><th>Data Type</th></tr>\n');
        for i = 1:numel(spec.outputs)
            dt = ''; if isfield(spec.outputs(i),'dataType'), dt = spec.outputs(i).dataType; end
            fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', spec.outputs(i).name, dt);
        end
        fprintf(fid, '</table>\n');
    end
    % Subsystems table
    if ~isempty(spec.subsystems)
        fprintf(fid, '<h2>Subsystems</h2><table><tr><th>Name</th><th>Description</th></tr>\n');
        for i = 1:numel(spec.subsystems)
            desc = ''; if isfield(spec.subsystems(i),'description'), desc = spec.subsystems(i).description; end
            fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', spec.subsystems(i).name, desc);
        end
        fprintf(fid, '</table>\n');
    end
    % Connections
    if ~isempty(spec.connections)
        fprintf(fid, '<h2>Connections</h2><ul>\n');
        for i = 1:numel(spec.connections)
            fprintf(fid, '<li><code>%s</code></li>\n', string(spec.connections{i}));
        end
        fprintf(fid, '</ul>\n');
    end
    fprintf(fid, '<hr><p style="color:#999">Generated by buildModelFromSpec.m</p>\n');
    fprintf(fid, '</body></html>\n');
    fclose(fid);
end

%% ================== Internal Logic Builders ==================

function addThresholdLogic(modelName, subName, params)
% Add threshold comparison logic inside a subsystem
    scope = [modelName '/' subName];
    % Add inports
    add_block('simulink/Sources/In1', [scope '/Input'], 'Position', [50, 60, 80, 80]);
    add_block('simulink/Sources/In1', [scope '/Threshold'], 'Position', [50, 140, 80, 160], ...
        'OutDataTypeStr', 'single');
    % Add relational operator
    op = getField(params, 'operator', '>=');
    add_block('simulink/Logic and Bit Operations/RelationalOperator', [scope '/Compare'], ...
        'Position', [200, 70, 250, 110], 'Operator', op);
    % Add outport
    add_block('simulink/Sinks/Out1', [scope '/Output'], 'Position', [350, 80, 380, 100]);
    % Wire
    add_line(scope, 'Input/1', 'Compare/1');
    add_line(scope, 'Threshold/1', 'Compare/2');
    add_line(scope, 'Compare/1', 'Output/1');
end

function addPIDLogic(modelName, subName, params)
% Add PID controller using ONLY basic blocks (no library blocks)
%   P: Error → Gain(Kp) → Sum
%   I: Error → Gain(Ki) → DiscreteIntegrator → Sum
%   D: Error → Gain(Kd) → (basic diff approx) → Sum
    scope = [modelName '/' subName];

    % Inports
    add_block('simulink/Sources/In1', [scope '/Reference'], 'Position', [50, 30, 80, 50]);
    add_block('simulink/Sources/In1', [scope '/Feedback'], 'Position', [50, 110, 80, 130]);

    % Error = Reference - Feedback
    add_block('simulink/Math Operations/Sum', [scope '/Error'], ...
        'Position', [150, 50, 180, 90], 'Inputs', '+-', 'OutDataTypeStr', 'single');

    % --- P path ---
    pGain = getField(params, 'P', '1.0');
    add_block('simulink/Math Operations/Gain', [scope '/P_Gain'], ...
        'Position', [250, 20, 300, 50], 'Gain', pGain, 'OutDataTypeStr', 'single');

    % --- I path ---
    iGain = getField(params, 'I', '0');
    add_block('simulink/Math Operations/Gain', [scope '/I_Gain'], ...
        'Position', [250, 80, 300, 110], 'Gain', iGain, 'OutDataTypeStr', 'single');
    add_block('simulink/Discrete/Discrete-Time Integrator', [scope '/I_Integrator'], ...
        'Position', [350, 80, 420, 110], 'OutDataTypeStr', 'single');

    % --- D path (optional) ---
    dGain = getField(params, 'D', '0');
    hasD = abs(str2double(dGain)) > 0;
    if hasD
        add_block('simulink/Math Operations/Gain', [scope '/D_Gain'], ...
            'Position', [250, 140, 300, 170], 'Gain', dGain, 'OutDataTypeStr', 'single');
        add_block('simulink/Discrete/Discrete Derivative', [scope '/D_Derivative'], ...
            'Position', [350, 140, 420, 170], 'OutDataTypeStr', 'single');
    end

    % Output Sum
    if hasD
        add_block('simulink/Math Operations/Sum', [scope '/PID_Sum'], ...
            'Position', [500, 60, 530, 150], 'Inputs', '+++', 'OutDataTypeStr', 'single');
    else
        add_block('simulink/Math Operations/Sum', [scope '/PID_Sum'], ...
            'Position', [500, 50, 530, 110], 'Inputs', '++', 'OutDataTypeStr', 'single');
    end

    % Saturation (basic clamp)
    add_block('simulink/Discontinuities/Saturation', [scope '/Clamp'], ...
        'Position', [580, 65, 620, 105], 'OutDataTypeStr', 'single');

    % Outport
    add_block('simulink/Sinks/Out1', [scope '/Output'], 'Position', [700, 75, 730, 95]);

    % Wire: Error → Gains
    add_line(scope, 'Reference/1', 'Error/1');
    add_line(scope, 'Feedback/1', 'Error/2');
    add_line(scope, 'Error/1', 'P_Gain/1');
    add_line(scope, 'Error/1', 'I_Gain/1');
    if hasD, add_line(scope, 'Error/1', 'D_Gain/1'); end

    % Wire: P path
    add_line(scope, 'P_Gain/1', 'PID_Sum/1');

    % Wire: I path
    add_line(scope, 'I_Gain/1', 'I_Integrator/1');
    add_line(scope, 'I_Integrator/1', 'PID_Sum/2');

    % Wire: D path
    if hasD
        add_line(scope, 'D_Gain/1', 'D_Derivative/1');
        add_line(scope, 'D_Derivative/1', 'PID_Sum/3');
    end

    % Wire: Sum → Clamp → Output
    add_line(scope, 'PID_Sum/1', 'Clamp/1');
    add_line(scope, 'Clamp/1', 'Output/1');
end

function addFilterLogic(modelName, subName, params)
% Add a basic discrete filter using Gain, Sum, UnitDelay (no library filter)
%   y[n] = b0*x[n] + b1*x[n-1] - a1*y[n-1]
    scope = [modelName '/' subName];
    b0 = getField(params, 'b0', '0.1');
    b1 = getField(params, 'b1', '0.1');
    a1 = getField(params, 'a1', '-0.8');

    add_block('simulink/Sources/In1', [scope '/Input'], 'Position', [50, 60, 80, 80]);
    add_block('simulink/Math Operations/Gain', [scope '/Gain_b0'], ...
        'Position', [150, 20, 200, 50], 'Gain', b0, 'OutDataTypeStr', 'single');
    add_block('simulink/Math Operations/Gain', [scope '/Gain_b1'], ...
        'Position', [150, 100, 200, 130], 'Gain', b1, 'OutDataTypeStr', 'single');
    add_block('simulink/Math Operations/Gain', [scope '/Gain_a1'], ...
        'Position', [150, 180, 200, 210], 'Gain', a1, 'OutDataTypeStr', 'single');
    add_block('simulink/Discrete/UnitDelay', [scope '/Delay_x'], ...
        'Position', [280, 100, 330, 130], 'OutDataTypeStr', 'single');
    add_block('simulink/Discrete/UnitDelay', [scope '/Delay_y'], ...
        'Position', [280, 180, 330, 210], 'OutDataTypeStr', 'single');
    add_block('simulink/Math Operations/Sum', [scope '/Sum'], ...
        'Position', [420, 50, 450, 200], 'Inputs', '++-', 'OutDataTypeStr', 'single');
    add_block('simulink/Sinks/Out1', [scope '/Output'], 'Position', [550, 115, 580, 135]);

    add_line(scope, 'Input/1', 'Gain_b0/1');
    add_line(scope, 'Input/1', 'Gain_b1/1');
    add_line(scope, 'Gain_b0/1', 'Sum/1');
    add_line(scope, 'Gain_b1/1', 'Delay_x/1');
    add_line(scope, 'Delay_x/1', 'Sum/2');
    add_line(scope, 'Delay_y/1', 'Gain_a1/1');
    add_line(scope, 'Gain_a1/1', 'Sum/3');
    add_line(scope, 'Sum/1', 'Delay_y/1');
    add_line(scope, 'Sum/1', 'Output/1');
end

%% ================== Utility ==================

function val = getField(s, fieldPath, default)
% Safely get nested field value
    val = default;
    parts = strsplit(fieldPath, '.');
    current = s;
    try
        for i = 1:numel(parts)
            current = current.(parts{i});
        end
        if ~isempty(current)
            val = current;
        end
    catch
    end
end
