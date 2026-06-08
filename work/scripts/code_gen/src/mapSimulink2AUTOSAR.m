%% batchCodeMapping.m
% 批量设置 / 删除 AUTOSAR Code Mapping
% 特点：
% 1) 支持手动多选模块批量处理
% 2) 自动清空历史选中状态，再恢复目标模块
% 3) 自动取消父级模块选中
% 4) 如果同时选中了父级和子级，仅保留子级模块
% 5) 仅处理当前模块自身输出端口，不扩散到父级
% 6) 兼容 root model 类型，避免 unique(rootModels) 报错

clc;

%% ===================== 配置区 =====================
% AUTOSAR属性配置
AR_DATA_ACCESS_MODE = 'StaticMemory';
AR_SW_CALIBRATION_ACCESS = 'ReadWrite';
AR_SW_ADDR_METHOD = 'VAR';

%% ===================== 第1步：获取当前手动选中的模块 =====================
selectedNow = find_system(0, ...
    'Type', 'Block', ...
    'Selected', 'on');

if isempty(selectedNow)
    error('请先在Simulink模型中手动选中需要处理的模块。');
end

% 统一转成 cellstr
selectedNow = normalizeToCellStr(selectedNow);

% 去重并保持顺序
selectedNow = unique(selectedNow, 'stable');

disp(['检测到手动选中的模块数量: ', num2str(numel(selectedNow))]);
for i = 1:numel(selectedNow)
    disp(['  [', num2str(i), '] ', selectedNow{i}]);
end

%% ===================== 第2步：过滤父级模块，仅保留最末级目标模块 =====================
filteredBlocks = removeParentBlocks(selectedNow);

disp('父级过滤后的最终目标模块:');
for i = 1:numel(filteredBlocks)
    disp(['  [', num2str(i), '] ', filteredBlocks{i}]);
end

if isempty(filteredBlocks)
    error('过滤父级模块后，没有可处理的目标模块。');
end

%% ===================== 第3步：清空所有历史选中状态 =====================
allBlocks = find_system(0, 'Type', 'Block');
allBlocks = normalizeToCellStr(allBlocks);

for i = 1:numel(allBlocks)
    try
        set_param(allBlocks{i}, 'Selected', 'off');
    catch
        % 忽略无效对象
    end
end

disp('已清空所有历史选中状态。');

%% ===================== 第4步：恢复目标模块选中状态 =====================
for i = 1:numel(filteredBlocks)
    try
        set_param(filteredBlocks{i}, 'Selected', 'on');
    catch ME
        warning('恢复选中失败: %s, 原因: %s', filteredBlocks{i}, ME.message);
    end
end

disp(['已恢复目标模块选中状态，共 ', num2str(numel(filteredBlocks)), ' 个模块。']);

%% ===================== 第5步：显式取消这些模块所有父级的选中状态 =====================
for i = 1:numel(filteredBlocks)
    cancelParentSelection(filteredBlocks{i});
end

disp('已取消所有父级模块的选中状态，仅保留目标模块。');

%% ===================== 第6步：操作选择 =====================
operationChoice = questdlg( ...
    '请选择要执行的操作：', ...
    '操作选择', ...
    '配置AUTOSAR属性', ...
    '删除Code Mapping', ...
    '取消', ...
    '配置AUTOSAR属性');

if isempty(operationChoice) || strcmp(operationChoice, '取消')
    disp('用户取消操作。');
    return;
end

%% ===================== 第7步：按根模型分组 =====================
rootModels = cell(size(filteredBlocks));

for i = 1:numel(filteredBlocks)
    rootModels{i} = getRootModelSafe(filteredBlocks{i});
end

% 去掉空项
validIdx = ~cellfun(@isempty, rootModels);
filteredBlocks = filteredBlocks(validIdx);
rootModels = rootModels(validIdx);

if isempty(filteredBlocks)
    error('没有有效的目标模块可处理。');
end

% 再次标准化为 cell array of char
rootModels = normalizeToCellStr(rootModels);

