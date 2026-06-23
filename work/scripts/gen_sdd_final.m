addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;
addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/ai_sdd/src');
kb = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b_model_knowledge.json';
if isfile(kb), delete(kb); end
fprintf('Generating SDD...\n');
pdf = DdGeneration_AI('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx', ...
    '', 'ForceAnalyze', true);
fprintf('\nPDF: %s\n', pdf);
exit(0);
