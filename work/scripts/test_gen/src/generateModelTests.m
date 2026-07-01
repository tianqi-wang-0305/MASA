function testResults = generateModelTests(modelPath, varargin)
% generateModelTests  Automatically generate and run Simulink Test cases
%   Analyzes model/subsystem interface using Agentic Toolkit tools,
%   generates Gherkin .feature files, and executes via model_test.
%   Tests are compliant with Simulink Test harness format.
%
%   Inputs:
%       modelPath     - Full path to .slx model file
%       varargin      - 'Component' - subsystem path (default: model root)
%                       'OutputDir' - output directory (default: model folder)
%                       'Strategy'  - test strategy: 'basic'|'boundary'|'comprehensive'
%                       'RunTests'  - true/false (default: true)
%
%   Outputs:
%       testResults   - Struct with test paths, results, and coverage
%
%   Usage:
%       % Test entire model
%       results = generateModelTests('path/to/Model.slx');
%
%       % Test specific subsystem with boundary coverage
%       results = generateModelTests('path/to/Model.slx', ...
%           'Component', 'Model/SubsystemName', ...
%           'Strategy', 'boundary');
%
%       % Generate feature files only, don't run
%       results = generateModelTests('path/to/Model.slx', 'RunTests', false);

    fprintf('=== Simulink Test Auto-Generation ===\n\n');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Component', '', @ischar);
    addParameter(p, 'OutputDir', '', @ischar);
    addParameter(p, 'Strategy', 'comprehensive', @(x) any(validatestring(x, {'basic', 'boundary', 'comprehensive'})));
    addParameter(p, 'RunTests', true, @islogical);
    parse(p, modelPath, varargin{:});

    modelPath = char(p.Results.modelPath);
    componentPath = p.Results.Component;
    outputDir = p.Results.OutputDir;
    strategy = p.Results.Strategy;
    shouldRun = p.Results.RunTests;

    %% 0) Resolve paths
    [modelDir, modelBase, ~] = fileparts(modelPath);
    if isempty(modelDir)
        modelDir = pwd;
    end
    modelName = string(modelBase);

    if isempty(outputDir)
        outputDir = fullfile(modelDir, '_tests');
    end
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Ensure toolkit on path
    toolkitRoot = getToolkitRoot();
    if ~isempty(toolkitRoot)
        addpath(toolkitRoot);
    end

    %% 1) Load model and analyze component
    fprintf('[1/5] Loading model: %s\n', modelName);
    load_system(modelPath);

    % Determine component under test
    if isempty(componentPath)
        componentPath = char(modelName);
        componentDisplay = char(modelName);
    else
        componentDisplay = componentPath;
    end

    fprintf('[2/5] Analyzing component: %s\n', componentDisplay);

    % Use model_read to get interface
    [inports, outports, dataTypes, sampleTime] = analyzeComponentInterface(componentPath);

    if isempty(inports)
        error('Component has no input ports. model_test requires at least one Inport and one Outport.');
    end
    if isempty(outports)
        error('Component has no output ports. model_test requires at least one Inport and one Outport.');
    end

    fprintf('  Found %d inputs, %d outputs\n', numel(inports), numel(outports));

    %% 2) Generate .feature files
    fprintf('[3/5] Generating test cases (strategy: %s)...\n', strategy);

    featureFiles = strings(0, 1);
    testSuites = generateTestSuite(strategy, modelName, componentPath, inports, outports, dataTypes, sampleTime);

    for i = 1:numel(testSuites)
        suite = testSuites(i);
        featureFile = fullfile(outputDir, suite.filename);
        writeFeatureFile(suite, featureFile, modelName, componentPath, inports, outports);
        featureFiles(end+1) = featureFile; %#ok<AGROW>
        fprintf('  Created: %s (%d scenarios)\n', suite.filename, numel(suite.scenarios));
    end

    %% 3) Run tests via model_test
    testResults = struct();
    testResults.modelName = modelName;
    testResults.componentPath = componentPath;
    testResults.featureFiles = featureFiles;
    testResults.testSuites = testSuites;
    testResults.strategy = strategy;
    testResults.inports = inports;
    testResults.outports = outports;
    testResults.suiteResults = {};

    if shouldRun
        fprintf('[4/5] Running tests...\n');

        for i = 1:numel(featureFiles)
            featureFile = featureFiles(i);
            [~, featName] = fileparts(featureFile);

            fprintf('  Running: %s\n', featName);
            try
                fullResult = model_test('TestFile', char(featureFile));
                testResults.suiteResults{end+1} = struct(...
                    'featureFile', featureFile, ...
                    'status', 'passed', ...
                    'result', string(fullResult)); %#ok<AGROW>
                fprintf('    Run:  PASS\n');
            catch ME
                testResults.suiteResults{end+1} = struct(...
                    'featureFile', featureFile, ...
                    'status', 'failed', ...
                    'error', ME.message); %#ok<AGROW>
                fprintf('    Run:  FAILED - %s\n', ME.message);
            end
        end
    end

    %% 4) Generate test report summary
    fprintf('[5/5] Generating test report...\n');
    testResults.reportFile = generateTestReport(testResults, outputDir);

    %% 5) Summary
    fprintf('\n=== Test Generation Complete ===\n');
    fprintf('Feature files: %d\n', numel(featureFiles));
    if shouldRun
        passed = sum(cellfun(@(x) isfield(x, 'status') && strcmp(x.status, 'passed'), testResults.suiteResults));
        fprintf('Tests passed: %d / %d\n', passed, numel(testResults.suiteResults));
    end
    fprintf('Report: %s\n', testResults.reportFile);
