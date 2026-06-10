function [violations, stats] = check_naming_convention(systemName)
violations = {};
stats = struct();
stats.checkedBlocks = 0;
stats.checkedLines = 0;
stats.invalidBlockNames = 0;
stats.invalidLineNames = 0;
stats.genericBlockNames = 0;

pattern = '^[A-Za-z][A-Za-z0-9_]*$';
genericNames = lower(string({
    'Subsystem', 'Stateflow Chart', 'Chart', 'Gain', 'Sum', 'Product', ...
    'Constant', 'Switch', 'Merge', 'If', 'MATLAB Function', 'Data Store Memory', ...
    'Signal Conversion', 'Bus Selector', 'Bus Creator', 'Inport', 'Outport'
}));

blocks = find_system(systemName, 'Type', 'Block', 'LookUnderMasks', 'all');
for i = 1:numel(blocks)
    blockPath = string(blocks{i});
    if blockPath == string(systemName)
        continue;
    end

    stats.checkedBlocks = stats.checkedBlocks + 1;
    name = string(get_param(blockPath, 'Name'));
    if strlength(name) == 0
        continue;
    end

    if isempty(regexp(char(name), pattern, 'once'))
        stats.invalidBlockNames = stats.invalidBlockNames + 1;
        violations{end + 1, 1} = sprintf('【命名违规】模块 "%s" 名称 "%s" 不符合规范', blockPath, name); %#ok<AGROW>
    end

    if any(strcmpi(strtrim(name), genericNames))
        stats.genericBlockNames = stats.genericBlockNames + 1;
        violations{end + 1, 1} = sprintf('【命名建议】模块 "%s" 使用了通用占位名称 "%s"', blockPath, name); %#ok<AGROW>
    end
end

lines = find_system(systemName, 'FindAll', 'on', 'Type', 'Line');
for i = 1:numel(lines)
    stats.checkedLines = stats.checkedLines + 1;
    name = string(get_param(lines(i), 'Name'));
    if strlength(name) == 0 || name == '<none>'
        continue;
    end

    if isempty(regexp(char(name), pattern, 'once'))
        stats.invalidLineNames = stats.invalidLineNames + 1;
        violations{end + 1, 1} = sprintf('【命名违规】信号线 "%s" 不符合规范', name); %#ok<AGROW>
    end
end
end