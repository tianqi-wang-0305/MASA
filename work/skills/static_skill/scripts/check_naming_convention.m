function [violations, stats] = check_naming_convention(systemName)
violations = {};
stats = struct();
stats.checkedBlocks = 0;
stats.checkedLines = 0;
stats.invalidBlockNames = 0;
stats.invalidLineNames = 0;
stats.genericBlockNames = 0;
stats.signalNamingIssues = 0;
stats.calNamingIssues = 0;

pattern = '^[A-Za-z][A-Za-z0-9_]*$';

% Known data type prefixes for signal naming validation
typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64',...
                'f32','f64','f16','b','bool'};

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
    blockType = string(get_param(blockPath, 'BlockType'));
    if strlength(name) == 0
        continue;
    end

    % Basic pattern check
    if isempty(regexp(char(name), pattern, 'once'))
        stats.invalidBlockNames = stats.invalidBlockNames + 1;
        violations{end + 1, 1} = sprintf('【命名违规】模块 "%s" 名称 "%s" 不符合规范', blockPath, name); %#ok<AGROW>
    end

    % Generic name check
    if any(strcmpi(strtrim(name), genericNames))
        stats.genericBlockNames = stats.genericBlockNames + 1;
        violations{end + 1, 1} = sprintf('【命名建议】模块 "%s" 使用了通用占位名称 "%s"', blockPath, name); %#ok<AGROW>
    end

    % Signal naming check: Inport/Outport should follow {type}_{Name}
    if blockType == "Inport" || blockType == "Outport"
        hasValidPrefix = false;
        for p = 1:numel(typePrefixes)
            if startsWith(char(name), typePrefixes{p})
                hasValidPrefix = true;
                break;
            end
        end
        if ~hasValidPrefix
            stats.signalNamingIssues = stats.signalNamingIssues + 1;
            violations{end + 1, 1} = sprintf('【命名建议】端口 "%s" 缺少数据类型前缀，建议格式: {type}{Name} 如 u16VehicleSpeed', name); %#ok<AGROW>
        end
    end

    % Calibration naming check: Constant/Parameter should follow cal{type}{Name}
    if blockType == "Constant" || blockType == "Gain"
        if ~startsWith(char(name), 'cal_')
            % Check if it's a numerical/calibration-like value
            try
                val = get_param(blockPath, 'Value');
                if ~isempty(str2num(val)) || contains(val, '.') %#ok<ST2NM>
                    stats.calNamingIssues = stats.calNamingIssues + 1;
                    violations{end + 1, 1} = sprintf('【命名建议】标定参数 "%s" 建议使用 cal_{type}{Name} 格式 如 cal_u16Threshold', name); %#ok<AGROW>
                end
            catch
            end
        end
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