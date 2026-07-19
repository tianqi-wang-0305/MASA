function result = autoSetPortDataTypes(modelPath, varargin)
% autoSetPortDataTypes 按信号名前缀自动设置端口数据类型
%   扫描模型中所有 Inport/Outport 块，根据信号名前缀自动设置 OutDataTypeStr。
%
%   命名前缀规则:
%     s8*/s08*   → int8
%     s16*       → int16
%     s32*       → int32
%     u8*/u08*   → uint8
%     u16*       → uint16
%     u32*       → uint32
%     f32*       → single
%     f64*       → double
%     b*/bool*   → boolean
%     e*         → Enum: int8 (枚举默认)
%     (其他)     → 保持原有类型不做修改
%
%   用法:
%     result = autoSetPortDataTypes('Model.slx');
%     result = autoSetPortDataTypes('Model.slx', 'Recurse', false);
%     result = autoSetPortDataTypes('Model.slx', 'Report', true);
%
%   输入:
%     modelPath  - 模型文件路径
%     'Recurse'  - 是否递归扫描子系统内部 (默认 true)
%     'Report'   - 是否生成 HTML 报告 (默认 true)
%
%   输出:
%     result     - 结构体包含 changed/skipped/errors 统计

    fprintf('=== 按前缀自动设置端口数据类型 ===\n\n');
    result = struct('changed', {{}}, 'skipped', {{}}, 'errors', {{}}, ...
        'totalScanned', 0, 'totalChanged', 0);

    %% 解析输入
    p = inputParser;
    addRequired(p, 'modelPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Recurse', true, @islogical);
    addParameter(p, 'Report', true, @islogical);
    parse(p, modelPath, varargin{:});

    modelPath = char(p.Results.modelPath);
    doRecurse = p.Results.Recurse;
    doReport = p.Results.Report;

    %% 加载模型
    [modelDir, modelName, ext] = fileparts(modelPath);
    if isempty(ext)
        modelPath = fullfile(modelDir, [modelName, '.slx']);
    end
    if ~bdIsLoaded(modelName)
        try
            load_system(modelPath);
        catch ME
            error('无法加载模型 %s: %s', modelPath, ME.message);
        end
    end

    %% 收集所有端口
    if doRecurse
        searchDepth = 1; % find_system 递归时用 LookUnderMasks
        allBlocks = find_system(modelName, 'LookUnderMasks', 'all', ...
            'FollowLinks', 'on', 'Type', 'Block');
    else
        searchDepth = 1;
        allBlocks = find_system(modelName, 'SearchDepth', 1, 'Type', 'Block');
    end

    % 过滤出 Inport 和 Outport
    inports = {};
    outports = {};
    for i = 1:numel(allBlocks)
        try
            bt = get_param(allBlocks{i}, 'BlockType');
            if strcmp(bt, 'Inport')
                inports{end+1} = allBlocks{i}; %#ok<AGROW>
            elseif strcmp(bt, 'Outport')
                outports{end+1} = allBlocks{i}; %#ok<AGROW>
            end
        catch
        end
    end

    allPorts = [inports, outports];
    result.totalScanned = numel(allPorts);
    fprintf('找到 %d 个 Inport + %d 个 Outport = %d 个端口\n', ...
        numel(inports), numel(outports), result.totalScanned);

    %% 处理每个端口
    changed = {};
    skipped = {};
    errors = {};
    for i = 1:numel(allPorts)
        blkPath = allPorts{i};
        try
            [c, s, e] = processOnePort(blkPath);
            changed = [changed; c]; %#ok<AGROW>
            skipped = [skipped; s]; %#ok<AGROW>
            errors = [errors; e];   %#ok<AGROW>
        catch ME
            errors{end+1} = struct('block', blkPath, 'reason', ME.message); %#ok<AGROW>
        end
    end

    result.changed = changed;
    result.skipped = skipped;
    result.errors = errors;
    result.totalChanged = numel(changed);

    %% 输出摘要
    if doReport
        reportFile = fullfile(modelDir, [modelName, '_type_report.html']);
        generateReport(reportFile, result, modelName);
        fprintf('\n报告已生成: %s\n', reportFile);
    end

    fprintf('\n=== 完成 ===\n');
    fprintf('  扫描: %d 个端口\n', result.totalScanned);
    fprintf('  修改: %d 个\n', result.totalChanged);
    fprintf('  跳过: %d 个（无需修改）\n', numel(skipped));
    if ~isempty(errors)
        fprintf('  错误: %d 个\n', numel(errors));
        for i = 1:min(5, numel(errors))
            fprintf('    ⚠ %s: %s\n', errors{i}.block, errors{i}.reason);
        end
    end
