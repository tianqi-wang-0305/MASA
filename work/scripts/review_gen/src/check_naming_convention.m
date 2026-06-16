function [violations, stats] = check_naming_convention(systemName)
violations = {};
stats = struct();
stats.checkedBlocks = 0;
stats.checkedLines = 0;
stats.invalidBlockNames = 0;
stats.invalidLineNames = 0;
stats.genericBlockNames = 0;
stats.signalNamingIssues = 0;
stats.signalNamingOk = 0;
stats.calNamingIssues = 0;
stats.calNamingOk = 0;

pattern = '^[A-Za-z][A-Za-z0-9_]*$';

% Valid type prefixes (sorted by length desc to match longer ones first)
typePrefixes = {'s64','u64','s32','u32','s16','u16','f32','f64','f16','s8','u8','bool','b'};

% Calibration block types (blocks that hold numeric/calibration parameters)
calBlockTypes = {'Constant', 'Gain', 'Saturation', 'LookupTable'};

genericNames = lower(string({
    'Subsystem', 'Stateflow Chart', 'Chart', 'Gain', 'Sum', 'Product', ...
    'Constant', 'Switch', 'Merge', 'If', 'MATLAB Function', 'Data Store Memory', ...
    'Signal Conversion', 'Bus Selector', 'Bus Creator', 'Inport', 'Outport'
}));

% Pre-compile type prefix startsWith patterns
calPrefixes = cellfun(@(p) ['cal_' p], typePrefixes, 'UniformOutput', false);

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

    % ─── Basic pattern check ─────────────────────────────────
    if isempty(regexp(char(name), pattern, 'once'))
        stats.invalidBlockNames = stats.invalidBlockNames + 1;
        violations{end + 1, 1} = sprintf('【命名违规】模块 "%s" 名称 "%s" 不符合基本命名规范', blockPath, name); %#ok<AGROW>
    end

    % ─── Generic name check ──────────────────────────────────
    if any(strcmpi(strtrim(name), genericNames))
        stats.genericBlockNames = stats.genericBlockNames + 1;
        violations{end + 1, 1} = sprintf('【命名建议】模块 "%s" 使用了通用占位名称 "%s"', blockPath, name); %#ok<AGROW>
    end

    % ─── Signal naming check: Inport/Outport ─────────────────
    if blockType == "Inport" || blockType == "Outport"
        nameStr = char(name);
        matchedPrefix = findMatchingPrefix(nameStr, typePrefixes);
        if isempty(matchedPrefix)
            stats.signalNamingIssues = stats.signalNamingIssues + 1;
            violations{end + 1, 1} = sprintf('【信号命名违规】端口 "%s" 名称 "%s" 缺少数据类型前缀，应使用 {type}{Name} 格式，如 u16VehicleSpeed', ...
                blockPath, name); %#ok<AGROW>
        else
            % Validate the rest after prefix is valid identifier start
            rest = nameStr(length(matchedPrefix)+1:end);
            if isempty(rest) || ~isletter(rest(1))
                stats.signalNamingIssues = stats.signalNamingIssues + 1;
                violations{end + 1, 1} = sprintf('【信号命名违规】端口 "%s" 前缀 "%s" 后缺少描述，应使用 {type}{Name} 格式，如 u16VehicleSpeed', ...
                    blockPath, matchedPrefix); %#ok<AGROW>
            else
                stats.signalNamingOk = stats.signalNamingOk + 1;
            end
        end
    end

    % ─── Calibration naming check: cal_{type}{Name} ──────────
    if any(blockType == calBlockTypes)
        nameStr = char(name);
        % Check if it starts with cal_
        if startsWith(nameStr, 'cal_')
            % Has cal_ prefix → validate the type part
            restAfterCal = nameStr(5:end); % after "cal_"
            if isempty(restAfterCal)
                stats.calNamingIssues = stats.calNamingIssues + 1;
                violations{end + 1, 1} = sprintf('【标定命名违规】标定参数 "%s" 的 cal_ 后缺少类型和名称', name); %#ok<AGROW>
            else
                matchedCalPrefix = findMatchingPrefix(restAfterCal, typePrefixes);
                if isempty(matchedCalPrefix)
                    stats.calNamingIssues = stats.calNamingIssues + 1;
                    violations{end + 1, 1} = sprintf('【标定命名违规】标定参数 "%s" 的 cal_ 后缺少有效数据类型前缀, 应使用 cal_{type}{Name} 格式, 如 cal_u16Threshold', name); %#ok<AGROW>
                else
                    rest = restAfterCal(length(matchedCalPrefix)+1:end);
                    if isempty(rest) || ~isletter(rest(1))
                        stats.calNamingIssues = stats.calNamingIssues + 1;
                        violations{end + 1, 1} = sprintf('【标定命名违规】标定参数 "%s" 前缀后缺少名称描述', name); %#ok<AGROW>
                    else
                        stats.calNamingOk = stats.calNamingOk + 1;
                    end
                end
            end
        else
            % Doesn't start with cal_ → check if it has calibration-like value
            hasNumericValue = false;
            try
                switch char(blockType)
                    case 'Constant'
                        val = get_param(blockPath, 'Value');
                        hasNumericValue = ~isempty(str2double(val)) || ~isnan(str2double(val));
                        % Also check if it looks like a variable reference (no cal_ prefix)
                        if ~hasNumericValue && ~startsWith(strtrim(val), 'cal_')
                            % It's a variable name but doesn't follow cal_ convention
                            hasNumericValue = true; % Flag it for suggestion
                        end
                    case 'Gain'
                        val = get_param(blockPath, 'Gain');
                        hasNumericValue = ~isempty(str2double(val)) && ~isnan(str2double(val));
                    case 'Saturation'
                        ul = get_param(blockPath, 'UpperLimit');
                        ll = get_param(blockPath, 'LowerLimit');
                        hasNumericValue = (~isempty(str2double(ul)) && ~isnan(str2double(ul))) || ...
                                          (~isempty(str2double(ll)) && ~isnan(str2double(ll)));
                    case 'LookupTable'
                        t = get_param(blockPath, 'Table');
                        hasNumericValue = ~isempty(str2num(t)); %#ok<ST2NM>
                end
            catch
                hasNumericValue = false;
            end
            if hasNumericValue
                stats.calNamingIssues = stats.calNamingIssues + 1;
                violations{end + 1, 1} = sprintf('【标定命名违规】标定参数 "%s" 缺少 cal_ 前缀, 应使用 cal_{type}{Name} 格式, 如 cal_u16Threshold', name); %#ok<AGROW>
            end
        end
    end
