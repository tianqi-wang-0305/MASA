% ===================== 第一步：先保存当前手动选中的模块（核心修复） =====================
% 1. 保存用户手动选中的模块句柄（在清空前先记录）
userSelectedHandles = [];
singleHandle = gcbh; % 获取当前选中模块的句柄
if ~isempty(singleHandle) && strcmp(get_param(singleHandle, 'Selected'), 'on')
    userSelectedHandles = {singleHandle}; % 单模块选中
else
    % 多模块选中场景
    tempHandles = find_system(0, 'Type', 'Block', 'Selected', 'on');
    if ~iscell(tempHandles)
        if isscalar(tempHandles) && ~isempty(tempHandles)
            tempHandles = {tempHandles};
        else
            tempHandles = num2cell(tempHandles);
        end
    end
    for i = 1:length(tempHandles)
        h = tempHandles{i};
        if strcmp(get_param(h, 'Selected'), 'on')
            userSelectedHandles{end+1} = h;
        end
    end
end

% 校验：用户必须先选中模块才能继续
if isempty(userSelectedHandles)
    error('请先在Simulink模型中手动选中需要处理的模块！');
end

% 2. 清空所有模块的选中状态（清除历史残留）
allBlocks = find_system(0, 'Type', 'Block');
if iscell(allBlocks)
    for i = 1:length(allBlocks)
        set_param(allBlocks{i}, 'Selected', 'off');
    end
else
    for i = 1:length(allBlocks)
        set_param(allBlocks(i), 'Selected', 'off');
    end
end
disp('🔄 已清空所有历史选中状态残留');

% 3. 恢复用户手动选中的模块（核心：保留目标模块选中状态）
for i = 1:length(userSelectedHandles)
    set_param(userSelectedHandles{i}, 'Selected', 'on');
end
disp(['✅ 已恢复你手动选中的', num2str(length(userSelectedHandles)), '个模块的选中状态']);

% ===================== 功能选择：配置属性 / 删除Code Mapping =====================
operationChoice = questdlg(...
    '请选择要执行的操作：', ...
    '操作选择', ...
    '配置AUTOSAR属性', ...
    '删除Code Mapping', ...
    '配置AUTOSAR属性');

% ===================== 核心函数：获取模块所属根模型 =====================
function modelName = getRootModel(blockPath)
    currentPath = blockPath;
    while ~isempty(get_param(currentPath, 'Parent'))
        currentPath = get_param(currentPath, 'Parent');
    end
    modelName = currentPath;
end

% ===================== 辅助函数：检查信号是否已添加 =====================
function isAdded = isSignalAdded(slMap, portHandle)
    isAdded = false;
    try
        getSignal(slMap, portHandle, 'SwCalibrationAccess');
        isAdded = true;
    catch
        isAdded = false;
    end
end

% ===================== 辅助函数：强制将端口句柄转为一维标量数组 =====================
function scalarPortHandles = convertToScalarPortHandles(portHandlesOut)
    if isempty(portHandlesOut)
        scalarPortHandles = [];
        return;
    end
    flattened = portHandlesOut(:);
    scalarPortHandles = cell2mat(arrayfun(@(x) x, flattened, 'UniformOutput', false));
    scalarPortHandles = unique(scalarPortHandles);
end

% ===================== 辅助函数：兼容获取模块路径（支持子系统） =====================
function blockPath = getBlockPathCompat(blockHandle)
    try
        blockPath = get_param(blockHandle, 'Path');
    catch
        blockName = get_param(blockHandle, 'Name');
        blockParent = get_param(blockHandle, 'Parent');
        if isempty(get_param(blockParent, 'Parent'))
            blockPath = [blockParent, '/', blockName];
        else
            parentHandle = get_param(blockParent, 'Handle');
            parentPath = getBlockPathCompat(parentHandle);
            blockPath = [parentPath, '/', blockName];
        end
    end
end