end

%% ================== 端口处理函数 ==================

function [changed, skipped, errors] = processOnePort(blkPath)
% 处理单个端口：读取信号名 → 提取前缀 → 设置数据类型
    changed = {};
    skipped = {};
    errors = {};

    blkName = get_param(blkPath, 'Name');
    currentType = get_param(blkPath, 'OutDataTypeStr');

    % 提取前缀
    prefix = extractPrefix(blkName);

    if isempty(prefix)
        % 无匹配前缀，跳过
        skipped{end+1} = struct('block', blkPath, ...
            'name', blkName, 'reason', '无匹配前缀', ...
            'currentType', currentType, 'suggestedType', '');
        return;
    end

    % 映射到 Simulink 数据类型
    newType = prefixToDataType(prefix);

    if isempty(newType)
        skipped{end+1} = struct('block', blkPath, ...
            'name', blkName, 'reason', sprintf('前缀%s无映射', prefix), ...
            'currentType', currentType, 'suggestedType', '');
        return;
    end

    % 如果已经是正确类型，跳过
    if strcmp(currentType, newType)
        skipped{end+1} = struct('block', blkPath, ...
            'name', blkName, 'reason', '类型已正确', ...
            'currentType', currentType, 'suggestedType', newType);
        return;
    end

    % 如果是 'Inherit: auto' 或 'double'，则修改
    if strcmp(currentType, 'Inherit: auto') || ...
       strcmp(currentType, 'double') || ...
       ~strcmp(currentType, newType)

        % 检查是否试图设置为 double (禁止)
        if strcmp(newType, 'double')
            skipped{end+1} = struct('block', blkPath, ...
                'name', blkName, 'reason', '禁止使用double类型', ...
                'currentType', currentType, 'suggestedType', newType);
            return;
        end

        try
            set_param(blkPath, 'OutDataTypeStr', newType);
            changed{end+1} = struct('block', blkPath, ...
                'name', blkName, 'prefix', prefix, ...
                'oldType', currentType, 'newType', newType);
            fprintf('  ✅ %s: %s → %s\n', blkName, currentType, newType);
        catch ME
            errors{end+1} = struct('block', blkPath, ...
                'name', blkName, 'reason', ME.message); %#ok<AGROW>
        end
    end
end

%% ================== 前缀提取与映射 ==================

function prefix = extractPrefix(signalName)
% 从信号名中提取类型前缀
% 格式: s16VehicleSpeed → s16
%       u8DoorStatus   → u8
%       f32Temperature → f32
%       bEnable        → b
%       boolReady      → bool
    prefix = '';

    % 匹配 's16', 'u8', 'f32', 'b', 'bool', 's32', 'u16', 'u32', 's8', 'u08', 's08', 'f64'
    patterns = {
        '^s16(?=[A-Z])', 's16';
        '^s32(?=[A-Z])', 's32';
        '^s8(?=[A-Z])',  's8';
        '^s08(?=[A-Z])', 's08';
        '^u16(?=[A-Z])', 'u16';
        '^u32(?=[A-Z])', 'u32';
        '^u8(?=[A-Z])',  'u8';
        '^u08(?=[A-Z])', 'u08';
        '^f32(?=[A-Z])', 'f32';
        '^f64(?=[A-Z])', 'f64';
        '^bool(?=[A-Z])','bool';
        '^b(?=[A-Z])',   'b';
        '^e(?=[A-Z])',   'e';
    };

    for i = 1:size(patterns, 1)
        if ~isempty(regexp(signalName, patterns{i,1}, 'once'))
            prefix = patterns{i,2};
            return;
        end
    end
