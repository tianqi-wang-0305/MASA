% build_model_headless.m - Build BCM Lock Controller in headless mode
% This avoids GUI-dependent operations like open_system

fprintf('=== Building BCM Lock Controller (headless) ===\n');

% Initialize Simulink
load_simulink;

% Add paths
addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
toolDirs = dir(fullfile('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit', 'tools'));
for i = 1:numel(toolDirs)
    if toolDirs(i).isdir && ~strcmp(toolDirs(i).name, '.') && ~strcmp(toolDirs(i).name, '..')
        addpath(fullfile('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit', 'tools', toolDirs(i).name));
    end
end
addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/model_gen/src');

fprintf('Creating model...\n');
new_system('BCM_LockController');
fprintf('new_system OK\n');
save_system('BCM_LockController', fullfile(pwd, 'BCM_LockController.slx'));
fprintf('Model saved\n');
exit(0);