end

% ─── Signal line name check ──────────────────────────────
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

%% ================== Helper ==================

function matched = findMatchingPrefix(nameStr, prefixes)
% Find the longest matching type prefix at the start of nameStr
    matched = '';
    for p = 1:numel(prefixes)
        candidate = prefixes{p};
        if startsWith(nameStr, candidate)
            if length(candidate) > length(matched)
                matched = candidate;
            end
        end
    end
end

function reportFile = generateNamingReport(violations, stats, systemName, outputDir)
% Generate HTML report for naming convention check results
    if nargin < 4, outputDir = pwd; end
    reportFile = fullfile(outputDir, [systemName '_naming_report.html']);
    fid = fopen(reportFile, 'w');
    fprintf(fid, '<!DOCTYPE html><html><head>\n');
    fprintf(fid, '<title>Naming Convention Report - %s</title>\n', systemName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:40px;background:#fafafa}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #FF5722;padding-bottom:10px}\n');
    fprintf(fid, '.violation{background:#fff3e0;border-left:4px solid #FF5722;padding:10px;margin:6px 0;font-size:13px}\n');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:20px 0}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:10px;text-align:left}\n');
    fprintf(fid, 'th{background:#FF5722;color:white}\n');
    fprintf(fid, '.summary{background:#fbe9e7;padding:20px;border-radius:5px;margin:20px 0}\n');
    fprintf(fid, '.ok{color:#4CAF50;font-weight:bold}.warn{color:#FF9800;font-weight:bold}\n');
    fprintf(fid, '</style></head><body>\n');
    fprintf(fid, '<h1>Naming Convention Report: %s</h1>\n', systemName);
    % Summary
    totalViolations = numel(violations);
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Blocks Checked:</strong> %d</p>\n', stats.checkedBlocks);
    fprintf(fid, '<p><strong>Lines Checked:</strong> %d</p>\n', stats.checkedLines);
    fprintf(fid, '<p><strong>Total Violations:</strong> %d</p>\n', totalViolations);
    fprintf(fid, '<p><strong>Signal Naming:</strong> %d issues / %d ok</p>\n', stats.signalNamingIssues, stats.signalNamingOk);
    fprintf(fid, '<p><strong>Calibration Naming:</strong> %d issues / %d ok</p>\n', stats.calNamingIssues, stats.calNamingOk);
    fprintf(fid, '<p><strong>Generic Names:</strong> %d</p>\n', stats.genericBlockNames);
    fprintf(fid, '</div>\n');
    % Stats table
    fprintf(fid, '<h2>Statistics</h2>\n');
    fprintf(fid, '<table><tr><th>Metric</th><th>Value</th></tr>\n');
    fnames = fieldnames(stats);
    for i = 1:numel(fnames)
        val = stats.(fnames{i});
        if isnumeric(val)
            css = ifelse(val > 0, 'warn', 'ok');
            fprintf(fid, '<tr><td>%s</td><td class="%s">%d</td></tr>\n', fnames{i}, css, val);
        end
    end
    fprintf(fid, '</table>\n');
    % Violations list
    if ~isempty(violations)
        fprintf(fid, '<h2>Violations (%d)</h2>\n', totalViolations);
        for i = 1:numel(violations)
            fprintf(fid, '<div class="violation">%s</div>\n', violations{i});
        end
    end
    fprintf(fid, '<hr><p style="color:#999">Generated by check_naming_convention.m</p>\n');
    fprintf(fid, '</body></html>\n');
    fclose(fid);
end

function s = ifelse(cond, a, b)
    if cond, s = a; else, s = b; end
end