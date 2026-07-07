function harnessPath = run_generateTestHarness(modelPath, varargin)
% run_generateTestHarness  Create an external Simulink Test harness file
%   Generates a standalone harness SLX for the selected model or subsystem.

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

    if exist(toolkitRoot, 'dir')
        addpath(genpath(toolkitRoot));
    end
    if exist('satk_initialize', 'file') > 0
        satk_initialize;
    end

    load_system(modelPath);
    [modelDir, modelBase, ~] = fileparts(modelPath);
    harnessDir = fullfile(modelDir, '_tests');
    if ~exist(harnessDir, 'dir')
        mkdir(harnessDir);
    end

    harnessName = sprintf('%s_Harness', modelBase);
    harnessPath = fullfile(harnessDir, [harnessName '.slx']);

    if exist(harnessPath, 'file')
        delete(harnessPath);
    end

    result = sltest.harness.create(modelBase, ...
        Name=harnessName, ...
        Source="Inport", ...
        Sink="Outport", ...
        SaveExternally=true, ...
        HarnessPath=harnessPath, ...
        LogOutputs=true, ...
        AutoShapeInputs=true, ...
        CreateWithoutCompile=true);

    if isstruct(result) && isfield(result, 'Errors') && ~isempty(result.Errors)
        error('Harness creation reported errors: %s', strjoin(string(result.Errors), '; '));
    end

    fprintf('Harness created: %s\n', harnessPath);
end