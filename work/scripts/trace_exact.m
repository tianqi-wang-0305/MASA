addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;

% Exact same setup as analyzeModelDeepForSDD
modelPath = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx';
[modelDir, modelBase, ~] = fileparts(modelPath);
modelName = string(modelBase);
load_system(modelPath);

sysPath = 'Foc_2024b/FieldOrientedControl';
sysName = string(get_param(sysPath, 'Name'));

fprintf('modelName type: %s\n', class(modelName));
fprintf('modelName value: %s\n', modelName);

% Replicate analyzeSingleSubsystem EXACTLY
scopeId = regexprep(string(get_param(sysPath, 'SID')), '^blk_', '');
fprintf('scopeId: %s (type: %s)\n', scopeId, class(scopeId));

fprintf('\n--- model_read ---\n');
try
    r = model_read(char(modelName), "root", scopeId);
    fprintf('OK\n');
catch ME
    fprintf('FAIL: %s\n', ME.message);
end

fprintf('--- model_query_params ---\n');
try
    r = model_query_params(char(modelName), jsonencode({scopeId}), jsonencode({"all"}), "false");
    fprintf('OK\n');
catch ME
    fprintf('FAIL: %s\n', ME.message);
end

fprintf('--- model_resolve_params ---\n');
try
    r = model_resolve_params(char(modelName), jsonencode({"Kp", "Ki"}));
    fprintf('OK\n');
catch ME
    fprintf('FAIL: %s\n', ME.message);
end

fprintf('--- Full function call ---\n');
addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/ai_sdd/src');
try
    k = analyzeSingleSubsystem(modelName, sysPath);
    if isfield(k, 'analysisError')
        fprintf('ERROR in knowledge: %s\n', k.analysisError);
    else
        fprintf('OK - description available\n');
    end
catch ME
    fprintf('FUNCTION FAILED: %s\n', ME.message);
    fprintf('STACK:\n');
    for i = 1:numel(ME.stack)
        fprintf('  %s:%d\n', ME.stack(i).file, ME.stack(i).line);
    end
end
exit(0);
