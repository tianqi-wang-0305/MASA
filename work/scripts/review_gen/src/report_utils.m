function reportPath = report_utils(auditResult)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
reportDir = fullfile(fileparts(auditResult.model), 'reports');
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end

reportPath = fullfile(reportDir, sprintf('%s_audit_%s.html', auditResult.model_name, timestamp));
fid = fopen(reportPath, 'w');
if fid == -1
    error('无法创建报告文件: %s', reportPath);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n<title>%s 模型审计报告</title>\n', auditResult.model_name);
fprintf(fid, '<style>body{font-family:Arial,sans-serif;margin:36px;line-height:1.6;} h1,h2{color:#1f2d3d;} table{border-collapse:collapse;width:100%%;margin:16px 0;} td,th{border:1px solid #d7dce3;padding:8px;vertical-align:top;} th{background:#f4f7fb;text-align:left;} .ok{color:#1b7f3a;} .issue{background:#fdf6f6;border-left:4px solid #e74c3c;padding:10px;margin:8px 0;} .note{background:#f5f8ff;border-left:4px solid #4a77d4;padding:10px;margin:8px 0;} pre{white-space:pre-wrap;word-break:break-word;background:#0f172a;color:#e2e8f0;padding:14px;border-radius:6px;}</style>\n</head>\n<body>\n');
fprintf(fid, '<h1>Simulink 静态审计报告</h1>\n');
fprintf(fid, '<table>');
writeRow(fid, '模型名称', auditResult.model_name);
writeRow(fid, '模型路径', auditResult.model);
writeRow(fid, '问题总数', num2str(auditResult.issues_count));
writeRow(fid, '命名违规', num2str(auditResult.naming_count));
writeRow(fid, '连线违规', num2str(auditResult.connection_count));
writeRow(fid, '层级违规', num2str(auditResult.hierarchy_count));
writeRow(fid, 'Model Advisor 问题', num2str(auditResult.model_advisor_count));
writeRow(fid, '最大层级深度', num2str(auditResult.hierarchy.maxDepth));
writeRow(fid, '子系统总数', num2str(auditResult.hierarchy.subsystemCount));
writeRow(fid, '顶层模块数', num2str(auditResult.hierarchy.topLevelBlockCount));
fprintf(fid, '</table>');

if auditResult.issues_count == 0
    fprintf(fid, '<p class="ok">未发现规范性问题。</p>\n');
else
    fprintf(fid, '<h2>问题列表</h2>\n');
    writeIssueSection(fid, '命名问题', auditResult.issue_groups.naming);
    writeIssueSection(fid, '连线问题', auditResult.issue_groups.connection);
    writeIssueSection(fid, '层级问题', auditResult.issue_groups.hierarchy);
    writeIssueSection(fid, 'Model Advisor 问题', auditResult.issue_groups.modelAdvisor);
end

fprintf(fid, '<h2>Model Advisor 输出</h2>\n');
fprintf(fid, '<div class="note">已执行的检查项数量：%d</div>\n', numel(auditResult.model_advisor.check_ids));
if isfield(auditResult.model_advisor, 'raw_output') && ~isempty(auditResult.model_advisor.raw_output)
    fprintf(fid, '<pre>%s</pre>\n', escapeHtml(auditResult.model_advisor.raw_output));
else
    fprintf(fid, '<p>未返回 Model Advisor 输出文本。</p>\n');
end

fprintf(fid, '<h2>建议的后续检查</h2>\n');
fprintf(fid, '<ul>\n');
fprintf(fid, '<li>检查重复命名、同层同名和层级内别名冲突。</li>\n');
fprintf(fid, '<li>检查未命名信号、总线边界和跨层级连线。</li>\n');
fprintf(fid, '<li>检查模型参考、状态机和条件执行子系统的一致性。</li>\n');
fprintf(fid, '<li>检查注释、文档块和需求追踪是否齐全。</li>\n');
fprintf(fid, '</ul>\n');

fprintf(fid, '<hr><p><em>本报告由 Simulink Static Skill 自动生成</em></p>\n</body>\n</html>');
fprintf('报告已生成: %s\n', reportPath);
end

function writeRow(fid, key, value)
fprintf(fid, '<tr><th>%s</th><td>%s</td></tr>', escapeHtml(key), escapeHtml(string(value)));
end

function writeIssueSection(fid, titleText, issues)
if isempty(issues)
    return;
end

fprintf(fid, '<h3>%s</h3>\n', escapeHtml(titleText));
for i = 1:numel(issues)
    fprintf(fid, '<div class="issue">%s</div>\n', escapeHtml(string(issues{i})));
end
end

function text = escapeHtml(text)
text = string(text);
text = replace(text, '&', '&amp;');
text = replace(text, '<', '&lt;');
text = replace(text, '>', '&gt;');
text = replace(text, '"', '&quot;');
end