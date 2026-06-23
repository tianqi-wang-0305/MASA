addpath('/Users/wangtianqi/Desktop/autoModeling/work/simulink-agentic-toolkit');
satk_initialize;
addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/ai_sdd/src');

% Patch analyzeSingleSubsystem to catch and print stack
% Call the outer function, it will fail, and we'll see the error via the output

modelPath = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx';
excelPath = '/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b_signals_cal.xlsx';

fprintf('Calling analyzeModelDeepForSDD...\n');
try
    kf = analyzeModelDeepForSDD(modelPath, excelPath);
    fprintf('KB: %s\n', kf);
catch ME
    fprintf('TOP LEVEL ERROR: %s\n', ME.message);
    for i = 1:numel(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
    end
end
exit(0);
