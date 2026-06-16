function result = checkModelWithThreshold(modelName, varargin)
% checkModelWithThreshold  Run Model Advisor with pass/fail threshold
%   Executes Model Advisor checks and fails if errors exceed threshold.
%   Designed for CI/CD and pre-commit hooks.
%
%   Inputs:
%       modelName     - Model name or path
%       varargin      - 'ErrorThreshold' - max errors before fail (default: 0)
%                       'WarningThreshold' - max warnings (default: inf)
%                       'Checks' - specific check IDs (default: 'all')
%                       'OutputDir' - report output (default: model dir)
%
%   Usage:
%       result = checkModelWithThreshold('Model.slx');
%       result = checkModelWithThreshold('Model.slx', 'ErrorThreshold', 5);

    fprintf('=== Model Check with Threshold ===\n\n');
    result = struct('passed', false, 'errors', 0, 'warnings', 0, ...
        'reportFile', '', 'details', {});

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ErrorThreshold', 0, @isnumeric);
    addParameter(p, 'WarningThreshold', inf, @isnumeric);
    addParameter(p, 'Checks', 'all', @ischar);
    addParameter(p, 'OutputDir', '', @ischar);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    errThreshold = p.Results.ErrorThreshold;
    warnThreshold = p.Results.WarningThreshold;
    checks = p.Results.Checks;
    outputDir = p.Results.OutputDir;

    [~, modelBase, ~] = fileparts(modelName);
    if isempty(modelBase)
        modelBase = modelName;
    end

    if isempty(outputDir)
        outputDir = fileparts(which(modelBase));
        if isempty(outputDir)
            outputDir = pwd;
        end
    end

    %% Step 1: Run Model Advisor
    fprintf('[1/3] Running Model Advisor on: %s\n', modelBase);

    try
        load_system(modelBase);
        modelHandle = get_param(modelBase, 'Handle');

        % Create Model Advisor
        ma = ModelAdvisor(modelBase);
        ma.setActiveModel();

        if strcmp(checks, 'all')
            ma.run('./*');
        else
            ma.run(checks);
        end

        % Generate report
        reportFile = fullfile(outputDir, [modelBase '_ModelAdvisor_Threshold.html']);
        ma.generateReport(reportFile, 'HTML');
        result.reportFile = reportFile;
        fprintf('      Report: %s\n', reportFile);
    catch ME
        fprintf('      Model Advisor failed: %s\n', ME.message);
        result.errors = -1;
        result.passed = false;
        return;
    end

    %% Step 2: Parse results
    fprintf('[2/3] Parsing results...\n');

    try
        maResult = ma.getResults();
        errorCount = 0;
        warningCount = 0;
        details = {};

        for i = 1:numel(maResult)
            if maResult{i}.Failed
                errorCount = errorCount + 1;
                details{end+1} = struct('check', maResult{i}.Title, ...
                    'severity', 'error', 'description', maResult{i}.Description); %#ok<AGROW>
            elseif maResult{i}.Warned
                warningCount = warningCount + 1;
                if warningCount <= 10 % Limit details output
                    details{end+1} = struct('check', maResult{i}.Title, ...
                        'severity', 'warning', 'description', maResult{i}.Description); %#ok<AGROW>
                end
            end
        end

        result.errors = errorCount;
        result.warnings = warningCount;
        result.details = details;

    catch ME
        fprintf('      Parse warning: %s\n', ME.message);
    end

    %% Step 3: Apply threshold
    fprintf('[3/3] Threshold check...\n');

    fprintf('      Errors:   %d (threshold: %d)\n', result.errors, errThreshold);
    fprintf('      Warnings: %d (threshold: %s)\n', result.warnings, ...
        mat2str(warnThreshold));

    if result.errors > errThreshold
        result.passed = false;
        fprintf('      ⛔ FAILED: Error count exceeds threshold\n');
    elseif result.warnings > warnThreshold
        result.passed = false;
        fprintf('      ⛔ FAILED: Warning count exceeds threshold\n');
    else
        result.passed = true;
        fprintf('      ✅ PASSED: All within thresholds\n');
    end

    %% Summary
    fprintf('\n=== Check Complete ===\n');
    if result.passed
        fprintf('Status: ✅ PASSED\n');
    else
        fprintf('Status: ⛔ FAILED\n');
    end
end
