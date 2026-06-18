addpath('/Users/wangtianqi/Desktop/autoModeling/work/scripts/data_mng/src');
r = exportSignalsToExcel('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx');
fprintf('Result: %d in, %d out\n', r.inputCount, r.outputCount);
exit(0);