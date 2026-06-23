addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;
addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/ai_sdd/src');

% Directly call the inner functions with the EXACT same params as the real call
modelPath = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx';
excelPath = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b_signals_cal.xlsx';
[modelDir, modelBase, ~] = fileparts(modelPath);
modelName = string(modelBase);
load_system(modelPath);

sysPath = 'Foc_2024b/FieldOrientedControl';

% Call model_overview exactly as in analyzeModelDeepForSDD
fprintf('model_overview...\n');
try
    ov = model_overview(char(modelName), "root", "full");
    fprintf('OK\n');
catch ME, fprintf('FAIL: %s\n', ME.message); end

% Call model_read with scopeId as the real function does
scopeId = regexprep(string(get_param(sysPath, 'SID')), '^blk_', '');
fprintf('\nmodel_read with scopeId (type=%s, val=%s)...\n', class(scopeId), scopeId);
try
    r = model_read(char(modelName), "root", scopeId);
    fprintf('OK\n');
catch ME, fprintf('FAIL: %s\n', ME.message); end

% model_query_params with scopeId
fprintf('\nmodel_query_params...\n');
try
    r = model_query_params(char(modelName), jsonencode({scopeId}), jsonencode({"all"}), "false");
    fprintf('OK\n');
catch ME, fprintf('FAIL: %s\n', ME.message); end

% model_resolve_params
fprintf('\nmodel_resolve_params...\n');
try
    r = model_resolve_params(char(modelName), jsonencode({"Kp"}));
    fprintf('OK\n');
catch ME, fprintf('FAIL: %s\n', ME.message); end

fprintf('\n=== Now test the EXACT function call inside analyzeModelDeepForSDD ===\n');
% The issue might be the outer catch - let me check which line throws
% by running the full flow
fprintf('Calling analyzeModelDeepForSDD for single subsys...\n');
try
    % This function exists only inside analyzeModelDeepForSDD.m
    % So we can't call it directly. Let's use a different approach.
    fprintf('Cannot call local function from outside.\n');
catch ME
    fprintf('FAIL: %s\n', ME.message);
end

fprintf('\n=== Checking model_read with char scopeId (not string) ===\n');
scopeIdChar = char(scopeId);
try
    r = model_read(char(modelName), "root", scopeIdChar);
    fprintf('OK with char scopeId\n');
catch ME, fprintf('FAIL: %s\n', ME.message); end

fprintf('\n=== Checking model_query_params with char scopeId ===\n');
try
    r = model_query_params(char(modelName), jsonencode({scopeIdChar}), jsonencode({"all"}), "false");
    fprintf('OK with char scopeId\n');
catch ME, fprintf('FAIL: %s\n', ME.message); end

exit(0);
