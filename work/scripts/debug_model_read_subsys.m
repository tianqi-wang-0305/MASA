addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;
load_system('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx');

% Get a subsystem
sysPath = 'Foc_2024b/FieldOrientedControl';
sid = get_param(sysPath, 'SID');
fprintf('Path: %s\n', sysPath);
fprintf('SID: %s\n', sid);

scopeId = regexprep(sid, '^blk_', '');
fprintf('Scope ID: %s\n', scopeId);

% Call exactly like analyzeSingleSubsystem does
try
    fprintf('\nCalling model_read...\n');
    r = model_read(char('Foc_2024b'), "root", scopeId);
    fprintf('OK\n');
catch ME
    fprintf('FAILED: %s\n', ME.message);
    fprintf('Stack:\n');
    for i = 1:numel(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
    end
end
exit(0);
