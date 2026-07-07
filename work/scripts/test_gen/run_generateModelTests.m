function result = run_generateModelTests(modelPath, varargin)
% run_generateModelTests  One-click launcher for Simulink Test generation
%   Resolves the workspace paths, initializes the Simulink Agentic Toolkit,
%   and forwards all arguments to generateModelTests.
%
%   Usage:
%       run_generateModelTests
%       run_generateModelTests('path/to/Model.slx')
%       run_generateModelTests('path/to/Model.slx', 'Strategy', 'boundary')
%       run_generateModelTests('path/to/Model.slx', 'Component', 'Model/Subsystem')

    if nargin < 1 || isempty(modelPath)
        [fileName, folderName] = uigetfile( ...
            {'*.slx;*.mdl', 'Simulink models (*.slx, *.mdl)'}, ...
            'Select a Simulink model');
        if isequal(fileName, 0)
            disp('Canceled.');
            result = [];
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

    if exist('satk_initialize', 'file') <= 0
        error('satk_initialize is not available. Check the Simulink Agentic Toolkit path.');
    end

    satk_initialize;

    fprintf('Launching Simulink test generation for: %s\n', modelPath);
    result = generateModelTests(modelPath, varargin{:});

    if nargout == 0
        clear result;
    end
end