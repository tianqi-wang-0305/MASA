function artifacts = run_generateTestExecutionArtifacts(modelPath, varargin)
% run_generateTestExecutionArtifacts  Generate executable Simulink Test assets
%   Creates a Signal Editor harness, a Test Sequence harness, and a Test
%   Manager test file with typed input MAT files.

    if nargin < 1 || isempty(modelPath)
        [fileName, folderName] = uigetfile(...
            {'*.slx;*.mdl', 'Simulink models (*.slx, *.mdl)'}, ...
            'Select a Simulink model');
        if isequal(fileName, 0)
            disp('Canceled.');
            artifacts = struct();
            return;
        end
        modelPath = fullfile(folderName, fileName);
    end

    modelPath = char(modelPath);
    if ~isfile(modelPath)
        error('Model file not found: %s', modelPath);
    end

    p = inputParser;
    addParameter(p, 'Strategy', 'comprehensive', @(x) any(validatestring(x, {'basic', 'boundary', 'comprehensive'})));
    addParameter(p, 'Component', '', @ischar);
    addParameter(p, 'OutputDir', '', @ischar);
    parse(p, varargin{:});

    [modelDir, modelBase, ~] = fileparts(modelPath);
    if isempty(p.Results.OutputDir)
        outputDir = fullfile(modelDir, '_tests');
    else
        outputDir = p.Results.OutputDir;
    end
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    launcherDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(fileparts(fileparts(launcherDir)), 'simulink-agentic-toolkit'));
    addpath(fullfile(fileparts(fileparts(launcherDir)), 'scripts', 'test_gen', 'src'));
    addpath(launcherDir);
    if exist('satk_initialize', 'file') > 0
        satk_initialize;
    end

    cd(modelDir);
    initScript = runInitVarIfAvailable(modelDir);
    origPWD = pwd;
    cleanupObj = onCleanup(@() cd(origPWD)); %#ok<NASGU>
    load_system(modelBase);
    runTag = regexprep(char(java.util.UUID.randomUUID), '-', '');

    testResults = generateModelTests(modelPath, ...
        'Strategy', p.Results.Strategy, ...
        'Component', p.Results.Component, ...
        'OutputDir', outputDir, ...
        'RunTests', false);

    load_system(modelBase);
    save_system(modelBase);

    artifacts = struct();
    artifacts.modelName = modelBase;
    artifacts.outputDir = outputDir;
    artifacts.initScript = initScript;

    try
        artifacts.signalEditor = createSignalEditorHarness(modelBase, testResults, outputDir, runTag);
    catch ME
        warning('Signal Editor harness generation failed: %s', ME.message);
        artifacts.signalEditor = '';
    end

    try
        artifacts.testSequence = createTestSequenceHarness(modelBase, testResults, outputDir, runTag);
    catch ME
        warning('Test Sequence harness generation failed: %s', ME.message);
        artifacts.testSequence = '';
    end

    try
        artifacts.testManager = createTestManagerFile(modelBase, testResults, outputDir);
    catch ME
        warning('Test Manager file generation failed: %s', ME.message);
        artifacts.testManager = '';
    end

    try
        artifacts.signalBuilder = createSignalBuilderHarness(modelBase, testResults, outputDir, runTag);
    catch ME
        warning('Signal Builder generation failed: %s', ME.message);
        artifacts.signalBuilder = '';
    end

    close_system(modelBase, 0);
end

function harnessPath = createSignalEditorHarness(modelBase, testResults, outputDir, runTag)
    harnessName = sprintf('%s_SignalEditorHarness_%s', modelBase, runTag);
    harnessPath = fullfile(outputDir, [harnessName '.slx']);
    inputsPath = fullfile(outputDir, [harnessName '_HarnessInputs.mat']);

    if exist(harnessPath, 'file')
        delete(harnessPath);
    end
    if exist(inputsPath, 'file')
        delete(inputsPath);
    end

    addpath(outputDir);
    pathCleanup = onCleanup(@() rmpath(outputDir)); %#ok<NASGU>

    sltest.harness.create(modelBase, ...
        Name=harnessName, ...
        Source='Signal Editor', ...
        Sink='Outport', ...
        SaveExternally=true, ...
        HarnessPath=harnessPath, ...
        LogOutputs=true, ...
        CreateWithoutCompile=true);

    scenarioFiles = cell(0, 1);
    for s = 1:numel(testResults.testSuites)
        suite = testResults.testSuites(s);
        for j = 1:numel(suite.scenarios)
            scenario = suite.scenarios{j};
            ds = buildTypedDatasetTemplate(testResults.inports, scenario);
            scenarioName = makeSafeName(scenario.title);
            scenarioFile = fullfile(outputDir, sprintf('%s_%s_HarnessInputs.mat', harnessName, scenarioName));
            save(scenarioFile, 'ds');
            scenarioFiles{end+1} = scenarioFile; %#ok<AGROW>
        end
    end

    if isempty(scenarioFiles)
        error('No Signal Editor input datasets were generated.');
    end

    baseScenarioFile = scenarioFiles{1};
    if ~strcmp(baseScenarioFile, inputsPath)
        copyfile(baseScenarioFile, inputsPath);
    else
        save(inputsPath, 'ds');
    end

    load_system(harnessPath);
    inputBlock = find_system(harnessName, 'MaskType', 'SignalEditor');
    if ~isempty(inputBlock)
        set_param(inputBlock{1}, 'FileName', inputsPath);
    end
    save_system(harnessName, harnessPath);
    close_system(harnessName, 0);