% 唯一化根模型
uniqModels = unique(rootModels, 'stable');

disp('检测到涉及的根模型:');
for i = 1:numel(uniqModels)
    disp(['  - ', uniqModels{i}]);
end

%% ===================== 第8步：逐模型获取映射对象 =====================
slMapDict = containers.Map;

for i = 1:numel(uniqModels)
    mdl = uniqModels{i};
    try
        slMapDict(mdl) = autosar.api.getSimulinkMapping(mdl);
        disp(['已获取AUTOSAR映射对象: ', mdl]);
    catch ME
        warning('获取模型 %s 的 AUTOSAR Mapping 失败: %s', mdl, ME.message);
    end
end

%% ===================== 第9步：批量处理模块 =====================
successCount = 0;
skipCount = 0;
failCount = 0;

for i = 1:numel(filteredBlocks)
    blockPath = filteredBlocks{i};
    disp('--------------------------------------------------');
    disp(['开始处理模块: ', blockPath]);

    try
        mdl = getRootModelSafe(blockPath);

        if ~isKey(slMapDict, mdl)
            warning('模块 %s 所属模型 %s 无可用映射对象，跳过。', blockPath, mdl);
            skipCount = skipCount + 1;
            continue;
        end

        slMap = slMapDict(mdl);

        blockHandle = get_param(blockPath, 'Handle');
        portHandles = get_param(blockHandle, 'PortHandles');

        outports = [];
        if isfield(portHandles, 'Outport')
            outports = portHandles.Outport;
        end

        outports = normalizePortHandles(outports);

        if isempty(outports)
            warning('模块 %s 无输出端口，跳过。', blockPath);
            skipCount = skipCount + 1;
            continue;
        end

        handledAnyPort = false;

        for p = 1:numel(outports)
            portH = outports(p);

            % 校验端口确实属于当前模块
            if ~isPortBelongsToBlock(portH, blockPath)
                warning('端口 %d 不属于当前模块 %s，跳过。', p, blockPath);
                continue;
            end

            try
                switch operationChoice
                    case '配置AUTOSAR属性'
                        ensureSignalMapped(slMap, portH);

                        mapSignal(slMap, portH, ...
                            AR_DATA_ACCESS_MODE, ...
                            'SwCalibrationAccess', AR_SW_CALIBRATION_ACCESS, ...
                            'SwAddrMethod', AR_SW_ADDR_METHOD);

                        disp(['配置成功: ', blockPath, ' (端口 ', num2str(p), ')']);
                        handledAnyPort = true;

                    case '删除Code Mapping'
                        if isSignalMapped(slMap, portH)
                            removeSignal(slMap, portH);
                            disp(['删除成功: ', blockPath, ' (端口 ', num2str(p), ')']);
                            handledAnyPort = true;
                        else
                            warning('模块 %s 端口 %d 未建立Code Mapping，无需删除。', blockPath, p);
                        end
                end
            catch MEp
                warning('处理模块 %s 的端口 %d 失败: %s', blockPath, p, MEp.message);
            end
        end

        if handledAnyPort
            successCount = successCount + 1;
        else
            skipCount = skipCount + 1;
        end

    catch ME
        warning('处理模块失败: %s, 原因: %s', blockPath, ME.message);
        failCount = failCount + 1;
    end
end

%% ===================== 第10步：完成提示 =====================
disp('==================================================');
disp('操作完成。');
disp(['成功模块数: ', num2str(successCount)]);
disp(['跳过模块数: ', num2str(skipCount)]);
disp(['失败模块数: ', num2str(failCount)]);

%% ===================== 本地函数区 =====================

