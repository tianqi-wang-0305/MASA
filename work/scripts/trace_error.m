addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;
load_system('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx');

modelName = 'Foc_2024b';
sysPath = 'Foc_2024b/FieldOrientedControl';

fprintf('Step 1: get_param\n');
name = string(get_param(sysPath, 'Name'));
fprintf('  OK: %s\n', name);

fprintf('Step 2: resolveBlockScopeId\n');
sidValue = string(get_param(sysPath, 'SID'));
scopeId = regexprep(sidValue, '^blk_', '');
fprintf('  scopeId=%s\n', scopeId);

fprintf('Step 3: model_read\n');
try
    r = model_read(modelName, "root", scopeId);
    fprintf('  OK\n');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

fprintf('Step 4: model_query_params\n');
try
    r = model_query_params(modelName, jsonencode({scopeId}), jsonencode({"all"}), "false");
    fprintf('  OK\n');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

fprintf('Step 5: getDirectSubsystems\n');
try
    children = find_system(sysPath, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    fprintf('  OK: %d children\n', numel(children));
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

fprintf('Step 6: summarizeDominantBlocks\n');
try
    blocks = find_system(sysPath, 'SearchDepth', 1, 'Type', 'Block');
    fprintf('  OK: %d blocks\n', numel(blocks));
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

fprintf('Step 7: getDirectPortNames\n');
try
    inports = find_system(sysPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    fprintf('  OK: %d inports\n', numel(inports));
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

fprintf('\nAll steps complete\n');
exit(0);