end

function harnessPath = createTestSequenceHarness(modelBase, testResults, outputDir, runTag)
    harnessName = sprintf('%s_TestSequenceHarness_%s', modelBase, runTag);
    harnessPath = fullfile(outputDir, [harnessName '.slx']);

    if exist(harnessPath, 'file')
        delete(harnessPath);
    end

    sltest.harness.create(modelBase, ...
        Name=harnessName, ...
        Source='Inport', ...
        Sink='Outport', ...
        SaveExternally=true, ...
        HarnessPath=harnessPath, ...
        LogOutputs=true, ...
        CreateWithoutCompile=true);

    load_system(harnessPath);
    sequenceBlockPath = sprintf('%s/Test Sequence', harnessName);
    sltest.testsequence.newBlock(sequenceBlockPath);
    sequenceBlock = sequenceBlockPath;

    inputNames = {testResults.inports.name};
    for i = 1:numel(inputNames)
        try
            sltest.testsequence.addSymbol(sequenceBlock, inputNames{i}, 'Data', 'Input');
        catch
        end
    end

    for s = 1:numel(testResults.testSuites)
        suite = testResults.testSuites(s);
        for j = 1:numel(suite.scenarios)
            scenario = suite.scenarios{j};
            scenarioName = sprintf('S%02d_%s', s, makeSafeName(scenario.title));
            try
                sltest.testsequence.addScenario(sequenceBlock, scenarioName);
            catch
            end
            try
                sltest.testsequence.useScenario(sequenceBlock, scenarioName);
            catch
            end
            actionText = buildScenarioActionText(scenario, testResults.inports);
            stepPath = sprintf('%s.Step1', scenarioName);
            sltest.testsequence.addStep(sequenceBlock, stepPath, 'Action', actionText);
        end
    end

    save_system(harnessName, harnessPath);
    close_system(harnessName, 0);
end

function tmPath = createTestManagerFile(modelBase, testResults, outputDir)
    tmPath = fullfile(outputDir, sprintf('%s_TM.mldatx', modelBase));
    if exist(tmPath, 'file')
        delete(tmPath);
    end

    tf = sltest.testmanager.TestFile(tmPath);
    for s = 1:numel(testResults.testSuites)
        suite = testResults.testSuites(s);
        tmSuite = tf.createTestSuite(makeSafeName(suite.title));
        for j = 1:numel(suite.scenarios)
            scenario = suite.scenarios{j};
            caseName = makeSafeName(scenario.title);
            tc = tmSuite.createTestCase('simulation', caseName);
            inputMat = fullfile(outputDir, sprintf('%s_%s_input.mat', modelBase, caseName));
            ds = buildTypedDatasetTemplate(testResults.inports, scenario);
            save(inputMat, 'ds');
            inputObj = addInput(tc, inputMat);
            try
                inputObj.map('CompileModel', false);
            catch ME
                warning('Input mapping failed for %s: %s', caseName, ME.message);
            end
        end
    end
    tf.saveToFile;
    tmPath = tf.FilePath;
end

function harnessPath = createSignalBuilderHarness(modelBase, testResults, outputDir, runTag)
    harnessName = sprintf('%s_SignalBuilderHarness_%s', modelBase, runTag);
    harnessPath = fullfile(outputDir, [harnessName '.slx']);
    if exist(harnessPath, 'file')
        delete(harnessPath);
    end

    sltest.harness.create(modelBase, ...
        Name=harnessName, ...
        Source='Inport', ...
        Sink='Outport', ...
        SaveExternally=true, ...
        HarnessPath=harnessPath, ...
        LogOutputs=true, ...
        CreateWithoutCompile=true);

    try
        load_system(harnessPath);
        sbBlk = find_system(harnessName, 'MaskType', 'Sigbuilder block');
        if ~isempty(sbBlk)
            warning('Signal Builder harness created, but the legacy signalbuilder API is unstable in this environment.');
        end
        close_system(harnessName, 0);
    catch
    end
