function [violations, stats] = check_hierarchy_integrity(systemName)
violations = {};
stats = struct();
stats.subsystemCount = 0;
stats.maxDepth = 0;
stats.topLevelBlockCount = 0;
stats.orphanBlockCount = 0;

allBlocks = find_system(systemName, 'Type', 'Block', 'LookUnderMasks', 'on');
subsystems = find_system(systemName, 'Type', 'Block', 'LookUnderMasks', 'on', 'BlockType', 'SubSystem');
rootBlocks = find_system(systemName, 'Type', 'Block', 'Parent', systemName);

for i = 1:numel(subsystems)
    if ~strcmp(subsystems{i}, systemName)
        stats.subsystemCount = stats.subsystemCount + 1;
    end
end

stats.topLevelBlockCount = numel(rootBlocks);
maxDepthLimit = 5;

for i = 1:numel(allBlocks)
    blk = allBlocks{i};
    if strcmp(blk, systemName)
        continue;
    end

    parent = get_param(blk, 'Parent');
    if ~strcmp(parent, systemName) && ~any(strcmp(parent, allBlocks))
        stats.orphanBlockCount = stats.orphanBlockCount + 1;
        violations{end + 1, 1} = sprintf('【层级违规】模块 "%s" 为游离模块', blk); %#ok<AGROW>
    end
end

for i = 1:numel(rootBlocks)
    depth = getSubsystemDepth(rootBlocks{i}, 1);
    if depth > stats.maxDepth
        stats.maxDepth = depth;
    end

    if depth > maxDepthLimit
        violations{end + 1, 1} = sprintf('【层级违规】子系统 "%s" 嵌套深度 %d > %d', rootBlocks{i}, depth, maxDepthLimit); %#ok<AGROW>
    end
end
end

function depth = getSubsystemDepth(block, currentDepth)
if ~strcmp(get_param(block, 'BlockType'), 'SubSystem')
    depth = currentDepth;
    return;
end

children = find_system(block, 'Type', 'Block', 'Parent', block);
if isempty(children)
    depth = currentDepth;
    return;
end

maxChildDepth = currentDepth;
for j = 1:numel(children)
    childDepth = getSubsystemDepth(children{j}, currentDepth + 1);
    if childDepth > maxChildDepth
        maxChildDepth = childDepth;
    end
end

depth = maxChildDepth;
end