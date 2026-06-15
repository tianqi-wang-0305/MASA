% run_build.m - Build BCM Lock Controller model
% Run with: matlab -batch "run('run_build.m')"

% Add toolkit and all tool subdirectories
toolkitRoot = '/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit';
addpath(toolkitRoot);

% Add all tool subdirectories
toolDirs = dir(fullfile(toolkitRoot, 'tools'));
for i = 1:numel(toolDirs)
    if toolDirs(i).isdir && ~strcmp(toolDirs(i).name, '.') && ~strcmp(toolDirs(i).name, '..')
        addpath(fullfile(toolkitRoot, 'tools', toolDirs(i).name));
    end
end

addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/model_gen/src');

fprintf('Toolkit path added\n');

if exist('model_edit', 'file')
    fprintf('model_edit found - using Toolkit mode\n');
else
    fprintf('model_edit NOT found - will use fallback (add_block/add_line)\n');
end

try
    createBCMLockController(pwd);
    fprintf('SUCCESS: Model created\n');
catch ME
    fprintf('ERROR: %s\n', ME.message);
    for i = 1:numel(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
    end
end