end

function dt = prefixToDataType(prefix)
% 前缀 → Simulink 数据类型映射
    switch prefix
        case {'s8', 's08'}
            dt = 'int8';
        case 's16'
            dt = 'int16';
        case 's32'
            dt = 'int32';
        case {'u8', 'u08'}
            dt = 'uint8';
        case 'u16'
            dt = 'uint16';
        case 'u32'
            dt = 'uint32';
        case 'f32'
            dt = 'single';
        case 'f64'
            dt = 'double';  % 允许但会警告
        case {'b', 'bool'}
            dt = 'boolean';
        case 'e'
            dt = 'int8';    % 枚举默认 int8
        otherwise
            dt = '';
    end
end

%% ================== 报告生成 ==================

function generateReport(reportFile, result, modelName)
    fid = fopen(reportFile, 'w');
    if fid < 0
        warning('无法写入报告: %s', reportFile);
        return;
    end

    fprintf(fid, '<!DOCTYPE html><html><head><meta charset="UTF-8">\n');
    fprintf(fid, '<title>Port Type Report - %s</title>\n', modelName);
    fprintf(fid, '<style>');
    fprintf(fid, 'body{font-family:-apple-system,sans-serif;margin:40px}');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #4CAF50;padding-bottom:10px}');
    fprintf(fid, '.ok{color:#4CAF50}.warn{color:#FF9800}.err{color:#f44336}');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:20px 0}');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:10px;text-align:left}');
    fprintf(fid, 'th{background:#4CAF50;color:white}');
    fprintf(fid, 'tr:nth-child(even){background:#f2f2f2}');
    fprintf(fid, '.summary{background:#e7f3fe;padding:15px;border-radius:5px}');
    fprintf(fid, '</style></head><body>\n');

    fprintf(fid, '<h1>Port Type Report: %s</h1>\n', modelName);
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Scanned:</strong> %d ports</p>\n', result.totalScanned);
    fprintf(fid, '<p><strong>Changed:</strong> %d</p>\n', result.totalChanged);
    fprintf(fid, '<p><strong>Skipped:</strong> %d</p>\n', numel(result.skipped));
    fprintf(fid, '<p><strong>Errors:</strong> %d</p>\n', numel(result.errors));
    fprintf(fid, '</div>\n');

    % Changed table
    if ~isempty(result.changed)
        fprintf(fid, '<h2>Changed Ports</h2>\n<table><tr>');
        fprintf(fid, '<th>Block</th><th>Name</th><th>Prefix</th><th>Old Type</th><th>New Type</th></tr>\n');
        for i = 1:numel(result.changed)
            c = result.changed{i};
            fprintf(fid, '<tr class="ok"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
                c.block, c.name, c.prefix, c.oldType, c.newType);
        end
        fprintf(fid, '</table>\n');
    end

    % Skipped table
    if ~isempty(result.skipped)
        fprintf(fid, '<h2>Skipped Ports</h2>\n<table><tr>');
        fprintf(fid, '<th>Block</th><th>Name</th><th>Reason</th><th>Current Type</th></tr>\n');
        for i = 1:min(50, numel(result.skipped))
            s = result.skipped{i};
            fprintf(fid, '<tr class="warn"><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
                s.block, s.name, s.reason, s.currentType);
        end
        if numel(result.skipped) > 50
            fprintf(fid, '<tr><td colspan="4">... and %d more</td></tr>\n', numel(result.skipped)-50);
        end
        fprintf(fid, '</table>\n');
    end

    % Errors
    if ~isempty(result.errors)
        fprintf(fid, '<h2>Errors</h2>\n<table><tr>');
        fprintf(fid, '<th>Block</th><th>Reason</th></tr>\n');
        for i = 1:numel(result.errors)
            e = result.errors{i};
            fprintf(fid, '<tr class="err"><td>%s</td><td>%s</td></tr>\n', e.block, e.reason);
        end
        fprintf(fid, '</table>\n');
    end

    fprintf(fid, '</body></html>\n');
    fclose(fid);
end