end

function ds = buildTypedDatasetTemplate(inports, scenario)
    ds = Simulink.SimulationData.Dataset;
    for i = 1:numel(inports)
        [startVal, endVal, stepTime, isStep] = parseStimulus(scenario.given{i, 2});
        if isStep
            stepTime = max(stepTime, 1e-6);
            time = [0; max(stepTime - 1e-6, 0); stepTime; stepTime + 1e-6];
            samples = [startVal; startVal; endVal; endVal];
        else
            time = [0; max(1, stepTime)];
            samples = [startVal; startVal];
        end

        typedSamples = castSamplesForType(inports(i).dataType, samples);
        ts = timeseries(typedSamples, time);
        ts.Name = inports(i).name;
        ds = ds.addElement(ts);
    end
end

function actionText = buildScenarioActionText(scenario, inports)
    assignments = strings(0, 1);
    for i = 1:numel(inports)
        [startVal, ~, ~, ~] = parseStimulus(scenario.given{i, 2});
        assignments(end+1) = sprintf('%s = %s;', makeSafeName(inports(i).name), literalForType(inports(i).dataType, startVal)); %#ok<AGROW>
    end
    actionText = strjoin(assignments, ' ');
end

function [startVal, endVal, stepTime, isStep] = parseStimulus(stimulus)
    stimulus = string(stimulus);
    constTok = regexp(stimulus, '^const\(([-+0-9.eE]+)\)$', 'tokens', 'once');
    if ~isempty(constTok)
        startVal = str2double(constTok{1});
        endVal = startVal;
        stepTime = 1;
        isStep = false;
        return;
    end

    stepTok = regexp(stimulus, '^step\(([-+0-9.eE]+) -> ([-+0-9.eE]+) @ ([-+0-9.eE]+)s\)$', 'tokens', 'once');
    if ~isempty(stepTok)
        startVal = str2double(stepTok{1});
        endVal = str2double(stepTok{2});
        stepTime = str2double(stepTok{3});
        isStep = true;
        return;
    end

    startVal = 0;
    endVal = 0;
    stepTime = 1;
    isStep = false;
end

function valueText = literalForType(dataType, value)
    dt = lower(string(dataType));
    if contains(dt, 'uint16')
        valueText = sprintf('uint16(%g)', value);
    elseif contains(dt, 'int16')
        valueText = sprintf('int16(%g)', value);
    elseif contains(dt, 'uint8')
        valueText = sprintf('uint8(%g)', value);
    elseif contains(dt, 'int8')
        valueText = sprintf('int8(%g)', value);
    elseif contains(dt, 'boolean') || contains(dt, 'bool')
        valueText = sprintf('logical(%d)', value ~= 0);
    else
        valueText = sprintf('%g', value);
    end
end

function data = castSamplesForType(dataType, rawData)
    dt = lower(string(dataType));
    if contains(dt, 'uint16')
        data = uint16(rawData);
    elseif contains(dt, 'int16')
        data = int16(rawData);
    elseif contains(dt, 'uint8')
        data = uint8(rawData);
    elseif contains(dt, 'int8')
        data = int8(rawData);
    elseif contains(dt, 'boolean') || contains(dt, 'bool')
        data = logical(rawData);
    elseif contains(dt, 'single')
        data = single(rawData);
    else
        data = double(rawData);
    end
end

function scenario = firstScenario(testResults)
    scenario = testResults.testSuites(1).scenarios{1};
end

function safeName = makeSafeName(text)
    safeName = strtrim(string(text));
    safeName = regexprep(safeName, '[^A-Za-z0-9_]', '_');
    safeName = regexprep(safeName, '_+', '_');
    if strlength(safeName) == 0 || ~isletter(extractBefore(safeName, 2))
        safeName = 'item_' + safeName;
    end
    safeName = char(safeName);
end

function initScript = runInitVarIfAvailable(modelDir)
% Run a nearby InitVar.m script in the base workspace if it exists.
    initScript = '';
    candidate = fullfile(modelDir, 'InitVar.m');
    if exist(candidate, 'file')
        initScript = candidate;
        try
            evalin('base', sprintf('run(''%s'')', strrep(candidate, '''', '''''')));
        catch ME
            warning('InitVar execution failed: %s', ME.message);
        end
    end
end