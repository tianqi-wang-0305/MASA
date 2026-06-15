function result = check_io_port_datatype_definition(modelPath)
%CHECK_IO_PORT_DATATYPE_DEFINITION 检查 Simulink 模型所有输入/输出端口是否显式定义了数据类型
%
% 用法:
%   result = check_io_port_datatype_definition('my_model.slx')
%   result = check_io_port_datatype_definition
%
% 说明:
%   - 扫描模型及其子系统中的 Inport / Outport 块
%   - 检查端口数据类型参数是否为显式定义，而不是 Inherit / auto / 空值
%   - 默认通过弹窗选择模型文件；命令行环境下回退到输入路径

if nargin < 1 || strlength(string(modelPath)) == 0
    modelPath = selectModelFileInteractively();
end

modelPath = normalizeModelPath(string(modelPath));
if ~isfile(modelPath)
    error('模型文件不存在: %s', modelPath);
end

[~, modelName, ~] = fileparts(modelPath);
modelName = string(modelName);
load_system(char(modelPath));
cleanupObj = onCleanup(@() closeLoadedModel(modelName)); %#ok<NASGU>

ports = collectIoPorts(modelName);
if isempty(ports)
    result = buildEmptyResult(modelPath, modelName);
    fprintf('未在模型中找到输入/输出端口。\n');
    fprintf('%s\n', jsonencode(result));
    return;
end

details = repmat(struct( ...
    'Direction', '', ...
    'BlockPath', '', ...
    'BlockName', '', ...
    'DeclaredDataType', '', ...
    'Explicit', false, ...
    'Reason', '', ...
    'CompiledDataType', ''), numel(ports), 1);

violations = {};
explicitCount = 0;
for i = 1:numel(ports)
    portInfo = ports(i);
    declaredType = readDeclaredDataType(portInfo.BlockPath);
    compiledType = readCompiledDataType(portInfo.BlockPath);
    [isExplicit, reason] = isExplicitDataType(declaredType);

    details(i).Direction = portInfo.Direction;
    details(i).BlockPath = char(portInfo.BlockPath);
    details(i).BlockName = char(portInfo.BlockName);
    details(i).DeclaredDataType = char(declaredType);
    details(i).Explicit = isExplicit;
    details(i).Reason = char(reason);
    details(i).CompiledDataType = char(compiledType);

    if isExplicit
        explicitCount = explicitCount + 1;
    else
        violations{end + 1, 1} = sprintf('%s 端口 "%s" 的数据类型未显式定义: %s', ...
            portInfo.Direction, portInfo.BlockPath, declaredType); %#ok<AGROW>
    end
end

result = struct();
result.success = true;
result.model = char(modelPath);
result.model_name = char(modelName);
result.total_ports = numel(ports);
result.explicit_ports = explicitCount;
result.non_explicit_ports = numel(ports) - explicitCount;
result.issues_count = numel(violations);
result.summary = composeSummary(result);
result.violations = violations;
result.details = struct2table(details);
result.report_path = writeHtmlReport(result);

printSummary(result);
fprintf('%s\n', jsonencode(result));
end

function ports = collectIoPorts(modelName)
ports = struct('Direction', {}, 'BlockPath', {}, 'BlockName', {});

inputBlocks = find_system(char(modelName), ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', ...
    'FindAll', 'off', ...
    'Type', 'Block', ...
    'BlockType', 'Inport');
outputBlocks = find_system(char(modelName), ...
    'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', ...
    'FindAll', 'off', ...
    'Type', 'Block', ...
    'BlockType', 'Outport');

for i = 1:numel(inputBlocks)
    blockPath = string(inputBlocks{i});
    ports(end + 1, 1).Direction = '输入'; %#ok<AGROW>
    ports(end).BlockPath = blockPath;
    ports(end).BlockName = string(get_param(blockPath, 'Name'));
end

for i = 1:numel(outputBlocks)
    blockPath = string(outputBlocks{i});
    ports(end + 1, 1).Direction = '输出'; %#ok<AGROW>
    ports(end).BlockPath = blockPath;
    ports(end).BlockName = string(get_param(blockPath, 'Name'));
end
end

function dataType = readDeclaredDataType(blockPath)
dataType = "";
for candidate = ["OutDataTypeStr", "DataType", "PortDataType", "DataTypeStr"]
    try
        value = string(get_param(char(blockPath), char(candidate)));
        if strlength(strtrim(value)) > 0
            dataType = value;
            return;
        end
    catch
    end
end
end

function dataType = readCompiledDataType(blockPath)
dataType = "";
for candidate = ["CompiledPortDataType", "OutDataTypeStr", "DataTypeStr"]
    try
        value = string(get_param(char(blockPath), char(candidate)));
        if strlength(strtrim(value)) > 0
            dataType = value;
            return;
        end
    catch
    end
end
end

function [isExplicit, reason] = isExplicitDataType(dataType)
textValue = strtrim(string(dataType));
if strlength(textValue) == 0
    isExplicit = false;
    reason = "数据类型为空";
    return;
end

lowerValue = lower(textValue);
if startsWith(lowerValue, "inherit") || startsWith(lowerValue, "auto") || contains(lowerValue, "inherited")
    isExplicit = false;
    reason = "继承/自动类型";
    return;
end

if strcmp(lowerValue, "-1") || strcmp(lowerValue, "same")
    isExplicit = false;
    reason = "未显式定义";
    return;
end

isExplicit = true;
reason = "显式定义";
end

