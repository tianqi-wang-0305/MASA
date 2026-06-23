kb = jsondecode(fileread('/Users/wangtianqi/Desktop/autoModeling/work/tst_mdl/Foc_2024b_model_knowledge.json'));
snames = fieldnames(kb.subsystems);
err=0; desc=0; examples={};
for i = 1:numel(snames)
    s = snames{i};
    if isfield(kb.subsystems.(s),'analysisError'), err=err+1; end
    if isfield(kb.subsystems.(s),'description')
        d = string(kb.subsystems.(s).description);
        if strlength(d) > 20 && ~contains(d,'分析失败') && ~contains(d,'描述生成异常')
            desc=desc+1;
            if numel(examples) < 3
                examples{end+1} = sprintf('%s: %s', s, extractBefore(d,150));
            end
        end
    end
end
fprintf('Total: %d\n', numel(snames));
fprintf('With analysisError: %d\n', err);
fprintf('With meaningful descriptions: %d\n', desc);
fprintf('\nSample descriptions:\n');
for i = 1:numel(examples)
    fprintf('  [%d] %s\n', i, examples{i});
end
if desc == 0 && err > 0
    fprintf('\nSample errors:\n');
    cnt = 0;
    for i = 1:numel(snames)
        s = snames{i};
        if isfield(kb.subsystems.(s),'analysisError') && cnt < 2
            fprintf('  %s: %s\n', s, kb.subsystems.(s).analysisError);
            cnt = cnt + 1;
        end
    end
end
exit(0);