function out = normalizeToCellStr(in)
    % 将输入统一转成 cell array of char
    if isempty(in)
        out = {};
        return;
    end

    if ischar(in)
        out = {in};
        return;
    end

    if isstring(in)
        out = cellstr(in);
        return;
    end

    if isnumeric(in)
        out = cell(size(num2cell(in)));
        for k = 1:numel(in)
            try
                out{k} = getfullname(in(k));
            catch
                try
                    out{k} = get_param(in(k), 'Name');
                catch
                    out{k} = char(string(in(k)));
                end
            end
        end
        return;
    end

    if iscell(in)
        out = cell(size(in));
        for k = 1:numel(in)
            item = in{k};
            if ischar(item)
                out{k} = item;
            elseif isstring(item)
                out{k} = char(item);
            elseif isnumeric(item)
                try
                    out{k} = getfullname(item);
                catch
                    try
                        out{k} = get_param(item, 'Name');
                    catch
                        out{k} = char(string(item));
                    end
                end
            else
                out{k} = char(string(item));
            end
        end
        return;
    end

    out = {char(string(in))};
end

function filtered = removeParentBlocks(blocks)
    % 如果一个块是另一个块的父级路径，则剔除父级，仅保留子级
    blocks = normalizeToCellStr(blocks);
    keep = true(size(blocks));

    for i = 1:numel(blocks)
        bi = blocks{i};
        for j = 1:numel(blocks)
            if i == j
                continue;
            end
            bj = blocks{j};

            % 如果 bj 是 bi 的子级，则 bi 应剔除
            if startsWithPath(bj, bi)
                keep(i) = false;
                break;
            end
        end
    end

    filtered = blocks(keep);
    filtered = unique(filtered, 'stable');
end

function tf = startsWithPath(childPath, parentPath)
    % 判断 childPath 是否为 parentPath 的子路径
    if strcmp(childPath, parentPath)
        tf = false; % 相同路径不算父子
        return;
    end

    prefix = [parentPath, '/'];
    tf = strncmp(childPath, prefix, length(prefix));
end

function cancelParentSelection(blockPath)
    % 显式取消 blockPath 的所有父级块选中状态
    current = blockPath;

    while true
        try
            parent = get_param(current, 'Parent');
        catch
            break;
        end

        if isempty(parent)
            break;
        end

        try
            set_param(parent, 'Selected', 'off');
        catch
            % 某些顶层对象可能不能设置，忽略
        end

        current = parent;
    end
end

function mdl = getRootModelSafe(blockPath)
    % 安全获取根模型名，并统一返回 char
    try
        mdl = bdroot(blockPath);
    catch
        mdl = '';
        return;
    end

    if isempty(mdl)
        mdl = '';
    elseif isstring(mdl)
        mdl = char(mdl);
    elseif isnumeric(mdl)
        try
            mdl = get_param(mdl, 'Name');
        catch
            mdl = char(string(mdl));
        end
    elseif ~ischar(mdl)
        mdl = char(string(mdl));
    end
end

function outports = normalizePortHandles(rawOutports)
    % 统一输出端口句柄为一维数值数组
    if isempty(rawOutports)
        outports = [];
        return;
    end

    if iscell(rawOutports)
        tmp = [];
        for i = 1:numel(rawOutports)
            item = rawOutports{i};
            if isnumeric(item)
                tmp = [tmp; item(:)]; %#ok<AGROW>
            end
        end
        outports = unique(tmp(:))';
    elseif isnumeric(rawOutports)
        outports = unique(rawOutports(:))';
    else
        outports = [];
    end
end

function tf = isPortBelongsToBlock(portH, blockPath)
    tf = false;
    try
        parentBlk = get_param(portH, 'Parent');
        if ischar(parentBlk) || isstring(parentBlk)
            tf = strcmp(char(parentBlk), blockPath);
        else
            parentPath = getfullname(parentBlk);
            tf = strcmp(parentPath, blockPath);
        end
    catch
        tf = false;
    end
end

function tf = isSignalMapped(slMap, portH)
    tf = false;
    try
        getSignal(slMap, portH, 'SwCalibrationAccess');
        tf = true;
    catch
        tf = false;
    end
end

function ensureSignalMapped(slMap, portH)
    if ~isSignalMapped(slMap, portH)
        addSignal(slMap, portH);
    end
end