function result = buildEmptyResult(modelPath, modelName)
result = struct();
result.success = true;
result.model = char(modelPath);
result.model_name = char(modelName);
result.total_ports = 0;
result.explicit_ports = 0;
result.non_explicit_ports = 0;
result.issues_count = 0;
result.summary = '未找到输入/输出端口。';
result.violations = {};
result.details = table();
end

function summaryText = composeSummary(result)
summaryText = sprintf('共检查 %d 个输入/输出端口，显式定义 %d 个，未显式定义 %d 个。', ...
    result.total_ports, result.explicit_ports, result.non_explicit_ports);
end

function reportPath = writeHtmlReport(result)
reportDir = fullfile(fileparts(result.model), 'reports');
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
reportPath = fullfile(reportDir, sprintf('%s_io_datatype_audit_%s.html', result.model_name, timestamp));
fid = fopen(reportPath, 'w');
if fid == -1
    error('无法创建 HTML 报告文件: %s', reportPath);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n');
fprintf(fid, '<title>%s IO Port Data Type Audit</title>\n', escapeHtml(result.model_name));
fprintf(fid, '<style>body{font-family:Arial,sans-serif;margin:36px;line-height:1.6;color:#1f2d3d;} h1,h2{color:#0f172a;} table{border-collapse:collapse;width:100%%;margin:16px 0;} th,td{border:1px solid #d7dce3;padding:8px;vertical-align:top;text-align:left;} th{background:#f4f7fb;} .ok{color:#1b7f3a;font-weight:600;} .bad{color:#b42318;font-weight:600;} .issue{background:#fdf6f6;border-left:4px solid #e74c3c;padding:10px;margin:8px 0;} .note{background:#f5f8ff;border-left:4px solid #4a77d4;padding:10px;margin:8px 0;} code{background:#eef2ff;padding:2px 6px;border-radius:4px;}</style>\n</head>\n<body>\n');
fprintf(fid, '<h1>Simulink 输入/输出端口数据类型审计报告</h1>\n');
fprintf(fid, '<div class="note">%s</div>\n', escapeHtml(result.summary));

fprintf(fid, '<table>');
writeHtmlRow(fid, '模型名称', result.model_name);
writeHtmlRow(fid, '模型路径', result.model);
writeHtmlRow(fid, '端口总数', num2str(result.total_ports));
writeHtmlRow(fid, '显式定义端口数', num2str(result.explicit_ports));
writeHtmlRow(fid, '未显式定义端口数', num2str(result.non_explicit_ports));
writeHtmlRow(fid, '问题总数', num2str(result.issues_count));
fprintf(fid, '</table>\n');

if isempty(result.violations)
    fprintf(fid, '<p class="ok">所有输入/输出端口的数据类型都已显式定义。</p>\n');
else
    fprintf(fid, '<h2>未显式定义的端口</h2>\n');
    for i = 1:numel(result.violations)
        fprintf(fid, '<div class="issue">%s</div>\n', escapeHtml(result.violations{i}));
    end
end

fprintf(fid, '<h2>端口明细</h2>\n');
fprintf(fid, '<table>');
fprintf(fid, '<tr><th>方向</th><th>块名</th><th>路径</th><th>声明数据类型</th><th>是否显式</th><th>原因</th><th>编译类型</th></tr>');
for i = 1:height(result.details)
    row = result.details(i, :);
    fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>', ...
        escapeHtml(string(row.Direction)), ...
        escapeHtml(string(row.BlockName)), ...
        escapeHtml(string(row.BlockPath)), ...
        escapeHtml(string(row.DeclaredDataType)), ...
        escapeHtml(string(string(row.Explicit))), ...
        escapeHtml(string(row.Reason)), ...
        escapeHtml(string(row.CompiledDataType)));
end
fprintf(fid, '</table>\n');

fprintf(fid, '<hr><p><em>本报告由 check_io_port_datatype_definition.m 自动生成</em></p>\n');
fprintf(fid, '</body>\n</html>');
end

function writeHtmlRow(fid, key, value)
fprintf(fid, '<tr><th>%s</th><td>%s</td></tr>', escapeHtml(string(key)), escapeHtml(string(value)));
end

function text = escapeHtml(text)
text = string(text);
text = replace(text, '&', '&amp;');
text = replace(text, '<', '&lt;');
text = replace(text, '>', '&gt;');
text = replace(text, '"', '&quot;');
end

function printSummary(result)
fprintf('模型: %s\n', result.model_name);
fprintf('端口总数: %d\n', result.total_ports);
fprintf('显式定义: %d\n', result.explicit_ports);
fprintf('未显式定义: %d\n', result.non_explicit_ports);
if ~isempty(result.violations)
    fprintf('发现问题:\n');
    for i = 1:numel(result.violations)
        fprintf('  - %s\n', result.violations{i});
    end
end
end

function closeLoadedModel(modelName)
if bdIsLoaded(char(modelName))
    close_system(char(modelName), 0);
end
end

function pathValue = normalizeModelPath(pathValue)
pathValue = replace(string(pathValue), '/', filesep);
pathValue = replace(pathValue, '\\', filesep);
end

function modelPath = selectModelFileInteractively()
if usejava('desktop')
    [fileName, folderName] = uigetfile({'*.slx;*.mdl', 'Simulink Models (*.slx, *.mdl)'}, ...
        'Select a Simulink model file');
    if isequal(fileName, 0)
        error('未选择模型文件。');
    end
    modelPath = fullfile(folderName, fileName);
    return;
end

modelPath = input('请输入 Simulink 模型文件完整路径: ', 's');
if strlength(string(modelPath)) == 0
    error('未提供模型文件路径。');
end
end