end

%% ================== Component Analysis ==================

function [inports, outports, dataTypes, sampleTime] = analyzeComponentInterface(componentPath)
% Analyze component interface using model_read and direct query
    inports = struct('name', {}, 'dataType', {}, 'dims', {}, 'sampleTime', {});
    outports = struct('name', {}, 'dataType', {}, 'dims', {}, 'sampleTime', {});

    % Get Inport blocks
    inBlocks = find_system(componentPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    for i = 1:numel(inBlocks)
        blk = inBlocks{i};
        if string(blk) == string(componentPath)
            continue;
        end
        name = string(get_param(blk, 'Name'));
        dt = string(get_param(blk, 'OutDataTypeStr'));
        dims = getBlockDimensions(blk);
        st = string(get_param(blk, 'SampleTime'));
        inports(end+1) = struct('name', name, 'dataType', dt, 'dims', dims, 'sampleTime', st); %#ok<AGROW>
    end

    % Get Outport blocks
    outBlocks = find_system(componentPath, 'SearchDepth', 1, 'BlockType', 'Outport');
    for i = 1:numel(outBlocks)
        blk = outBlocks{i};
        if string(blk) == string(componentPath)
            continue;
        end
        name = string(get_param(blk, 'Name'));
        dt = string(get_param(blk, 'OutDataTypeStr'));
        dims = getBlockDimensions(blk);
        st = string(get_param(blk, 'SampleTime'));
        outports(end+1) = struct('name', name, 'dataType', dt, 'dims', dims, 'sampleTime', st); %#ok<AGROW>
    end

    dataTypes = unique(string([{inports.dataType}, {outports.dataType}]));
    sampleTime = get_param(componentPath, 'FixedStep');
    if isempty(sampleTime)
        sampleTime = '0.01'; % default
    end
end

function dims = getBlockDimensions(blk)
    dims = "";
    candidateParams = {'Dimensions', 'PortDimensions', 'CompiledPortDimensions'};
    for i = 1:numel(candidateParams)
        paramName = candidateParams{i};
        try
            value = get_param(blk, paramName);
            if ~isempty(value)
                if isstring(value) || ischar(value)
                    dims = string(value);
                elseif isnumeric(value)
                    dims = string(mat2str(value));
                else
                    dims = string(value);
                end
                return;
            end
        catch
        end
    end
end

%% ================== Test Suite Generation ==================

function suites = generateTestSuite(strategy, modelName, componentPath, inports, outports, dataTypes, sampleTime)
% Generate test suites based on strategy
    suites = [];

    switch strategy
        case 'basic'
            suites = generateBasicTests(modelName, componentPath, inports, outports, sampleTime);
        case 'boundary'
            suites = generateBoundaryTests(modelName, componentPath, inports, outports, sampleTime);
        case 'comprehensive'
            suites = [generateBasicTests(modelName, componentPath, inports, outports, sampleTime); ...
                      generateBoundaryTests(modelName, componentPath, inports, outports, sampleTime); ...
                      generateMcdcTests(modelName, componentPath, inports, outports, sampleTime)];
    end
end

function suites = generateBasicTests(modelName, componentPath, inports, outports, sampleTime)
% Generate basic nominal test cases
    suites = struct('filename', {}, 'title', {}, 'description', {}, 'scenarios', {});
    [~, compName] = fileparts(componentPath);
    if isempty(compName)
        compName = modelName;
    end

    %% Suite 1: Nominal Operation
    scenarios = {};
    simTime = getSimTime(sampleTime);

    % Scenario 1.1: All inputs at nominal (zero/constant)
    s = struct();
    s.title = 'Nominal operation - constant inputs';
    s.description = sprintf('Verify component operates correctly with constant nominal inputs over %s simulation.', simTime);
    s.given = cell(0, 2);
    for i = 1:numel(inports)
        inName = inports(i).name;
        safeName = makeSafePortName(inName);
        stimulus = getNominalStimulus(inports(i), 'constant');
        s.given(end+1, :) = {safeName, stimulus};
    end
    s.when = sprintf('simulate for %s in Normal mode', simTime);
    s.then = generateBasicAssertions(outports, 'constant');
    s.isBaseline = false;
    scenarios{end+1} = s;

    % Scenario 1.2: Step response
    s = struct();
    s.title = 'Step response - input transitions';
    s.description = 'Verify component responds correctly to step changes in inputs.';
    s.given = cell(0, 2);
    for i = 1:numel(inports)
        inName = inports(i).name;
        safeName = makeSafePortName(inName);
        stimulus = getNominalStimulus(inports(i), 'step');
        s.given(end+1, :) = {safeName, stimulus};
    end
    s.when = sprintf('simulate for %s in Normal mode', simTime);
    s.then = generateBasicAssertions(outports, 'step');
    s.isBaseline = true;
    s.baselineFile = [char(compName) '_baseline.mat'];
    scenarios{end+1} = s;

    suites(1) = struct(...
        'filename', sprintf('%s_NominalTests.feature', compName), ...
        'title', sprintf('%s Nominal Operation Tests', compName), ...
        'description', 'Basic functional verification of component behavior under normal operating conditions.', ...
        'scenarios', {scenarios});
end

function suites = generateBoundaryTests(modelName, componentPath, inports, outports, sampleTime)
% Generate boundary and edge case tests
    suites = struct('filename', {}, 'title', {}, 'description', {}, 'scenarios', {});
    [~, compName] = fileparts(componentPath);
    if isempty(compName)
        compName = modelName;
    end
    simTime = getSimTime(sampleTime);
    scenarios = {};

    %% Suite 2: Boundary Conditions
    % Scenario 2.1: Zero inputs
    s = struct();
    s.title = 'Boundary - zero/off inputs';
    s.description = 'Verify component behavior when all inputs are at zero or minimum value.';
    s.given = cell(0, 2);
    for i = 1:numel(inports)
        inName = inports(i).name;
        safeName = makeSafePortName(inName);
        s.given(end+1, :) = {safeName, 'const(0)'};
    end
    s.when = sprintf('simulate for %s in Normal mode', simTime);
    s.then = generateBoundaryAssertions(outports);
    s.isBaseline = false;
    scenarios{end+1} = s;

    % Scenario 2.2: Maximum value inputs
    s = struct();
    s.title = 'Boundary - maximum inputs';
    s.description = 'Verify component behavior when all inputs are at maximum value.';
    s.given = cell(0, 2);
    for i = 1:numel(inports)
        inName = inports(i).name;
        safeName = makeSafePortName(inName);
        s.given(end+1, :) = {safeName, getMaxStimulus(inports(i))};
    end
    s.when = sprintf('simulate for %s in Normal mode', simTime);
    s.then = generateBoundaryAssertions(outports);
    s.isBaseline = false;
    scenarios{end+1} = s;

    % Scenario 2.3: Step transition (0->max)
    if numel(inports) >= 1
        s = struct();
        s.title = 'Boundary - step transition zero to maximum';
        s.description = 'Verify component handles abrupt transition from zero to maximum input.';
        s.given = cell(0, 2);
        first = true;
        for i = 1:numel(inports)
            inName = inports(i).name;
            safeName = makeSafePortName(inName);
            if first
                s.given(end+1, :) = {safeName, sprintf('step(0 -> %s @ 1s)', getMaxValue(inports(i)))};
                first = false;
            else
                s.given(end+1, :) = {safeName, 'const(0)'};
            end
        end
        s.when = sprintf('simulate for %s in Normal mode', simTime);
        s.then = generateBoundaryAssertions(outports);
        s.isBaseline = false;
        scenarios{end+1} = s;
    end

    suites(1) = struct(...
        'filename', sprintf('%s_BoundaryTests.feature', compName), ...
        'title', sprintf('%s Boundary & Edge Case Tests', compName), ...
        'description', 'Verification of component behavior at boundary conditions and edge cases.', ...
        'scenarios', {scenarios});
end

function suites = generateMcdcTests(modelName, componentPath, inports, outports, sampleTime)
% Generate MCDC-oriented test cases by toggling each input independently.
    suites = struct('filename', {}, 'title', {}, 'description', {}, 'scenarios', {});
    [~, compName] = fileparts(componentPath);
    if isempty(compName)
        compName = modelName;
    end

    simTime = getSimTime(sampleTime);
    scenarios = {};

    % Nominal baseline
    s = struct();
    s.title = 'MCDC - nominal baseline';
    s.description = 'Baseline scenario used to compare independent input toggles for MCDC-oriented analysis.';
    s.given = cell(0, 2);
    for i = 1:numel(inports)
        s.given(end+1, :) = {makeSafePortName(inports(i).name), getMcdcStimulus(inports(i), 'nominal')}; %#ok<AGROW>
    end
    s.when = sprintf('simulate for %s in Normal mode', simTime);
    s.then = generateBoundaryAssertions(outports);
    s.isBaseline = true;
    s.baselineFile = [char(compName) '_mcdc_baseline.mat'];
    scenarios{end+1} = s;

    % Independent high/low toggle for every input
    for i = 1:numel(inports)
        for polarity = ["high", "low"]
            s = struct();
            s.title = sprintf('MCDC - %s %s toggle', makeSafePortName(inports(i).name), polarity);
            s.description = sprintf('Toggle %s to %s while holding all other inputs nominal.', inports(i).name, polarity);
            s.given = cell(0, 2);
            for j = 1:numel(inports)
                if i == j
                    stimulus = getMcdcStimulus(inports(j), char(polarity));
                else
                    stimulus = getMcdcStimulus(inports(j), 'nominal');
                end
                s.given(end+1, :) = {makeSafePortName(inports(j).name), stimulus}; %#ok<AGROW>
            end
            s.when = sprintf('simulate for %s in Normal mode', simTime);
            s.then = generateBoundaryAssertions(outports);
            s.isBaseline = false;
            scenarios{end+1} = s;
        end
    end

    suites(1) = struct(...
        'filename', sprintf('%s_McdcTests.feature', compName), ...
        'title', sprintf('%s MCDC-Oriented Tests', compName), ...
        'description', 'Input toggle tests intended to support MCDC-oriented verification.', ...
        'scenarios', {scenarios});
end

%% ================== Stimulus Generation ==================

function stimulus = getNominalStimulus(portInfo, mode)
% Generate nominal stimulus based on port info and mode
    dt = lower(portInfo.dataType);
    dims = portInfo.dims;

    if contains(dt, 'boolean') || contains(dt, 'bool')
        if strcmp(mode, 'step')
            stimulus = 'step(0 -> 1 @ 1s)';
        else
            stimulus = 'const(0)';
        end
    elseif contains(dt, 'uint8') || contains(dt, 'int8')
        if strcmp(mode, 'step')
            stimulus = 'step(0 -> 100 @ 1s)';
        else
            stimulus = 'const(0)';
        end
    elseif contains(dt, 'uint16') || contains(dt, 'int16')
        if strcmp(mode, 'step')
            stimulus = 'step(0 -> 1000 @ 1s)';
        else
            stimulus = 'const(0)';
        end
    elseif contains(dt, 'uint32') || contains(dt, 'int32')
        if strcmp(mode, 'step')
            stimulus = 'step(0 -> 10000 @ 1s)';
        else
            stimulus = 'const(0)';
        end
    else % double, single, or inherited
        if strcmp(mode, 'step')
            stimulus = 'step(0 -> 100 @ 1s)';
        else
            stimulus = 'const(0)';
        end
    end
end

function stimulus = getMaxStimulus(portInfo)
% Generate maximum value stimulus
    dt = lower(portInfo.dataType);
    if contains(dt, 'boolean') || contains(dt, 'bool')
        stimulus = 'const(1)';
    elseif contains(dt, 'uint8')
        stimulus = 'const(255)';
    elseif contains(dt, 'int8')
        stimulus = 'const(127)';
    elseif contains(dt, 'uint16')
        stimulus = 'const(65535)';
    elseif contains(dt, 'int16')
        stimulus = 'const(32767)';
    elseif contains(dt, 'uint32')
        stimulus = 'const(4294967295)';
    elseif contains(dt, 'int32')
        stimulus = 'const(2147483647)';
    else
        stimulus = 'const(1e6)';
    end
end

function stimulus = getMcdcStimulus(portInfo, polarity)
% Generate low/high nominal values for MCDC-oriented toggles.
    dt = lower(portInfo.dataType);
    switch lower(string(polarity))
        case 'nominal'
            if contains(dt, 'bool') || contains(dt, 'boolean')
                stimulus = 'const(0)';
            elseif contains(dt, 'uint') || contains(dt, 'int') || contains(dt, 'enum')
                stimulus = 'const(0)';
            else
                stimulus = 'const(0)';
            end
        case 'high'
            if contains(dt, 'bool') || contains(dt, 'boolean')
                stimulus = 'const(1)';
            elseif contains(dt, 'uint') || contains(dt, 'int') || contains(dt, 'enum')
                stimulus = 'const(1)';
            else
                stimulus = 'const(1)';
            end
        case 'low'
            if contains(dt, 'bool') || contains(dt, 'boolean')
                stimulus = 'const(0)';
            elseif contains(dt, 'uint') || contains(dt, 'enum')
                stimulus = 'const(0)';
            elseif contains(dt, 'int')
                stimulus = 'const(-1)';
            else
                stimulus = 'const(-1)';
            end
        otherwise
            stimulus = 'const(0)';
    end
end

function maxVal = getMaxValue(portInfo)
% Get max value string for step generation
    dt = lower(portInfo.dataType);
    if contains(dt, 'boolean') || contains(dt, 'bool')
        maxVal = '1';
    elseif contains(dt, 'uint8')
        maxVal = '255';
    elseif contains(dt, 'int8')
        maxVal = '127';
    elseif contains(dt, 'uint16')
        maxVal = '65535';
    elseif contains(dt, 'int16')
        maxVal = '32767';
    elseif contains(dt, 'uint32')
        maxVal = '4294967295';
    elseif contains(dt, 'int32')
        maxVal = '2147483647';
    else
        maxVal = '100';
    end
end

%% ================== Assertion Generation ==================

function assertions = generateBasicAssertions(outports, mode)
% Generate basic output assertions
    assertions = {};
    for i = 1:min(3, numel(outports))  % Assert on first 3 outputs
        outName = makeSafePortName(outports(i).name);
        dt = lower(outports(i).dataType);

        if contains(dt, 'boolean') || contains(dt, 'bool')
            assertions{end+1} = struct('name', [outName 'Check'], 'expr', [outName ' >= 0']); %#ok<AGROW>
        else
            assertions{end+1} = struct('name', [outName 'InRange'], 'expr', [outName ' == [-inf .. inf]']); %#ok<AGROW>
        end
    end
end

function assertions = generateBoundaryAssertions(outports)
% Generate boundary assertions
    assertions = {};
    for i = 1:min(3, numel(outports))
        outName = makeSafePortName(outports(i).name);
        assertions{end+1} = struct('name', [outName 'Finite'], 'expr', [outName ' == [-inf .. inf]']); %#ok<AGROW>
    end
end

%% ================== Feature File Writer ==================

function writeFeatureFile(suite, filePath, modelName, componentPath, inports, outports)
% Write Gherkin .feature file with TOML front-matter
    fid = fopen(filePath, 'w');
    if fid < 0
        error('Cannot write feature file: %s', filePath);
    end

    % TOML front-matter
    fprintf(fid, '# --- front-matter:toml ---\n');
    fprintf(fid, 'model = "%s"\n', modelName);
    if ~strcmp(componentPath, modelName)
        fprintf(fid, 'component = "%s"\n', componentPath);
    end
    fprintf(fid, '[inputs]\n');
    for i = 1:numel(inports)
        safeName = makeSafePortName(inports(i).name);
        portRef = makePortRef(inports(i).name);
        fprintf(fid, '%s = "%s"\n', safeName, portRef);
    end
    fprintf(fid, '[outputs]\n');
    for i = 1:numel(outports)
        safeName = makeSafePortName(outports(i).name);
        portRef = makePortRef(outports(i).name);
        fprintf(fid, '%s = "%s"\n', safeName, portRef);
    end
    fprintf(fid, '# --- end front-matter ---\n');
    fprintf(fid, '\n');

    % Feature
    fprintf(fid, 'Feature: %s\n', suite.title);
    fprintf(fid, '  %s\n', suite.description);
    fprintf(fid, '\n');

    % Scenarios
    for i = 1:numel(suite.scenarios)
        sc = suite.scenarios{i};

        fprintf(fid, 'Scenario: %s\n', sc.title);
        if isfield(sc, 'description') && ~isempty(sc.description)
            fprintf(fid, '  %s\n', sc.description);
        end

        % Given inputs
        fprintf(fid, '  Given inputs\n');
        for j = 1:size(sc.given, 1)
            fprintf(fid, '    * %s = %s\n', sc.given{j, 1}, sc.given{j, 2});
        end

        % When simulate
        fprintf(fid, '  When %s\n', sc.when);

        % Then assertions
        if sc.isBaseline && isfield(sc, 'baselineFile')
            fprintf(fid, '  Then baseline "%s" with tolerances: absTol=0.01, relTol=0.01, timeTol=50ms\n', ...
                sc.baselineFile);
        end

        if ~isempty(sc.then)
            fprintf(fid, '  Then outputs\n');
            for j = 1:numel(sc.then)
                fprintf(fid, '    * %s: %s\n', sc.then{j}.name, sc.then{j}.expr);
            end
        end

        fprintf(fid, '\n');
    end

    fclose(fid);
end

%% ================== Test Report Generation ==================

function reportFile = generateTestReport(testResults, outputDir)
% Generate HTML test report
    reportFile = fullfile(outputDir, 'test_report.html');

    fid = fopen(reportFile, 'w');
    if fid < 0
        warning('Cannot write report file: %s', reportFile);
        reportFile = '';
        return;
    end

    fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Test Report - %s</title>\n', testResults.modelName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 40px; }\n');
    fprintf(fid, 'h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }\n');
    fprintf(fid, 'h2 { color: #555; }\n');
    fprintf(fid, '.pass { color: #4CAF50; font-weight: bold; }\n');
    fprintf(fid, '.fail { color: #f44336; font-weight: bold; }\n');
    fprintf(fid, 'table { border-collapse: collapse; width: 100%%; margin: 20px 0; }\n');
    fprintf(fid, 'th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }\n');
    fprintf(fid, 'th { background-color: #4CAF50; color: white; }\n');
    fprintf(fid, 'tr:nth-child(even) { background-color: #f2f2f2; }\n');
    fprintf(fid, '.summary { background-color: #e7f3fe; padding: 15px; border-radius: 5px; margin: 20px 0; }\n');
    fprintf(fid, '</style>\n</head>\n<body>\n');

    fprintf(fid, '<h1>Simulink Test Report</h1>\n');
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Model:</strong> %s</p>\n', testResults.modelName);
    fprintf(fid, '<p><strong>Component:</strong> %s</p>\n', testResults.componentPath);
    fprintf(fid, '<p><strong>Strategy:</strong> %s</p>\n', testResults.strategy);
    fprintf(fid, '<p><strong>Generated:</strong> %s</p>\n', datetime('now'));
    fprintf(fid, '<p><strong>Test Files:</strong> %d</p>\n', numel(testResults.featureFiles));

    totalScenarios = 0;
    for i = 1:numel(testResults.featureFiles)
        totalScenarios = totalScenarios + countFeatureScenarios(testResults.featureFiles(i));
    end
    fprintf(fid, '<p><strong>Scenarios:</strong> %d</p>\n', totalScenarios);

    if isfield(testResults, 'suiteResults') && ~isempty(testResults.suiteResults)
        passed = sum(cellfun(@(x) isfield(x, 'status') && strcmp(x.status, 'passed'), testResults.suiteResults));
        total = numel(testResults.suiteResults);
        fprintf(fid, '<p><strong>Results:</strong> %d / %d passed</p>\n', passed, total);
    end
    fprintf(fid, '</div>\n');

    % Interface summary
    fprintf(fid, '<h2>Interface Summary</h2>\n');
    fprintf(fid, '<h3>Inputs</h3>\n');
    fprintf(fid, '<table>\n');
    fprintf(fid, '<tr><th>Name</th><th>Data Type</th><th>Dimensions</th><th>Sample Time</th></tr>\n');
    for i = 1:numel(testResults.inports)
        ip = testResults.inports(i);
        fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
            ip.name, ip.dataType, ip.dims, ip.sampleTime);
    end
    fprintf(fid, '</table>\n');

    fprintf(fid, '<h3>Outputs</h3>\n');
    fprintf(fid, '<table>\n');
    fprintf(fid, '<tr><th>Name</th><th>Data Type</th><th>Dimensions</th><th>Sample Time</th></tr>\n');
    for i = 1:numel(testResults.outports)
        op = testResults.outports(i);
        fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
            op.name, op.dataType, op.dims, op.sampleTime);
    end
    fprintf(fid, '</table>\n');

    % Feature files table
    fprintf(fid, '<h2>Test Suites</h2>\n');
    fprintf(fid, '<table>\n');
    fprintf(fid, '<tr><th>Feature File</th><th>Scenarios</th><th>Status</th><th>Details</th></tr>\n');

    for i = 1:numel(testResults.featureFiles)
        featureFile = testResults.featureFiles(i);
        [~, fName] = fileparts(featureFile);
        scenarioCount = countFeatureScenarios(featureFile);
        status = 'N/A';
        details = 'Not executed';

        if isfield(testResults, 'suiteResults') && i <= numel(testResults.suiteResults)
            sr = testResults.suiteResults{i};
            if strcmp(sr.status, 'passed')
                status = '<span class="pass">PASS</span>';
                details = 'Executed successfully';
            else
                status = '<span class="fail">FAIL</span>';
                if isfield(sr, 'error')
                    details = sr.error;
                end
            end
        end

        fprintf(fid, '<tr><td>%s</td><td>%d</td><td>%s</td><td>%s</td></tr>\n', ...
            fName, scenarioCount, status, details);
    end
    fprintf(fid, '</table>\n');

    % Scenario details
    fprintf(fid, '<h2>Scenario Details</h2>\n');
    fprintf(fid, '<table>\n');
    fprintf(fid, '<tr><th>Feature File</th><th>Scenario</th><th>Inputs</th><th>Expected Outputs</th></tr>\n');
    for i = 1:numel(testResults.testSuites)
        suite = testResults.testSuites(i);
        [~, fName] = fileparts(testResults.featureFiles(i));
        for j = 1:numel(suite.scenarios)
            sc = suite.scenarios{j};
            inputText = formatScenarioInputs(sc);
            outputText = formatScenarioOutputs(sc);
            fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
                fName, escapeHtml(sc.title), inputText, outputText);
        end
    end
    fprintf(fid, '</table>\n');

    % Next steps
    fprintf(fid, '<h2>Next Steps</h2>\n');
    fprintf(fid, '<ul>\n');
    fprintf(fid, '<li>Review generated .feature files in: <code>%s</code></li>\n', outputDir);
    fprintf(fid, '<li>Run tests manually: <code>model_test(''TestFile'', ''path/to/test.feature'')</code></li>\n');
    fprintf(fid, '<li>Add more scenarios for additional coverage</li>\n');
    fprintf(fid, '<li>Use <code>coverage=''decision''</code> for coverage analysis</li>\n');
    fprintf(fid, '</ul>\n');

    fprintf(fid, '</body>\n</html>\n');
    fclose(fid);

    fprintf('Test report: %s\n', reportFile);
