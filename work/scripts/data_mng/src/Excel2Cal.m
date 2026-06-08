% filepath: /D:/modle/v2/test/Excel2Cal.m
% 优化脚本：按SWC分组生成文件
% 枚举(Type=enum)逐类型生成到按 SWC 分组的单一 .m 文件（每个 SWC 一个文件，文件内包含该 SWC 的所有枚举）
% 每个枚举以 Simulink.defineIntEnumType 形式生成，HeaderFile = '<SWC>_Enum.h'
% 非枚举且非 configuration 的参数按 SWC 生成 <SWC>_LoadCalParameter.m，放入 CalParameters 子目录
% Table 类型直接赋数组（Value 原样）
% StorageClass = Custom，CustomStorageClass 按 DataType 自动推断
% 跳过 Type=configuration
%
% 额外优化（本版本）：
% 1) 在用户选择的模型中生成模块：
%    - 非 enum、非 configuration：生成 Constant（Value=变量名）
%    - enum：生成 Enumerated Constant（Simulink/Sources/Enumerated Constant）
%           * 尝试将数据类型设置为枚举类型（兼容不同版本参数名：OutDataTypeStr / DataType / OutDataType）
%           * Value = EnumType.<默认成员>
% 2) 生成的模块不添加描述（不写 AttributesFormatString）
% 3) 不再删除端口（保留子系统原有 Inport/Outport）
% 4) 块“路径名”使用 makeValidName，块“显示名”尽量改为 Excel 原始 Name（若非法/重名则跳过）
% -----------------------------------------------------------------------------

%% Excel字段名
colName = 'Name';
colSWC = 'SWC';
colDescription = 'Description'; %#ok<NASGU> % 保留字段名，但本版本不写入模块描述
colType = 'Type';
colDataType = 'DataType';
colValue = 'Value';
colMin = 'Min';
colMax = 'Max';
colUnit = 'Unit';

%% 选择 Excel 文件
[excelFile, excelPath] = uigetfile({'*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)'}, '选择Excel文件');
if isequal(excelFile, 0)
    disp('未选择文件，脚本终止。');
    return;
end
filename = fullfile(excelPath, excelFile);

%% 选择 Sheet
[~, sheets] = xlsfinfo(filename);
[sheetIdx, ok] = listdlg('PromptString', '选择需要处理的Sheet页:', ...
                         'SelectionMode', 'single', ...
                         'ListString', sheets);
if ~ok
    disp('未选择Sheet页，脚本终止。');
    return;
end
sheetName = sheets{sheetIdx};

%% 读表（把 Value 强制当 char，方便解析 enum/table 表达式）
opts = detectImportOptions(filename, 'Sheet', sheetName);
opts = setvartype(opts, colValue, 'char');
T = readtable(filename, opts);

%% ---------------- 用户选项：参数类 + 是否在模型中生成块 ----------------
% 1) 选择标定量类（影响 *_LoadCalParameter.m 里对象构造）
paramClassCandidates = {'PowerSAR.Parameter','NoneSAR.Parameter'};
[sel, ok] = listdlg('PromptString','选择标定量生成的类：', ...
                    'SelectionMode','single', ...
                    'ListString', paramClassCandidates);
if ~ok
    disp('未选择标定量类，脚本终止。');
    return;
end
paramClassName = paramClassCandidates{sel};

% 2) 是否在 Simulink 中生成模块
btn = questdlg('是否在 Simulink 模型中生成 Constant / Enumerated Constant 模块？', ...
               '模型生成', '生成','不生成','不生成');
genBlocksInModel = strcmp(btn,'生成');

%% ---------------- 工具函数 ----------------
function val = getVal(Tlocal, col, i)
    if iscell(Tlocal.(col))
        val = Tlocal.(col){i};
    else
        val = Tlocal.(col)(i);
    end
end

