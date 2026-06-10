function [violations, stats] = check_connection_rules(systemName)
violations = {};
stats = struct();
stats.checkedLines = 0;
stats.danglingLines = 0;
stats.unconnectedInports = 0;
stats.unconnectedOutports = 0;

lines = find_system(systemName, 'FindAll', 'on', 'Type', 'Line');
for i = 1:numel(lines)
    stats.checkedLines = stats.checkedLines + 1;
    srcBlockHandle = get_param(lines(i), 'SrcBlockHandle');
    dstBlockHandles = get_param(lines(i), 'DstBlockHandle');

    if isempty(srcBlockHandle) || srcBlockHandle == -1 || isempty(dstBlockHandles) || all(dstBlockHandles == -1)
        stats.danglingLines = stats.danglingLines + 1;
        violations{end + 1, 1} = sprintf('【连线违规】存在悬空或未完成连接的信号线（句柄 %d）', lines(i)); %#ok<AGROW>
    end
end

inportBlocks = find_system(systemName, 'LookUnderMasks', 'all', 'BlockType', 'Inport');
for i = 1:numel(inportBlocks)
    lineHandles = get_param(inportBlocks{i}, 'LineHandles');
    if isempty(lineHandles) || ~isfield(lineHandles, 'Outport') || any(lineHandles.Outport == -1)
        stats.unconnectedInports = stats.unconnectedInports + 1;
        violations{end + 1, 1} = sprintf('【连线违规】输入端口 "%s" 未连接', inportBlocks{i}); %#ok<AGROW>
    end
end

outportBlocks = find_system(systemName, 'LookUnderMasks', 'all', 'BlockType', 'Outport');
for i = 1:numel(outportBlocks)
    lineHandles = get_param(outportBlocks{i}, 'LineHandles');
    if isempty(lineHandles) || ~isfield(lineHandles, 'Inport') || any(lineHandles.Inport == -1)
        stats.unconnectedOutports = stats.unconnectedOutports + 1;
        violations{end + 1, 1} = sprintf('【连线违规】输出端口 "%s" 未连接', outportBlocks{i}); %#ok<AGROW>
    end
end
end