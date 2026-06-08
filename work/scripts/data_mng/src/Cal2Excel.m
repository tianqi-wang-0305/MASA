% filepath: /d:/modle/v2/test/Cal2Excel.m
function Cal2Excel()
% 逆向脚本：扫描文件夹及子文件夹下所有文件（不限名字/扩展名），
% 从内容中识别 Excel2Cal 生成格式，反推生成原规则 Excel（缺失字段留空）。
%
% 目标表头（来自你截图）：
% Name, SWC, Description, Type, DataType, Value, Min, Max, Unit,
% Factor, Offset, Dimensions, Complexity, StorageClass, Identifier,
% Alignment, Comment

    clc;

    rootDir = uigetdir(pwd, '选择要逆向扫描的文件夹（递归扫描所有子文件）');
    if isequal(rootDir, 0)
        disp('未选择目录，脚本终止。');
        return;
    end

    files = listAllFilesRecursive(rootDir);
    if isempty(files)
        warning('目录下没有找到文件：%s', rootDir);
        return;
    end

    headers = getExcelHeaders();
    rows = {}; % cell rows aligned to headers

    parsedFiles = 0;

    for i = 1:numel(files)
        f = files{i};

        % 尝试按文本读取（无法读取/二进制则跳过）
        try
            txt = fileread(f);
        catch
            continue;
        end
        if isempty(txt) || ~ischar(txt)
            continue;
        end

        % 特征过滤
        looksLikeEnum  = contains(txt, 'Simulink.defineIntEnumType', 'IgnoreCase', false);
        looksLikeParam = contains(txt, '.CoderInfo.', 'IgnoreCase', false) || ...
                         contains(txt, 'HeaderFileName', 'IgnoreCase', false);

        anyParsed = false;

        if looksLikeEnum
            enumRows = parseEnumTextToRows(txt, headers, f);  % <- 传入文件路径
            if ~isempty(enumRows)
                rows = [rows; enumRows]; %#ok<AGROW>
                anyParsed = true;
            end
        end

        if looksLikeParam
            paramRows = parseParamTextToRows(txt, headers);
            if ~isempty(paramRows)
                rows = [rows; paramRows]; %#ok<AGROW>
                anyParsed = true;
            end
        end

        if anyParsed
            parsedFiles = parsedFiles + 1;
        end
    end

    if isempty(rows)
        warning('未解析出任何行。请确认目录中包含由 Excel2Cal 生成/同结构的脚本。');
        return;
    end

    T = cell2table(rows, 'VariableNames', headers);

    % 排序（尽量）
    sortVars = intersect({'SWC','Type','Name'}, T.Properties.VariableNames, 'stable');
    if ~isempty(sortVars)
        try
            T = sortrows(T, sortVars);
        catch
        end
    end

    [outFile, outPath] = uiputfile({'*.xlsx','Excel (*.xlsx)'}, ...
        sprintf('保存逆向生成的 Excel（解析到 %d 个文件）', parsedFiles), ...
        fullfile(rootDir, 'Reverse_Generated.xlsx'));
    if isequal(outFile, 0)
        disp('未选择输出文件，脚本终止。');
        return;
    end

    outXlsx = fullfile(outPath, outFile);
    writetable(T, outXlsx, 'Sheet', 'Sheet1');
    fprintf('已生成 Excel：%s\n', outXlsx);
end

%% ============================= 表头（与你截图保持一致） =============================
function headers = getExcelHeaders()
    headers = { ...
        'Name', 'SWC', 'Description', 'Type', 'DataType', 'Value', 'Min', 'Max', 'Unit', ...
        'Factor', 'Offset', 'Dimensions', 'Complexity', 'StorageClass', 'Identifier', ...
        'Alignment', 'Comment' ...
    };
end

%% ============================= 遍历所有文件（不限扩展名） =============================
function files = listAllFilesRecursive(rootDir)
    d = dir(fullfile(rootDir, '**', '*'));
    d = d(~[d.isdir]);
    files = cell(numel(d), 1);
    for i = 1:numel(d)
        files{i} = fullfile(d(i).folder, d(i).name);
    end
end