function customSC = getCustomSC(dataType)
    switch lower(strtrim(string(dataType)))
        case {'boolean','uint8','int8'}
            customSC = 'CAL_NORMAL_8BIT';
        case {'uint16','int16'}
            customSC = 'CAL_NORMAL_16BIT';
        case {'uint32','int32','single'}
            customSC = 'CAL_NORMAL_32BIT';
        case {'double'}
            customSC = 'CAL_NORMAL_64BIT';
        otherwise
            customSC = '';
    end
end

function s = escapeQuotes(str)
    s = strrep(char(str), '''', '''''');
end

% 解析枚举 Value 为 {names}, [values]
function [namesCell, valuesVec] = parseEnumForDefine(rawVals)
    lines = splitlines(string(rawVals));
    lines = lines(strlength(strtrim(lines)) > 0);
    names = {};
    vals = [];
    for k = 1:numel(lines)
        ln = strtrim(lines(k));
        m = regexp(ln, '^\s*(0x[0-9A-Fa-f]+|[-+]?\d+)\s+(.+?)\s*$', 'tokens', 'once');
        if isempty(m)
            m = regexp(ln, '^\s*(0x[0-9A-Fa-f]+|[-+]?\d+)\s*[,;:]\s*(.+?)\s*$', 'tokens', 'once');
        end
        if isempty(m), continue; end
        numStr = string(m{1});
        nameStr = string(m{2});
        if startsWith(numStr, "0x", 'IgnoreCase', true)
            val = hex2dec(extractAfter(numStr, 2));
        else
            val = str2double(numStr);
        end
        if ~isfinite(val), continue; end
        names{end+1} = strtrim(char(nameStr)); %#ok<AGROW>
        vals(end+1) = val; %#ok<AGROW>
    end
    namesCell = names;
    valuesVec = vals;
end

%% ---------------- 生成枚举（按 SWC 聚合到单一 m 文件） ----------------
enumRows = [];
if any(strcmpi(T.Properties.VariableNames, colType))
    enumRows = find(strcmpi(string(T.(colType)), 'enum'));
end

enumsOutDir = fullfile(excelPath, 'Enums');
if ~exist(enumsOutDir, 'dir'), mkdir(enumsOutDir); end

swcEnumMap = containers.Map('KeyType','char','ValueType','any'); % value: struct array fields: typeName, namesCell, valuesVec, storageType
for ii = 1:numel(enumRows)
    r = enumRows(ii);
    swcName = char(string(getVal(T, colSWC, r)));
    if isempty(strtrim(swcName)), swcName = 'UnknownSWC'; end
    typeName = char(string(getVal(T, colName, r)));
    if isempty(strtrim(typeName)), warning('第 %d 行枚举 Name 为空，跳过。', r); continue; end

    rawVals = getVal(T, colValue, r);
    if isempty(rawVals), warning('枚举 %s 的 Value 为空，跳过。', typeName); continue; end

    [namesCell, valuesVec] = parseEnumForDefine(rawVals);
    if isempty(namesCell) || isempty(valuesVec)
        warning('枚举 %s 未解析到合法成员，跳过。', typeName);
        continue;
    end

    dtype = '';
    if any(strcmpi(T.Properties.VariableNames, colDataType))
        dttmp = getVal(T, colDataType, r);
        if ~isempty(dttmp), dtype = char(string(dttmp)); end
    end

    if ~isKey(swcEnumMap, swcName)
        swcEnumMap(swcName) = [];
    end
    item = struct('typeName', typeName, 'namesCell', {namesCell}, 'valuesVec', valuesVec, 'storageType', dtype);
    swcEnumMap(swcName) = [swcEnumMap(swcName), item]; %#ok<AGROW>
end

swcKeys = swcEnumMap.keys;
for k = 1:numel(swcKeys)
    swcName = swcKeys{k};
    items = swcEnumMap(swcName);
    if isempty(items), continue; end

    headerFile = sprintf('%s_Enum.h', swcName);
    outFile = fullfile(enumsOutDir, sprintf('%s_Enums.m', swcName));
    fid = fopen(outFile, 'w');
    if fid == -1
        warning('无法创建枚举输出文件：%s', outFile);
        continue;
    end

    fprintf(fid, '%% 自动生成：%s 的枚举定义（%s）\n', swcName, datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '%% 每个枚举使用 Simulink.defineIntEnumType 形式\n\n');

    for i = 1:numel(items)
        tn   = items(i).typeName;
        ncell= items(i).namesCell;
        vvec = items(i).valuesVec;
        stype= items(i).storageType;
        if isempty(stype)
            maxv = max(vvec);
            if maxv <= intmax('uint8')
                stype = 'uint8';
            elseif maxv <= intmax('uint16')
                stype = 'uint16';
            else
                stype = 'uint32';
            end
        end
        defVal = ncell{1};

        fprintf(fid, 'Simulink.defineIntEnumType(''%s'',...\n', tn);

        fprintf(fid, '{');
        for j = 1:numel(ncell)
            nm = escapeQuotes(ncell{j});
            if j < numel(ncell)
                fprintf(fid, '''%s'',', nm);
            else
                fprintf(fid, '''%s''', nm);
            end
        end
        fprintf(fid, '},...\n');

        fprintf(fid, '[');
        for j = 1:numel(vvec)
            if j < numel(vvec)
                fprintf(fid, '%d,', vvec(j));
            else
                fprintf(fid, '%d', vvec(j));
            end
        end
        fprintf(fid, '],...\n');

        fprintf(fid, '''DefaultValue'',''%s'',...\n', escapeQuotes(defVal));
        fprintf(fid, '''DataScope'',''Exported'',...\n');
        fprintf(fid, '''HeaderFile'',''%s'',...\n', headerFile);
        fprintf(fid, '''AddClassNameToEnumNames'',true,...\n');
        fprintf(fid, '''StorageType'',''%s'');\n\n', stype);
    end

    fclose(fid);
    fprintf('生成枚举文件：%s\n', outFile);
end

%% ---------------- 生成参数文件（非枚举/非 configuration） ----------------
swcList = T.(colSWC);
if isstring(swcList)
    swcList = cellstr(swcList);
elseif ~iscell(swcList)
    swcList = cellstr(string(swcList));
end
for i = 1:numel(swcList)
    if isempty(swcList{i}) || strcmpi(strtrim(swcList{i}), '')
        swcList{i} = 'UnknownSWC';
    end
end
uniqueSWC = unique(swcList);

paramsOutDir = fullfile(excelPath, 'CalParameters');
if ~exist(paramsOutDir, 'dir'), mkdir(paramsOutDir); end

for swcIdx = 1:numel(uniqueSWC)
    swcName = uniqueSWC{swcIdx};
    indices = find(strcmp(swcList, swcName));
    HeaderFileName = [swcName '_CalParameter.h'];
    DefinitionFileName = [swcName '_CalParameter.c'];
    outputFile = fullfile(paramsOutDir, [swcName '_LoadCalParameter.m']);

    fid = fopen(outputFile, 'w');
    if fid == -1
        warning('无法创建输出文件：%s', outputFile);
        continue;
    end
    fprintf(fid, 'HeaderFileName = ''%s'';\n', HeaderFileName);
    fprintf(fid, 'DefinitionFileName = ''%s'';\n\n', DefinitionFileName);

    for idx = indices'
        typeVal = getVal(T, colType, idx);
        if strcmpi(typeVal, 'enum') || strcmpi(typeVal, 'configuration')
            continue;
        end

        varName = getVal(T, colName, idx);
        value = getVal(T, colValue, idx);
        description = getVal(T, colDescription, idx); %#ok<NASGU>
        dataType = getVal(T, colDataType, idx);
        minVal = getVal(T, colMin, idx);
        maxVal = getVal(T, colMax, idx);
        unit = getVal(T, colUnit, idx);

        varName = matlab.lang.makeValidName(string(varName));
        varName = char(varName);

        fprintf(fid, '%s = %s;\n', varName, paramClassName);

        if strcmpi(typeVal, 'Table')
            if iscell(value), valueStr = value{1};
            elseif isstring(value), valueStr = char(value);
            elseif ischar(value), valueStr = value;
            else, valueStr = num2str(value); end
            valueStr = strtrim(valueStr);
            fprintf(fid, '%s.Value = %s;\n', varName, valueStr);
        else
            if ~isempty(value)
                if isnumeric(value)
                    fprintf(fid, '%s.Value = %s;\n', varName, num2str(value));
                elseif ischar(value) || isstring(value)
                    vnum = str2double(value);
                    if isnan(vnum)
                        fprintf(fid, '%s.Value = ''%s'';\n', varName, escapeQuotes(value));
                    else
                        fprintf(fid, '%s.Value = %s;\n', varName, num2str(vnum));
                    end
                else
                    fprintf(fid, '%s.Value = [];\n', varName);
                end
            else
                fprintf(fid, '%s.Value = [];\n', varName);
            end
        end

        fprintf(fid, '%s.CoderInfo.StorageClass = ''Custom'';\n', varName);
        customSC = getCustomSC(dataType);
        fprintf(fid, '%s.CoderInfo.CustomStorageClass = ''%s'';\n', varName, customSC);
        fprintf(fid, '%s.CoderInfo.Alias = ''%s'';\n', varName, varName);
        fprintf(fid, '%s.CoderInfo.CustomAttributes.HeaderFile = HeaderFileName;\n', varName);
        fprintf(fid, '%s.CoderInfo.CustomAttributes.DefinitionFile = DefinitionFileName;\n', varName);

        fprintf(fid, '%s.Description = ''%s'';\n', varName, escapeQuotes(getVal(T, colDescription, idx)));
        fprintf(fid, '%s.DataType = ''%s'';\n', varName, char(string(dataType)));

        if isnumeric(minVal) && isscalar(minVal) && ~isnan(minVal)
            fprintf(fid, '%s.Min = %s;\n', varName, num2str(minVal));
        else
            mv = str2double(string(minVal));
            if ~isnan(mv)
                fprintf(fid, '%s.Min = %s;\n', varName, num2str(mv));
            else
                fprintf(fid, '%s.Min = [];\n', varName);
            end
        end

        if isnumeric(maxVal) && isscalar(maxVal) && ~isnan(maxVal)
            fprintf(fid, '%s.Max = %s;\n', varName, num2str(maxVal));
        else
            mv = str2double(string(maxVal));
            if ~isnan(mv)
                fprintf(fid, '%s.Max = %s;\n', varName, num2str(mv));
            else
                fprintf(fid, '%s.Max = [];\n', varName);
            end
        end
        fprintf(fid, '%s.DocUnits = ''%s'';\n', varName, char(string(unit)));
        fprintf(fid, '\n');
    end

    fclose(fid);
    fprintf('生成参数文件：%s\n', outputFile);
end

disp('全部生成完成~')

%% ====================== 追加功能：在模型中生成 Constant / Enumerated Constant ======================
if genBlocksInModel
    % 过滤：跳过 configuration，但保留 enum 与常规参数
    typeStrAll = lower(strtrim(string(T.(colType))));
    isCfg = (typeStrAll == "configuration");
    rows = find(~isCfg);

    if isempty(rows)
        fprintf('[模型生成] 没有可生成的行（跳过 configuration 后为空）。\n');
        return;
    end

    % 选择目标模型（必须已打开）
    mdls = find_system('Type','block_diagram');
    mdls = mdls(~strcmpi(mdls,'simulink'));
    if isempty(mdls)
        warning('[模型生成] 未检测到已打开的 Simulink 模型，跳过生成模块。');
        return;
    end

    [mdlIdx, ok] = listdlg('PromptString','选择要生成模块的模型：', ...
                           'SelectionMode','single', ...
                           'ListString', mdls);
    if ~ok
        disp('[模型生成] 未选择模型，跳过。');
        return;
    end

    tgtModel = mdls{mdlIdx};
    if ~bdIsLoaded(tgtModel)
        load_system(tgtModel);
    end

    % （可选但建议）加载本次生成的枚举类型，避免 Enumerated Constant 退回默认
    % 如果你不希望自动加载，可把此段注释掉
    try
        for kk = 1:numel(swcKeys)
            f = fullfile(enumsOutDir, sprintf('%s_Enums.m', swcKeys{kk}));
            if exist(f, 'file')
                run(f);
            end
        end
    catch ME
        warning('[模型生成] 自动加载枚举脚本失败：%s', ME.message);
    end

    % 根容器
    ensureSubsystem(tgtModel, 'AutoGen_CalConstants', [30 30 300 130]);
    rootContainer = [tgtModel '/AutoGen_CalConstants'];

    % SWC 列表（基于 rows）
    swcValsAll = string(T.(colSWC)(rows));
    swcValsAll = strtrim(swcValsAll);
    swcValsAll(ismissing(swcValsAll) || strlength(swcValsAll)==0) = "UnknownSWC";
    swcList = unique(swcValsAll);

    created = 0; updated = 0; skipped = 0;

    % SWC 子系统排布
    swcBaseX = 30; swcBaseY = 180; swcW = 300; swcH = 140;
    swcDx = 360;  swcDy = 240;
    swcPerRow = 4;

    for s = 1:numel(swcList)
        swcRaw = swcList(s);
        swcName = char(matlab.lang.makeValidName(swcRaw));
        if isempty(strtrim(swcName))
            swcName = 'UnknownSWC';
        end

        rr = floor((s-1)/swcPerRow);
        cc = mod((s-1), swcPerRow);
        swcPos = [swcBaseX + cc*swcDx, swcBaseY + rr*swcDy, ...
                  swcBaseX + cc*swcDx + swcW, swcBaseY + rr*swcDy + swcH];

        ensureSubsystem(rootContainer, swcName, swcPos);
        swcSys = [rootContainer '/' swcName];

        swcRows = rows(swcValsAll == swcRaw);
        if isempty(swcRows)
            continue;
        end

        % 网格布局
        x0 = 30; y0 = 30; w = 240; h = 55;
        dx = 300; dy = 85;
        maxPerCol = 18;

        for n = 1:numel(swcRows)
            r = swcRows(n);

            typeVal = lower(strtrim(string(getVal(T, colType, r))));
            isEnumRow = (typeVal == "enum");

            rawName = getVal(T, colName, r);
            if isempty(rawName)
                skipped = skipped + 1;
                continue;
            end

            % 路径名用合法名字
            blkName = char(matlab.lang.makeValidName(string(rawName)));
            if isempty(strtrim(blkName))
                skipped = skipped + 1;
                continue;
            end

            blkPath = [swcSys '/' blkName];

            % 显示名尽量用原始名字（失败则保持）
            displayName = char(string(rawName));

            col = floor((n-1)/maxPerCol);
            row = mod((n-1), maxPerCol);
            pos = [x0 + col*dx, y0 + row*dy, x0 + col*dx + w, y0 + row*dy + h];

            if ~isEnumRow
                libBlk = 'simulink/Sources/Constant';
                constValueExpr = blkName; % Value=变量名
                enumTypeName = "";
            else
                libBlk = 'simulink/Sources/Enumerated Constant';

                enumTypeName = "";
                if any(strcmpi(T.Properties.VariableNames, colDataType))
                    enumTypeName = strtrim(string(getVal(T, colDataType, r)));
                end
                if strlength(enumTypeName) == 0
                    enumTypeName = strtrim(string(getVal(T, colName, r)));
                end

                rawVals = getVal(T, colValue, r);
                [namesCell, ~] = parseEnumForDefine(rawVals);

                if isempty(namesCell)
                    constValueExpr = char(enumTypeName);
                else
                    constValueExpr = char(enumTypeName + "." + string(namesCell{1}));
                end
            end

            exists = ~isempty(find_system(swcSys, 'SearchDepth', 1, 'Type', 'Block', 'Name', blkName));

            if ~exists
                try
                    add_block(libBlk, blkPath, 'Position', pos);

                    % 显示名
                    try
                        set_param(blkPath, 'ShowName', 'on');
                        set_param(blkPath, 'Name', displayName);
                    catch
                    end

                    if isEnumRow
                        setEnumConstantParams(blkPath, enumTypeName, constValueExpr);
                    else
                        set_param(blkPath, 'Value', constValueExpr);
                    end

                    created = created + 1;
                catch ME
                    warning('创建块失败：%s（%s）', blkPath, ME.message);
                    skipped = skipped + 1;
                end
            else
                try
                    set_param(blkPath, 'Position', pos);

                    % 显示名
                    try
                        set_param(blkPath, 'ShowName', 'on');
                        set_param(blkPath, 'Name', displayName);
                    catch
                    end

                    if isEnumRow
                        setEnumConstantParams(blkPath, enumTypeName, constValueExpr);
                    else
                        set_param(blkPath, 'Value', constValueExpr);
                    end

                    updated = updated + 1;
                catch ME
                    warning('更新块失败：%s（%s）', blkPath, ME.message);
                    skipped = skipped + 1;
                end
            end
        end
    end

    fprintf('\n[模型生成] created=%d, updated=%d, skipped=%d\n', created, updated, skipped);

    btn = questdlg('是否保存模型？', '保存模型', '保存','不保存','不保存');
    if strcmp(btn,'保存')
        try
            save_system(tgtModel);
            fprintf('已保存模型：%s\n', tgtModel);
        catch ME
            warning('保存模型失败：%s', ME.message);
        end
    end
end

%% ===== Local helpers（仅模型生成使用）=====
function ensureSubsystem(parentSys, subName, pos)
    if nargin < 3
        pos = [30 30 200 120];
    end
    subPath = [parentSys '/' subName];
    exists = ~isempty(find_system(parentSys, 'SearchDepth', 1, 'Type','Block', 'Name', subName));
    if ~exists
        add_block('simulink/Ports & Subsystems/Subsystem', subPath, 'Position', pos);
    else
        try, set_param(subPath, 'Position', pos); catch, end
    end
end

function setEnumConstantParams(blkPath, enumTypeName, enumValueExpr)
% 兼容不同 Simulink 版本的 Enumerated Constant 参数名差异：
% - 有的版本用 OutDataTypeStr
% - 有的版本用 DataType / OutDataType
% 同时设置 Value = EnumType.Member

    % 先设置 Value（基本都支持）
    try
        set_param(blkPath, 'Value', char(enumValueExpr));
    catch ME
        warning('枚举常量设置 Value 失败：%s（%s）', blkPath, ME.message);
    end

    % 再设置枚举数据类型：根据 DialogParameters 探测可用字段
    try
        d = get_param(blkPath, 'DialogParameters');

        if isfield(d, 'OutDataTypeStr')
            set_param(blkPath, 'OutDataTypeStr', char(enumTypeName));
            return;
        end
        if isfield(d, 'DataType')
            set_param(blkPath, 'DataType', char(enumTypeName));
            return;
        end
        if isfield(d, 'OutDataType')
            set_param(blkPath, 'OutDataType', char(enumTypeName));
            return;
        end

        warning('枚举常量块未发现可设置类型的参数(OutDataTypeStr/DataType/OutDataType)：%s', blkPath);
    catch ME
        warning('枚举常量设置 DataType 失败：%s（%s）', blkPath, ME.message);
    end
end