% ===================== 主逻辑：严格限定仅当前手动选中模块 =====================
% 1. 重新获取保留的选中模块（确保无历史残留）
currentSelectedHandles = [];
for i = 1:length(userSelectedHandles)
    h = userSelectedHandles{i};
    if strcmp(get_param(h, 'Selected'), 'on')
        currentSelectedHandles{end+1} = h;
    end
end

% 校验：仅保留当前手动选中的模块
selectedBlocks = {};
for i = 1:length(currentSelectedHandles)
    blockHandle = currentSelectedHandles{i};
    blockPath = getBlockPathCompat(blockHandle);
    selectedBlocks{end+1} = blockPath;
    disp(['✅仅处理当前手动选中的模块：', blockPath]);
end

if isempty(selectedBlocks)
    error('选中模块丢失，请重新选中后重试！');
end
disp(['🔍最终确认处理模块数量：', num2str(length(selectedBlocks))]);

% 2. 自动识别根模型（仅基于当前选中模块）
firstBlockPath = selectedBlocks{1};
hModel = getRootModel(firstBlockPath);
disp(['📌自动识别根模型：', hModel]);

% 3. 获取AUTOSAR映射句柄
slMap = autosar.api.getSimulinkMapping(hModel);

% 4. 遍历选中模块（端口句柄与当前模块强绑定）
for i = 1:length(selectedBlocks)
    blockPath = selectedBlocks{i};
    disp(['📝开始处理：', blockPath]);
    
    % 强制校验：仅处理当前模块的端口，不关联父级
    blockHandle = get_param(blockPath, 'Handle'); % 精准获取当前模块句柄
    portHandles = get_param(blockHandle, 'portHandles'); % 仅取当前模块的端口
    rawOutportHandles = portHandles.Outport;
    
    if isempty(rawOutportHandles)
        warning('模块%s无输出端口，跳过', blockPath);
        continue;
    end
    
    % 标量化端口句柄
    outportHandles = convertToScalarPortHandles(rawOutportHandles);
    if isempty(outportHandles)
        warning('模块%s端口句柄无效，跳过', blockPath);
        continue;
    end
    
    % 遍历当前模块的端口（仅当前模块，无父级扩散）
    for portIdx = 1:length(outportHandles)
        singlePort = outportHandles(portIdx);
        if ~isscalar(singlePort) || ~isnumeric(singlePort)
            warning('端口%d非标量，跳过', portIdx);
            continue;
        end
        
        % 最终校验：端口是否属于当前模块（杜绝父级端口混入）
        portBlockPath = '';
        try
            portParentHandle = get_param(singlePort, 'Parent');
            portBlockPath = getBlockPathCompat(portParentHandle);
        catch
            portBlockPath = '';
        end
        if ~strcmp(portBlockPath, blockPath)
            warning('端口%d属于非当前模块%s，跳过', portIdx, portBlockPath);
            continue;
        end
        
        try
            if strcmp(operationChoice, '配置AUTOSAR属性')
                addSignal(slMap, singlePort);
                mapSignal(slMap, singlePort, ...
                    'StaticMemory', ...
                    'SwCalibrationAccess', 'ReadWrite', ...
                    'SwAddrMethod', 'VAR');
                disp(['✅ 配置成功：', blockPath, ' (端口', num2str(portIdx), ')']);
            elseif strcmp(operationChoice, '删除Code Mapping')
                if isSignalAdded(slMap, singlePort)
                    removeSignal(slMap, singlePort);
                    disp(['🗑️ 删除成功：', blockPath, ' (端口', num2str(portIdx), ')']);
                else
                    warning('端口%d无Code Mapping，无需删除', portIdx);
                end
            end
        catch err
            warning('处理端口%d失败：%s', portIdx, err.message);
            continue;
        end
    end
end

disp(['🎉 操作完成！仅处理了手动选中的模块，无任何父级模块连带配置']);