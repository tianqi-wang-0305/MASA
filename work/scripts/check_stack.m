kb = jsondecode(fileread('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b_model_knowledge.json'));
snames = fieldnames(kb.subsystems);
for i = 1:2
    s = snames{i};
    fprintf('=== %s ===\n', s);
    if isfield(kb.subsystems.(s),'analysisError')
        fprintf('%s\n', kb.subsystems.(s).analysisError);
    end
end
exit(0);
