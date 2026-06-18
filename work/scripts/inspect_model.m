load_system('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b.slx');
top = find_system('Foc_2024b','SearchDepth',1,'Type','Block');
fprintf('Top-level blocks: %d\n', numel(top));
for i = 1:numel(top)
    try
        bt = get_param(top{i},'BlockType');
        n = get_param(top{i},'Name');
        fprintf('  %s (%s)\n', n, bt);
    catch, end
end
io = find_system('Foc_2024b','LookUnderMasks','all','BlockType','Inport');
fprintf('\nTotal Inports (all levels): %d\n', numel(io));
for i = 1:min(5,numel(io))
    fprintf('  Inport: %s\n', io{i});
end
io2 = find_system('Foc_2024b','LookUnderMasks','all','BlockType','Outport');
fprintf('Total Outports (all levels): %d\n', numel(io2));
for i = 1:min(5,numel(io2))
    fprintf('  Outport: %s\n', io2{i});
end
allB = find_system('Foc_2024b','LookUnderMasks','all','Type','Block');
calCount = 0;
for i = 1:numel(allB)
    n = get_param(allB{i},'Name');
    if startsWith(n,'cal_'), calCount = calCount + 1; end
end
fprintf('Total cal_ blocks: %d\n', calCount);
exit(0);
