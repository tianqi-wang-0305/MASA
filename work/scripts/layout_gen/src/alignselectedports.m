% alignselectedports.m
% 功能：对齐用户选中的外部 Inport/Outport 块到选中的子系统对应端口，并调整连线为在子系统端口处水平接入
% 使用说明：在 Simulink 模型窗口中先选中目标子系统和相关 Inport/Outport（可框选多选），然后运行本脚本

% 1. 获取当前活动模型和用户选择的对象
try
    activeSystem = gcs;
catch
    activeSystem = '';
end

if isempty(activeSystem)
    error('请先打开一个模型并选中目标子系统和相关端口。');
end

modelName = bdroot(activeSystem);
selection = find_system(modelName, 'FindAll', 'on', 'Selected', 'on', 'Type', 'Block');

% 2. 分离出子系统和端口块（支持选中多个端口、单个子系统）
subsysHandles = [];
inportHandles = [];
outportHandles = [];

for i = 1:length(selection)
    try
        type = get_param(selection(i), 'Type');
    catch
        continue;
    end
    if strcmp(type, 'block')
        blockType = get_param(selection(i), 'BlockType');
        if strcmp(blockType, 'SubSystem')
            subsysHandles(end+1) = selection(i);
        elseif strcmp(blockType, 'Inport')
            inportHandles(end+1) = selection(i);
        elseif strcmp(blockType, 'Outport')
            outportHandles(end+1) = selection(i);
        end
    end
end

if isempty(subsysHandles)
    error('请至少选中一个子系统（SubSystem）。');
end
if isempty(inportHandles) && isempty(outportHandles)
    error('请至少选中一个 Inport 或 Outport 块。');
end

% 如果用户选中了多个子系统，使用第一个，并给出提示
if length(subsysHandles) > 1
    warning('检测到多个子系统被选中，脚本将只对第一个子系统进行对齐（Handle: %d）。', subsysHandles(1));
end
subsysHandle = subsysHandles(1);

% 获取子系统端口句柄
subsysPorts = get_param(subsysHandle, 'PortHandles');
subsysPos = get_param(subsysHandle, 'Position');
leftX = subsysPos(1) - 80;
rightX = subsysPos(3) + 30;

% 辅助函数：按中心 y 排序，返回排序后的 handles 和对应中心 y
function [sortedHandles, centers] = sort_by_center(handles)
    centers = [];
    sortedHandles = [];
    if isempty(handles)
        return;
    end
    validHandles = [];
    validCenters = [];
    for k = 1:length(handles)
        h = handles(k);
        try
            pos = get_param(h, 'Position'); % 可能为 1x4 或 1x2 或 Nx2
        catch
            continue;
        end
        if isempty(pos)
            continue;
        end
        % 处理不同尺寸的 Position
        cy = [];
        if numel(pos) == 4
            cy = (pos(2) + pos(4)) / 2; % block-style
        elseif numel(pos) == 2
            cy = pos(2); % port-style [x y]
        elseif size(pos,2) == 2
            % e.g., line points Nx2，取 y 的均值作为该 handle 的中心 y
            cy = mean(pos(:,2));
        else
            continue;
        end
        validHandles(end+1) = h; %#ok<AGROW>
        validCenters(end+1) = cy; %#ok<AGROW>
    end
    if isempty(validHandles)
        return;
    end
    [validCenters, idx] = sort(validCenters, 'ascend');
    sortedHandles = validHandles(idx);
    centers = validCenters;
end

% 处理一个分组（selectedHandles 是外部 Inport/Outport 块）
function align_group(selectedHandles, subsystemPortHandles, subsysHandle, portSide, snapX)
    if isempty(selectedHandles) || isempty(subsystemPortHandles)
        return;
    end

    % 计算选中块的中心 y 并排序（从上到下）
    [selSorted, selCenters] = sort_by_center(selectedHandles);
    if isempty(selSorted)
        return;
    end

    % 计算子系统端口位置并排序（从上到下）
    [portSorted, portCenters] = sort_by_center(subsystemPortHandles);
    if isempty(portSorted)
        return;
    end

    n = min(length(selSorted), length(portSorted));
    for ii = 1:n
        blk = selSorted(ii);
        yTarget = portCenters(ii); % 使用 sort_by_center 返回的中心 y

        % 移动选中的 Inport/Outport 块，使中心对齐
        try
            blkPos = get_param(blk, 'Position'); % [left top right bottom]
        catch
            continue;
        end
        if numel(blkPos) ~= 4
            % 如果块的 Position 不是 4 元素（非常罕见），跳过
            continue;
        end
        h = blkPos(4) - blkPos(2); % 高度
        w = blkPos(3) - blkPos(1); % 宽度
        newTop = yTarget - h/2;
        newBottom = yTarget + h/2;
        newPos = [snapX, newTop, snapX + w, newBottom];
        set_param(blk, 'Position', newPos);

        % 调整连线（如果存在）
        portHandles = get_param(blk, 'PortHandles');
        blkType = get_param(blk, 'BlockType');
        connLine = -1;
        try
            if strcmp(blkType, 'Inport')
                connLine = get_param(portHandles.Outport, 'Line');
            else % Outport
                connLine = get_param(portHandles.Inport, 'Line');
            end
        catch
            connLine = -1;
        end

        if connLine ~= -1
            try
                pts = get_param(connLine, 'Points'); % Nx2
                if isempty(pts) || size(pts,2)~=2
                    % 跳过不符合格式的
                    continue;
                end
                % 构造新的点，使连线在靠近子系统的一段为水平段接到 yTarget
                srcPt = pts(1, :);
                dstPt = pts(end, :);

                % 若 src 或 dst 已在 yTarget，则避免重复点
                newPts = [srcPt;
                          srcPt(1), yTarget;
                          dstPt(1), yTarget;
                          dstPt];

                % 去掉连续重复行（保持顺序）
                % 找到相邻不相同的行
                keep = true(size(newPts,1),1);
                for r = 2:size(newPts,1)
                    if isequal(newPts(r,:), newPts(r-1,:))
                        keep(r) = false;
                    end
                end
                newPts = newPts(keep, :);

                % 如果只有一个点或两点且重复，则保留原点
                if size(newPts,1) < 2
                    newPts = pts;
                end

                set_param(connLine, 'Points', newPts);
            catch ME
                warning('调整连线时出错（Line handle: %d）：%s', connLine, ME.message);
            end
        end
    end
end

% 对 Inport 组进行对齐（子系统内部对应 Inport）
if ~isempty(inportHandles) && isfield(subsysPorts, 'Inport') && ~isempty(subsysPorts.Inport)
    align_group(inportHandles, subsysPorts.Inport, subsysHandle, 'Inport', leftX);
end

% 对 Outport 组进行对齐（子系统内部对应 Outport）
if ~isempty(outportHandles) && isfield(subsysPorts, 'Outport') && ~isempty(subsysPorts.Outport)
    align_group(outportHandles, subsysPorts.Outport, subsysHandle, 'Outport', rightX);
end

save_system(modelName, [], 'OverwriteIfChangedOnDisk', true);

disp('选中部分端口和子系统已对齐（按垂直顺序映射，已增强 Position 读取的兼容性）。');