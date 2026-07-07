function harnessPath = run_generateSignalBuilderHarness(modelPath, varargin)
% run_generateSignalBuilderHarness  Generate a Signal Builder executable harness model
%   Creates a standalone Simulink model that uses a Signal Builder block to
%   drive the model under test with one group per generated scenario.

    if nargin < 1 || isempty(modelPath)
        [fileName, folderName] = uigetfile( ...
            {'*.slx;*.mdl', 'Simulink models (*.slx, *.mdl)'}, ...
            'Select a Simulink model');
        if isequal(fileName, 0)
            disp('Canceled.');
            harnessPath = '';
            return;
        end
        modelPath = fullfile(folderName, fileName);
    end

    modelPath = char(modelPath);
    if ~isfile(modelPath)
        error('Model file not found: %s', modelPath);
    end

    launcherDir = fileparts(mfilename('fullpath'));
    workRoot = fileparts(fileparts(launcherDir));
    toolkitRoot = fullfile(workRoot, 'simulink-agentic-toolkit');
    srcRoot = fullfile(workRoot, 'scripts', 'test_gen', 'src');

    if exist(toolkitRoot, 'dir')
        addpath(genpath(toolkitRoot));
    end
    if exist(srcRoot, 'dir')
        addpath(srcRoot);
    end

    if exist('satk_initialize', 'file') > 0
        satk_initialize;
    end

    % Reuse the generated scenario definitions without running tests.
    testResults = generateModelTests(modelPath, 'RunTests', false, varargin{:});
    harnessPath = exportSignalBuilderHarness(testResults, modelPath);
end

function harnessPath = exportSignalBuilderHarness(testResults, modelPath)
    [modelDir, modelBase, ~] = fileparts(char(modelPath));
    harnessDir = fullfile(modelDir, '_tests');
    if ~exist(harnessDir, 'dir')
        mkdir(harnessDir);
    end

    harnessName = sprintf('%s_SignalBuilderHarness', modelBase);
    harnessPath = fullfile(harnessDir, [harnessName '.slx']);

    load_system(modelPath);
    if bdIsLoaded(harnessName)
        close_system(harnessName, 0);
    end
    if exist(harnessPath, 'file')
        delete(harnessPath);
    end

    new_system(harnessName);
    open_system(harnessName);

    sbBlk = [harnessName '/Stimulus'];
    dutBlk = [harnessName '/DUT'];

    add_block('simulink/Sources/Signal Builder', sbBlk, 'Position', [80 70 240 170]);

    try
        add_block('simulink/Ports & Subsystems/Model', dutBlk, 'Position', [360 55 530 185]);
    catch
        add_block('simulink/Ports & Subsystems/Model Reference', dutBlk, 'Position', [360 55 530 185]);
    end

    set_param(dutBlk, 'ModelName', modelBase);

    inports = testResults.inports;
    outports = testResults.outports;
    signalNames = arrayfun(@(x) char(makeSafePortName(x.name)), inports, 'UniformOutput', false);

    for i = 1:numel(outports)
        outName = char(makeSafePortName(outports(i).name));
        add_block('simulink/Sinks/Out1', [harnessName '/' outName], ...
            'Position', [620 60 + (i-1) * 40 670 80 + (i-1) * 40]);
    end

    if ~isempty(testResults.testSuites)
        suite = testResults.testSuites(1);
        if ~isempty(suite.scenarios)
            scenario = suite.scenarios{1};
            simTime = parseSimulationTime(scenario);
            [timeCell, dataCell, groupName] = buildSignalBuilderGroup(scenario, inports, simTime);
            save_system(harnessName, harnessPath);
            close_system(harnessName, 0);
            load_system(harnessPath);
            sbBlk = [harnessName '/Stimulus'];
            signalbuilder(sbBlk, 'create', timeCell, dataCell, signalNames, {groupName});
        end
    end

    set_param(harnessName, 'SimulationCommand', 'update');

    sbPorts = get_param(sbBlk, 'PortHandles');
    dutPorts = get_param(dutBlk, 'PortHandles');
    numSignals = min(numel(signalNames), numel(sbPorts.Outport));
    for i = 1:numSignals
        add_line(harnessName, sbPorts.Outport(i), dutPorts.Inport(i), 'autorouting', 'on');
    end

    numOuts = min(numel(outports), numel(dutPorts.Outport));
    for i = 1:numOuts
        outBlk = [harnessName '/' char(makeSafePortName(outports(i).name))];
        outPorts = get_param(outBlk, 'PortHandles');
        add_line(harnessName, dutPorts.Outport(i), outPorts.Inport, 'autorouting', 'on');
    end

    save_system(harnessName, harnessPath);
    close_system(harnessName);
    fprintf('Signal Builder harness: %s\n', harnessPath);
end

function [timeCell, dataCell, groupName] = buildSignalBuilderGroup(scenario, inports, simTime)
    timeCell = cell(1, numel(inports));
    dataCell = cell(1, numel(inports));
    for i = 1:numel(inports)
        stimulus = scenario.given{i, 2};
        [timeCell{i}, dataCell{i}] = parseStimulus(stimulus, simTime);
    end
    groupName = char(makeSafeGroupName(scenario.title));
end

function [timeVec, dataVec] = parseStimulus(stimulus, simTime)
    stimulus = string(stimulus);
    constTok = regexp(stimulus, '^const\(([-+0-9.eE]+)\)$', 'tokens', 'once');
    if ~isempty(constTok)
        value = str2double(constTok{1});
        timeVec = [0 simTime];
        dataVec = [value value];
        return;
    end

    stepTok = regexp(stimulus, '^step\(([-+0-9.eE]+) -> ([-+0-9.eE]+) @ ([-+0-9.eE]+)s\)$', 'tokens', 'once');
    if ~isempty(stepTok)
        startValue = str2double(stepTok{1});
        endValue = str2double(stepTok{2});
        stepTime = str2double(stepTok{3});
        delta = max(1e-6, stepTime * 1e-3);
        timeVec = [0 stepTime max(stepTime + delta, stepTime) simTime];
        dataVec = [startValue startValue endValue endValue];
        return;
    end

    timeVec = [0 simTime];
    dataVec = [0 0];
end

function simTime = parseSimulationTime(scenario)
    simTime = 10;
    if isfield(scenario, 'when')
        tok = regexp(string(scenario.when), 'simulate for ([0-9.]+)s', 'tokens', 'once');
        if ~isempty(tok)
            parsed = str2double(tok{1});
            if isfinite(parsed) && parsed > 0
                simTime = parsed;
            end
        end
    end
end

function safeName = makeSafePortName(portName)
    safeName = strtrim(string(portName));
    safeName = regexprep(safeName, '[^A-Za-z0-9_]', '_');
    safeName = regexprep(safeName, '_+', '_');
    if strlength(safeName) == 0 || ~isletter(extractBefore(safeName, 2))
        safeName = 'p_' + safeName;
    end
    safeName = char(safeName);
end

function safeName = makeSafeGroupName(groupName)
    safeName = strtrim(string(groupName));
    safeName = regexprep(safeName, '[^A-Za-z0-9_]', '_');
    safeName = regexprep(safeName, '_+', '_');
    safeName = char(safeName);
end