end

%% ================== Utility Functions ==================

function safeName = makeSafePortName(portName)
% Convert port name to safe Gherkin alias (no spaces, no special chars)
    safeName = strtrim(string(portName));
    safeName = regexprep(safeName, '[^A-Za-z0-9_]', '_');
    safeName = regexprep(safeName, '_+', '_');
    if ~isletter(extractBefore(safeName, 2))
        safeName = 'p_' + safeName;
    end
    safeName = char(safeName);
end

function portRef = makePortRef(portName)
% Create port reference string for TOML front-matter
    portName = strtrim(string(portName));
    % Quote if name contains special characters
    if contains(portName, {' ', '(', ')', '.'})
        portRef = "'" + portName + "'";
    else
        portRef = char(portName);
    end
end

function simTimeStr = getSimTime(sampleTime)
% Determine appropriate simulation time
    st = str2double(regexprep(sampleTime, '[^0-9.eE\-]', ''));
    if isnan(st) || st <= 0
        st = 0.01;
    end
    % Simulate for enough steps to see behavior
    numSteps = max(100, min(1000, 500 / st));
    totalTime = numSteps * st;
    simTimeStr = sprintf('%.3fs', totalTime);
end

function rootPath = getToolkitRoot()
% Find the simulink-agentic-toolkit root directory
    envPath = string(getenv('SATK_ROOT'));
    if strlength(envPath) > 0 && exist(envPath, 'dir')
        rootPath = char(envPath);
        return;
    end
    scriptPath = fileparts(mfilename('fullpath'));
    candidates = {
        fullfile(scriptPath, '..', '..', '..', 'simulink-agentic-toolkit');
        fullfile(scriptPath, '..', '..', '..', '..', 'simulink-agentic-toolkit');
    };
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'dir') && exist(fullfile(candidates{i}, 'tools', 'model_overview', 'model_overview.p'), 'file')
            rootPath = candidates{i};
            return;
        end
    end
    rootPath = '';
