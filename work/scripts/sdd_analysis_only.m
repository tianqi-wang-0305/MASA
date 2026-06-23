%% SDD Analysis only (no PDF rendering, which needs GUI)
addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;
addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/ai_sdd/src');

kbPath = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b_model_knowledge.json';
if isfile(kbPath), delete(kbPath); end

fprintf('=== Running deep analysis ===\n');
analyzeModelDeepForSDD('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx', '');

fprintf('\n=== KB generated ===\n');
if isfile(kbPath)
    d = dir(kbPath);
    fprintf('KB file: %s (%d bytes)\n', kbPath, d.bytes);
end

fprintf('\n=== To generate PDF, run in MATLAB GUI: ===\n');
fprintf('addpath(''/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit'');\n');
fprintf('addpath(''/Users/wangtianqi/Desktop/autoModeling/work/scripts/ai_sdd/src'');\n');
fprintf('satk_initialize;\n');
fprintf('DdGeneration_AI(''...Foc_2024b.slx'', '''', ''ForceAnalyze'', false);\n');
