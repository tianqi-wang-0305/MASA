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
    portRefs = struct();
    yPos = 50;
    for i = 1:numel(inputs)
        blkName = inputs(i).name;
        add_block('simulink/Sources/In1', [modelName '/' blkName]);
        set_param([modelName '/' blkName], 'Position', [50, yPos, 80, yPos+20]);
        try set_param([modelName '/' blkName], 'OutDataTypeStr', inputs(i).dataType); catch, end
        portRefs.(genvarname(blkName)) = struct('block', blkName, 'type', 'Inport');
        yPos = yPos + 40;
    end

    % Add output ports
    yPos = 50;
    for i = 1:numel(outputs)
        blkName = outputs(i).name;
        add_block('simulink/Sinks/Out1', [modelName '/' blkName]);
        set_param([modelName '/' blkName], 'Position', [650, yPos, 680, yPos+20]);
        try set_param([modelName '/' blkName], 'OutDataTypeStr', outputs(i).dataType); catch, end
        portRefs.(genvarname(blkName)) = struct('block', blkName, 'type', 'Outport');
        yPos = yPos + 40;
    end

    % Add subsystems
    subPos = 100;
    for i = 1:numel(subsystems)
        blkName = subsystems(i).name;
        add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/' blkName]);
        set_param([modelName '/' blkName], 'Position', [250, subPos, 400, subPos+80]);
        portRefs.(genvarname(blkName)) = struct('block', blkName, 'type', 'SubSystem');
        subPos = subPos + 120;
    end

    % Add constants
    for i = 1:numel(constants)
        blkName = constants(i).name;
        add_block('simulink/Sources/Constant', [modelName '/' blkName]);
        val = num2str(constants(i).value);
        set_param([modelName '/' blkName], 'Value', val);
        set_param([modelName '/' blkName], 'Position', [150, subPos, 220, subPos+20]);
        portRefs.(genvarname(blkName)) = struct('block', blkName, 'type', 'Constant');
        subPos = subPos + 40;
    end

    %% Apply connections
    for i = 1:numel(connections)
        conn = connections{i};
        if ischar(conn) || isstring(conn)
            connStr = char(conn);
            parts = split(connStr, '->');
            if numel(parts) == 2
                src = strtrim(parts{1});
                dst = strtrim(parts{2});
                try
                    add_line(modelName, [src '/1'], [dst '/1']);
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
                addThresholdLogic(modelName, subName, params);
            case 'pid'
                addPIDLogic(modelName, subName, params);
            case 'filter'
                addFilterLogic(modelName, subName, params);
            otherwise
                fprintf('  ⚠ Unknown logic type: %s for %s\n', logicType, subName);
        end
    end

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
    add_block('simulink/Discrete/DiscreteIntegrator', [scope '/I_Integrator'], ...
        'Position', [350, 80, 420, 110], 'OutDataTypeStr', 'single');

    % --- D path (optional) ---
    dGain = getField(params, 'D', '0');
    hasD = abs(str2double(dGain)) > 0;
    if hasD
        add_block('simulink/Math Operations/Gain', [scope '/D_Gain'], ...
            'Position', [250, 140, 300, 170], 'Gain', dGain, 'OutDataTypeStr', 'single');
        add_block('simulink/Discrete/DiscreteDerivative', [scope '/D_Derivative'], ...
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
    add_block('simulink/Saturation', [scope '/Clamp'], ...
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