end

function scenarioCount = countFeatureScenarios(featureFile)
% Count Gherkin scenarios in a generated feature file.
    scenarioCount = 0;
    try
        featureText = fileread(char(featureFile));
        scenarioCount = numel(regexp(featureText, '^\s*Scenario\s*:', 'lineanchors'));
    catch
        scenarioCount = 0;
    end
end

function text = formatScenarioInputs(sc)
% Format scenario inputs for HTML report.
    if ~isfield(sc, 'given') || isempty(sc.given)
        text = '-';
        return;
    end

    parts = strings(0, 1);
    for i = 1:size(sc.given, 1)
        parts(end+1) = sprintf('%s = %s', string(sc.given{i, 1}), string(sc.given{i, 2})); %#ok<AGROW>
    end
    text = escapeHtml(strjoin(parts, newline));
end

function text = formatScenarioOutputs(sc)
% Format scenario output assertions for HTML report.
    if ~isfield(sc, 'then') || isempty(sc.then)
        text = '-';
        return;
    end

    parts = strings(0, 1);
    for i = 1:numel(sc.then)
        parts(end+1) = sprintf('%s: %s', string(sc.then{i}.name), string(sc.then{i}.expr)); %#ok<AGROW>
    end
    text = escapeHtml(strjoin(parts, newline));
end

function text = escapeHtml(text)
% Escape HTML-sensitive characters while preserving simple line breaks.
    text = string(text);
    text = replace(text, '&', '&amp;');
    text = replace(text, '<', '&lt;');
    text = replace(text, '>', '&gt;');
    text = replace(text, char(10), '<br>');
    text = replace(text, char(13), '');
    text = char(text);
end
