function runAIPipeline(modelPath, excelPath, varargin)
% runAIPipeline  Unified AI-powered automation pipeline for Simulink development
%   Runs AI-enhanced SDD document generation and automated unit test generation.
%
%   Inputs:
%       modelPath    - Full path to .slx model file
%       excelPath    - Full path to Excel interface/calibration workbook
%       varargin     - 'SkipTests' - skip test generation (default: false)
%                      'SkipSDD'   - skip SDD generation (default: false)
%                      'TestStrategy' - 'basic'|'boundary'|'comprehensive'
%                      'TestComponent' - subsystem path for testing
%
%   Usage:
%       % Run full pipeline
%       runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx');
%
%       % Run SDD only
%       runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx', 'SkipTests', true);
%
%       % Run with comprehensive tests on specific subsystem
%       runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx', ...
%           'TestComponent', 'Model/Subsystem', 'TestStrategy', 'comprehensive');

    fprintf('========================================\n');
    fprintf('  AI-Powered Simulink Automation Pipeline\n');
    fprintf('========================================\n\n');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelPath', @(x) ischar(x) || isstring(x));
    addRequired(p, 'excelPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'SkipTests', false, @islogical);
    addParameter(p, 'SkipSDD', false, @islogical);
    addParameter(p, 'TestStrategy', 'basic', @(x) any(validatestring(x, {'basic', 'boundary', 'comprehensive'})));
    addParameter(p, 'TestComponent', '', @ischar);
    parse(p, modelPath, excelPath, varargin{:});

    modelPath = char(p.Results.modelPath);
    excelPath = char(p.Results.excelPath);

    %% Add required paths
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(scriptDir, 'ai_sdd', 'src'));
    addpath(fullfile(scriptDir, 'test_gen', 'src'));

    %% Step 1: AI-Enhanced SDD Generation
    if ~p.Results.SkipSDD
        fprintf('--- Step 1/2: AI-Enhanced SDD Generation ---\n\n');
        try
            pdfFile = DdGeneration_AI(modelPath, excelPath);
            fprintf('\n[OK] SDD document: %s\n\n', pdfFile);
        catch ME
            warning('SDD generation failed: %s', ME.message);
            fprintf('Falling back to standard DdGeneration_ASPICE...\n');
            try
                pdfFile = DdGeneration_ASPICE(modelPath, excelPath);
                fprintf('[OK] Fallback SDD: %s\n\n', pdfFile);
            catch ME2
                warning('Fallback also failed: %s', ME2.message);
            end
        end
    else
        fprintf('--- Step 1/2: SDD Generation SKIPPED ---\n\n');
    end

    %% Step 2: Automated Test Generation
    if ~p.Results.SkipTests
        fprintf('--- Step 2/2: Automated Test Generation ---\n\n');
        try
            testArgs = {modelPath, 'Strategy', p.Results.TestStrategy};
            if ~isempty(p.Results.TestComponent)
                testArgs = [testArgs, 'Component', p.Results.TestComponent];
            end
            results = generateModelTests(testArgs{:});
            fprintf('\n[OK] Tests generated: %s\n', results.reportFile);
        catch ME
            warning('Test generation failed: %s', ME.message);
        end
    else
        fprintf('--- Step 2/2: Test Generation SKIPPED ---\n\n');
    end

    fprintf('\n========================================\n');
    fprintf('  Pipeline Complete\n');
    fprintf('========================================\n');
end