%% ============================= 枚举解析 -> 行（对齐表头） =============================
function rows = parseEnumTextToRows(txt, headers, filePath)
% 解析 defineIntEnumType 块（兼容 "defineIntEnumType(...\n'<Name>'" 这种写法）
% 不依赖 HeaderFile：
% - SWC：优先从 typeName 的 "<SWC>_Enum" 前缀推断；再从文件名 "<SWC>_Enums.m" 推断；否则留空

    if nargin < 3, filePath = ''; end
    rows = {};

    % ---- 将内容按 defineIntEnumType 切块：每块从一次出现开始，到下一次出现前 ----
    startIdx = regexp(txt, 'Simulink\.defineIntEnumType', 'start');
    if isempty(startIdx)
        return;
    end

    blocks = cell(numel(startIdx), 1);
    for k = 1:numel(startIdx)
        s = startIdx(k);
        if k < numel(startIdx)
            e = startIdx(k+1) - 1;
        else
            e = numel(txt);
        end
        blocks{k} = txt(s:e);
    end

    % 文件名兜底 SWC：Seat_Enums.m -> Seat
    swcFromFile = '';
    if ~isempty(filePath)
        [~, bn, ~] = fileparts(filePath);
        tok = regexp(bn, '^(.*?)_Enums$', 'tokens', 'once', 'ignorecase');
        if ~isempty(tok)
            swcFromFile = tok{1};
        end
    end

    for b = 1:numel(blocks)
        blk = blocks{b};

        % ---- typeName：匹配 defineIntEnumType( ... 'Name' ----
        % 允许 ( 后面有 "...", 换行, 空白, 直到第一个单引号字符串
        typeName = token1(blk, 'defineIntEnumType\s*\(\s*(?:\.\.\.)?\s*[\r\n\s]*''([^'']+)''');
        if isempty(typeName)
            continue;
        end

        % ---- SWC 不看 HeaderFile：从 typeName 推断 "<SWC>_Enum" ----
        swc = '';
        tok = regexp(typeName, '^(.*?)_Enum', 'tokens', 'once');
        if ~isempty(tok)
            swc = tok{1};
        elseif ~isempty(swcFromFile)
            swc = swcFromFile;
        end

        % ---- StorageType（如果块里有就取；没有就空）----
        storageType = token1(blk, '''StorageType''\s*,\s*''([^'']+)''');

        % ---- Names: {'A', 'B', ...} ----
        names = {};
        mNames = regexp(blk, '\{\s*(.*?)\s*\}\s*,', 'tokens', 'once');
        if ~isempty(mNames)
            namesPart = mNames{1};
            q = regexp(namesPart, '''((?:''''|[^''])*)''', 'tokens');
            for i = 1:numel(q)
                names{end+1} = strrep(q{i}{1}, '''''', ''''); %#ok<AGROW>
            end
        end

        % ---- Values: [0, 1, ...] ----
        vals = [];
        mVals = regexp(blk, '\[\s*([0-9,\s\-+]+)\s*\]\s*,', 'tokens', 'once');
        if ~isempty(mVals)
            vals = str2num(mVals{1}); %#ok<ST2NM>
        end

        % ---- Value 文本：每行 "num name" ----
        valueStr = '';
        if ~isempty(names) && ~isempty(vals) && numel(names) == numel(vals)
            lines = strings(numel(names), 1);
            for i = 1:numel(names)
                lines(i) = string(vals(i)) + " " + string(names{i});
            end
            valueStr = char(strjoin(lines, newline));
        end

        r = blankRow(headers);
        r = setField(r, headers, 'Name', typeName);
        r = setField(r, headers, 'SWC', swc);
        r = setField(r, headers, 'Type', 'enum');
        r = setField(r, headers, 'DataType', storageType);
        r = setField(r, headers, 'Value', valueStr);

        rows(end+1, :) = r; %#ok<AGROW>
    end
end

%% ============================= 参数解析 -> 行（对齐表头） =============================
function rows = parseParamTextToRows(txt, headers)
% 解析 *_LoadCalParameter 生成体：
% - SWC：优先 HeaderFileName = '<SWC>_CalParameter.h'
% - Name：变量名（xxx = Class;）
% - Value/Description/DataType/Min/Max/DocUnits/StorageClass
% - Type：如果 Value 像数组 => 'Table'，否则尽量从文件里找不到就留空

    rows = {};

    swc = '';
    hf = token1(txt, 'HeaderFileName\s*=\s*''([^'']+)''\s*;');
    if ~isempty(hf)
        hf = string(hf);
        swc = char(extractBefore(hf, "_CalParameter.h"));
        if isempty(strtrim(swc)), swc = ''; end
    end

    decl = regexp(txt, '^\s*([A-Za-z]\w*)\s*=\s*([A-Za-z]\w*(?:\.[A-Za-z]\w*)*)\s*;\s*$', ...
                  'tokens', 'lineanchors');
    if isempty(decl)
        return;
    end
    varNames = cellfun(@(c)c{1}, decl, 'UniformOutput', false);

    for i = 1:numel(varNames)
        v = varNames{i};

        value = extractAssignmentRHS(txt, v, 'Value');
        desc  = stripQuotes(extractAssignmentRHS(txt, v, 'Description'));
        dt    = stripQuotes(extractAssignmentRHS(txt, v, 'DataType'));
        minv  = extractAssignmentRHS(txt, v, 'Min');
        maxv  = extractAssignmentRHS(txt, v, 'Max');
        unit  = stripQuotes(extractAssignmentRHS(txt, v, 'DocUnits'));

        storageClass = stripQuotes(extractAssignmentRHS(txt, v, 'CoderInfo.StorageClass'));
        if isempty(storageClass)
            % 有些情况下这一行固定是 Custom，但为了稳健尝试搜一下
            % v.CoderInfo.StorageClass = 'Custom';
            storageClass = '';
        end

        typeVal = '';
        if ~isempty(value)
            vtrim = strtrim(value);
            if startsWith(vtrim, '[') || startsWith(vtrim, '{') || ...
               (contains(vtrim, '[') && contains(vtrim, ']') && contains(vtrim, newline))
                typeVal = 'Table';
            end
        end

        r = blankRow(headers);
        r = setField(r, headers, 'Name', v);
        r = setField(r, headers, 'SWC', swc);
        r = setField(r, headers, 'Description', desc);
        r = setField(r, headers, 'Type', typeVal);
        r = setField(r, headers, 'DataType', dt);
        r = setField(r, headers, 'Value', value);
        r = setField(r, headers, 'Min', minv);
        r = setField(r, headers, 'Max', maxv);
        r = setField(r, headers, 'Unit', unit);
        r = setField(r, headers, 'StorageClass', storageClass);

        rows(end+1, :) = r; %#ok<AGROW>
    end
end

%% ============================= 通用小工具 =============================
function r = blankRow(headers)
    r = cell(1, numel(headers));
    for k = 1:numel(r), r{k} = ''; end
end

function r = setField(r, headers, name, value)
    idx = find(strcmp(headers, name), 1);
    if isempty(idx), return; end
    if isempty(value)
        r{idx} = '';
    else
        r{idx} = char(string(value));
    end
end

function t = token1(txt, pat)
    m = regexp(txt, pat, 'tokens', 'once');
    if isempty(m)
        t = '';
    else
        t = m{1};
    end
end

function rhs = extractAssignmentRHS(txt, varName, fieldName)
% 提取：varName.fieldName = <rhs>;
% 支持跨行，直到以分号结束（匹配行锚点）
    rhs = '';
    pat = ['(?s)^\s*' regexptranslate('escape', varName) '\.' regexptranslate('escape', fieldName) '\s*=\s*(.*?)\s*;\s*$'];
    m = regexp(txt, pat, 'tokens', 'once', 'lineanchors');
    if isempty(m), return; end
    rhs = strtrim(m{1});
end

function s = stripQuotes(s)
% 'xxx' -> xxx，处理 MATLAB '' 转义
    if isempty(s), return; end
    s = strtrim(s);
    if numel(s) >= 2 && s(1)=='''' && s(end)==''''
        s = s(2:end-1);
        s = strrep(s, '''''', '''');
    end
end