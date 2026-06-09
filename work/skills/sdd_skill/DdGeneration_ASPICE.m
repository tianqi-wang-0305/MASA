function pdfFile = DdGeneration_ASPICE(modelPath, excelPath)
rootDir = fileparts(mfilename("fullpath"));
if strlength(rootDir) == 0
    rootDir = pwd;
end

addpath(rootDir);

if nargin < 1 || strlength(string(modelPath)) == 0
    modelPath = string(getenv("SDD_MODEL_PATH"));
end
if nargin < 2 || strlength(string(excelPath)) == 0
    excelPath = string(getenv("SDD_EXCEL_PATH"));
end

modelPath = string(modelPath);
excelPath = string(excelPath);
if strlength(modelPath) == 0
    error("Model path is required.");
end
if strlength(excelPath) == 0
    error("Excel path is required.");
end

[modelDir, modelBase, modelExt] = fileparts(char(modelPath));
if strlength(string(modelBase)) == 0
    pathParts = split(string(modelPath), filesep);
    if numel(pathParts) >= 2
        modelDir = char(join(pathParts(1:end-1), filesep));
        [~, modelBase, modelExt] = fileparts(char(pathParts(end)));
    end
end
if strlength(string(modelDir)) == 0
    modelDir = pwd;
end
modelPath = string(fullfile(modelDir, [modelBase modelExt]));
modelName = string(modelBase);

loadReportDependencies(modelDir);
currentDir = pwd;
cleanupDir = onCleanup(@() cd(currentDir));
cd(modelDir);
load_system(modelName);
interfaceData = readInterfaceWorkbook(excelPath);

rptFileBase = fullfile(modelDir, modelName + "_DetailDesign_ASPICE");
rptFile = rptFileBase;
pdfFile = rptFile + ".pdf";

if isfile(pdfFile)
    fid = fopen(pdfFile, "a");
    if fid < 0
        rptFile = rptFileBase + "_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
        pdfFile = rptFile + ".pdf";
    else
        fclose(fid);
        delete(pdfFile);
    end
end

rpt = slreportgen.report.Report(rptFile, "pdf");
rpt.CompileModelBeforeReporting = false;

tp = mlreportgen.report.TitlePage;
tp.Title = modelName + " Detailed Design Document";
tp.Subtitle = "Source workbook: " + excelPath;
append(rpt, tp);

append(rpt, mlreportgen.report.TableOfContents);

if ~isempty(interfaceData)
    append(rpt, buildInputSignalSection(interfaceData.Interface));
    append(rpt, mlreportgen.dom.PageBreak);
    append(rpt, buildOutputSignalSection(interfaceData.Interface));
    append(rpt, mlreportgen.dom.PageBreak);
    append(rpt, buildCalibrationSection(interfaceData.Calibration));
    append(rpt, mlreportgen.dom.PageBreak);
end

navSec = mlreportgen.report.Section;
navSec.Title = "Subsystem Navigation";
append(navSec, mlreportgen.dom.Paragraph("Click a subsystem name to jump to its corresponding report section."));

systems = collectReportSystems(modelName);
navTable = mlreportgen.dom.Table(2);
navTable.Width = "100%";
navTable.Border = "solid";
navTable.ColSep = "solid";
navTable.RowSep = "solid";
navTable.TableEntriesInnerMargin = "4pt";

headerRow = mlreportgen.dom.TableRow;
append(headerRow, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph("Subsystem")));
append(headerRow, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph("Description")));
append(navTable, headerRow);

for k = 1:numel(systems)
    sys = systems(k);
    if sys == string(modelName)
        targetId = modelOverviewTargetId();
        linkText = "Model Overview";
        descriptionText = getModelDescription(sys);
    else
        targetId = sectionTargetId(sys, 1, k);
        linkText = get_param(sys, "Name");
        descriptionText = getModelDescription(sys);
    end

    row = mlreportgen.dom.TableRow;
    linkParagraph = mlreportgen.dom.Paragraph(mlreportgen.dom.InternalLink(targetId, linkText));
    append(row, mlreportgen.dom.TableEntry(linkParagraph));
    append(row, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph(descriptionText)));
    append(navTable, row);
end

append(navSec, navTable);
append(rpt, navSec);
append(rpt, mlreportgen.dom.PageBreak);

overviewSec = mlreportgen.report.Section;
overviewSec.Title = "Model Overview";
overviewSec.LinkTarget = modelOverviewTargetId();
appendSectionDescription(overviewSec, composeModelOverview(modelName, modelPath));
appendDiagram(overviewSec, get_param(modelName, "Handle"));

appendSubsystemTree(overviewSec, modelName, modelPath, modelName, 1);
append(rpt, overviewSec);

close(rpt);
if usejava("desktop")
    rptview(rpt);
end

end

function modelSummary = composeModelOverview(modelName, modelPath)
modelSummary = strings(0, 1);
modelSummary(end + 1, 1) = "我将这个模型理解为车身中央门锁控制软件的顶层实现，它负责把车门状态、车速、开关请求、碰撞状态和故障状态等外部信息统一纳入控制逻辑，最终输出门锁控制、电机驱动、状态指示和尾门相关结果。";
modelSummary(end + 1, 1) = "从功能上看，我把它划分为控制决策、尾门处理、状态提示和执行驱动几个层次；这些层次共同完成请求判断、动作裁决、输出分发和异常抑制。";
modelSummary(end + 1, 1) = "本章只展示顶层模型的截图和整体功能说明，不展开接口清单或内部元数据。";
end

function appendSubsystemTree(parentSection, modelName, modelPath, parentPath, level)
children = getDirectSubsystems(parentPath);
for i = 1:numel(children)
    childPath = children(i);
    childName = string(get_param(childPath, "Name"));

    if shouldSkipSubsystem(childPath)
        continue;
    end

    sec = mlreportgen.report.Section;
    sec.Title = resolveSubsystemTitle(childPath, parentPath, childName);
    sec.LinkTarget = sectionTargetId(childPath, level, i);

    descriptionText = composeSubsystemDescription(modelName, modelPath, childPath, parentPath, level);
    appendSectionDescription(sec, descriptionText);
    appendDiagram(sec, get_param(childPath, "Handle"));

    append(parentSection, sec);
    appendSubsystemTree(sec, modelName, modelPath, childPath, level + 1);
end
end

function textBlocks = composeSubsystemDescription(modelName, modelPath, sysPath, parentPath, level)
textBlocks = strings(0, 1);
textBlocks(end + 1, 1) = composeSubsystemBehaviorSummary(sysPath, parentPath);
end

function summaryText = composeSubsystemBehaviorSummary(sysPath, parentPath)
behaviorText = inferBehaviorTextFromModelRead(sysPath);
if strlength(behaviorText) == 0
    behaviorText = inferBehaviorTextFromStructure(sysPath);
end
summaryText = behaviorText;
if ~endsWith(summaryText, "。") && ~endsWith(summaryText, ".")
    summaryText = summaryText + "。";
end
end

function behaviorText = inferBehaviorTextFromModelRead(sysPath)
behaviorText = "";
try
    modelName = string(bdroot(sysPath));
    scopeId = resolveBlockScopeId(sysPath);
    readValue = model_read(modelName, "root", scopeId);
    readText = string(readValue);
    if contains(lower(readText), "invalid_param") || contains(lower(readText), "error_code")
        behaviorText = "";
        return;
    end
    behaviorText = summarizeModelReadText(readText);
catch
    behaviorText = "";
end
end

function behaviorText = inferBehaviorTextFromStructure(sysPath)
blockSummary = summarizeDominantBlocks(sysPath);
behaviorText = summarizeModelReadText(lower(string(blockSummary)));
end

function behaviorText = summarizeModelReadText(readText)
readText = strtrim(string(readText));
if strlength(readText) == 0
    behaviorText = "完成局部信号处理和功能传递";
    return;
end

lines = split(readText, newline);
lines = strtrim(lines);
lines = lines(strlength(lines) > 0);
skipPrefixes = ["status:", "model:", "scope:", "token_estimate:", "blocks:", "interfaces:", "- id:", "in:", "out:"];
candidateLines = strings(0, 1);
for i = 1:numel(lines)
    lineText = lower(lines(i));
    shouldSkip = false;
    for j = 1:numel(skipPrefixes)
        if startsWith(lineText, skipPrefixes(j))
            shouldSkip = true;
            break;
        end
    end
    if ~shouldSkip
        candidateLines(end + 1, 1) = lines(i); %#ok<AGROW>
    end
end

if isempty(candidateLines)
    behaviorText = "完成局部信号处理和功能传递";
    return;
end

behaviorText = candidateLines(1);
behaviorText = regexprep(behaviorText, "^[-*\s]+", "");
behaviorText = regexprep(behaviorText, "\s+", " ");
if ~endsWith(behaviorText, "。") && ~endsWith(behaviorText, ".")
    behaviorText = behaviorText + "";
end
end

function roleText = specialSubsystemRole(sysName)
lowerName = lower(string(sysName));
roleText = "";

if lowerName == "command"
    roleText = "控制决策与仲裁";
elseif lowerName == "tailgate"
    roleText = "尾门控制与请求裁决";
elseif lowerName == "lightcontral"
    roleText = "状态指示与灯光提示";
elseif lowerName == "motorcontral"
    roleText = "电机驱动与执行输出";
end
end

function scopeId = resolveBlockScopeId(sysPath)
scopeId = "";
try
    sidValue = string(get_param(sysPath, "SID"));
    scopeId = regexprep(sidValue, "^blk_", "");
catch
    scopeId = "";
end
end

function titleText = resolveSubsystemTitle(childPath, parentPath, childName)
titleText = strtrim(string(childName));
genericNames = ["chart", "subsystem", "function", "stateflow chart"];
if any(strcmpi(titleText, genericNames))
    try
        parentName = strtrim(string(get_param(parentPath, "Name")));
    catch
        parentName = "";
    end
    if strlength(parentName) > 0 && ~any(strcmpi(parentName, genericNames))
        titleText = parentName;
        return;
    end

    try
        owningName = strtrim(string(get_param(bdroot(childPath), "Name")));
    catch
        owningName = "";
    end
    if strlength(owningName) > 0
        titleText = owningName;
    end
end
end

function roleText = inferRoleText(sysName, blockSummary, childSubsystems)
lowerName = lower(string(sysName));
if contains(lowerName, "command")
    roleText = "状态判断、逻辑仲裁和控制决策";
elseif contains(lowerName, "tailgate")
    roleText = "尾门请求判定和动作裁决";
elseif contains(lowerName, "light")
    roleText = "状态指示和灯光提示";
elseif contains(lowerName, "motor")
    roleText = "电机驱动映射和执行输出";
elseif contains(blockSummary, "Switch") || contains(blockSummary, "Compare") || contains(blockSummary, "Logic")
    roleText = "条件判断与逻辑仲裁";
elseif contains(blockSummary, "Gain") || contains(blockSummary, "Sum") || contains(blockSummary, "Product")
    roleText = "运算变换与信号整形";
elseif contains(blockSummary, "Delay") || contains(blockSummary, "Memory")
    roleText = "时序保持与状态传递";
elseif contains(blockSummary, "Lookup") || contains(blockSummary, "Table")
    roleText = "标定查表与参数映射";
elseif ~isempty(childSubsystems)
    roleText = "功能拆分与局部控制组织";
else
    roleText = "信号处理";
end
end

function namesText = formatNameList(names)
if isempty(names)
    namesText = "未显式暴露的端口";
    return;
end

namesText = strjoin(names.', "、");
end

function names = getDirectPortNames(sysPath, blockType)
blocks = find_system(sysPath, "SearchDepth", 1, "BlockType", blockType);
names = strings(0, 1);
for i = 1:numel(blocks)
    if string(blocks{i}) == string(sysPath)
        continue;
    end
    names(end + 1, 1) = string(get_param(blocks{i}, "Name")); %#ok<AGROW>
end
end

function summary = summarizeDominantBlocks(sysPath)
blocks = find_system(sysPath, "SearchDepth", 1);
counts = containers.Map("KeyType", "char", "ValueType", "double");

for i = 1:numel(blocks)
    blockPath = string(blocks{i});
    if blockPath == string(sysPath)
        continue;
    end

    try
        blockType = string(get_param(blockPath, "BlockType"));
    catch
        blockType = "";
    end

    if blockType == "SubSystem" || blockType == "Inport" || blockType == "Outport"
        continue;
    end

    if strlength(blockType) == 0
        continue;
    end

    key = char(blockType);
    if isKey(counts, key)
        counts(key) = counts(key) + 1;
    else
        counts(key) = 1;
    end
end

if counts.Count == 0
    summary = "接口/层级组织";
    return;
end

keysList = string(keys(counts));
valuesList = zeros(numel(keysList), 1);
for i = 1:numel(keysList)
    valuesList(i) = counts(char(keysList(i)));
end

[~, order] = sort(valuesList, "descend");
selected = keysList(order(1:min(4, numel(order))));
summary = strjoin(selected.', "、");
end

function children = getDirectSubsystems(parentPath)
blocks = find_system(parentPath, "SearchDepth", 1, "BlockType", "SubSystem");
children = strings(0, 1);
for i = 1:numel(blocks)
    blockPath = string(blocks{i});
    if blockPath == string(parentPath)
        continue;
    end
    if shouldSkipSubsystem(blockPath)
        continue;
    end
    children(end + 1, 1) = blockPath; %#ok<AGROW>
end
end

function tf = shouldSkipSubsystem(sysPath)
tf = false;
try
    sysName = lower(string(get_param(sysPath, "Name")));
catch
    sysName = "";
end

try
    blockType = lower(string(get_param(sysPath, "BlockType")));
catch
    blockType = "";
end

try
    maskType = lower(string(get_param(sysPath, "MaskType")));
catch
    maskType = "";
end

if contains(sysName, "event listener") || contains(sysName, "eventlistener") || ...
        contains(maskType, "event listener") || contains(blockType, "eventlistener") || ...
        contains(sysName, "enumerated constant") || contains(maskType, "enumerated constant") || ...
        strcmpi(blockType, "EnumeratedConstant")
    tf = true;
end
end

function appendSectionDescription(sec, descriptionText)
descriptionText = string(descriptionText);
descriptionText = strtrim(descriptionText);
if strlength(descriptionText) == 0
    return;
end

parts = split(descriptionText, newline);
parts = parts(strlength(strtrim(parts)) > 0);
for i = 1:numel(parts)
    append(sec, mlreportgen.dom.Paragraph(strtrim(parts(i))));
end
end

function appendDiagram(sec, sourceHandle)
try
    diag = slreportgen.report.Diagram(sourceHandle);
    diag.SnapshotFormat = "pdf";
    diag.Scaling = "auto";
    diag.Width = "6.8in";
    diag.MaxWidth = "6.8in";
    diag.MaxHeight = "9.0in";
    append(sec, diag);
catch diagramError
    append(sec, mlreportgen.dom.Paragraph("Diagram snapshot unavailable for this level: " + string(diagramError.message)));
end
end

function targetId = sectionTargetId(sysId, level, index)
sanitized = regexprep(string(sysId), "[^A-Za-z0-9]", "_");
targetId = char("section_" + sanitized + "_" + string(level) + "_" + string(index));
end

function targetId = modelOverviewTargetId()
targetId = "section_model_overview";
end

function systems = collectReportSystems(modelName)
allSystems = unique([string(modelName); string(find_system(modelName, ...
    "LookUnderMasks", "all", ...
    "FollowLinks", "on", ...
    "Type", "Block", ...
    "BlockType", "SubSystem"))], "stable");

keep = true(size(allSystems));
for i = 1:numel(allSystems)
    sys = allSystems(i);
    if sys == string(modelName)
        continue;
    end

    try
        sysName = string(get_param(sys, "Name"));
    catch
        sysName = sys;
    end

    try
        maskType = string(get_param(sys, "MaskType"));
    catch
        maskType = "";
    end

    try
        blockType = string(get_param(sys, "BlockType"));
    catch
        blockType = "";
    end

    if contains(sysName, "Enumerated Constant", "IgnoreCase", true) || ...
       contains(maskType, "Enumerated Constant", "IgnoreCase", true) || ...
       strcmpi(blockType, "EnumeratedConstant")
        keep(i) = false;
    end
end

systems = allSystems(keep);
end

function descriptionText = getModelDescription(sys)
descriptionText = "";
try
    descriptionText = string(get_param(sys, "Description"));
catch
    descriptionText = "";
end

descriptionText = strtrim(descriptionText);
if strlength(descriptionText) == 0
    descriptionText = "";
end
end

function loadReportDependencies(rootDir)
dependencyFiles = strings(0, 1);
envValue = string(getenv("SDD_DEPENDENCY_FILES"));
if strlength(envValue) > 0
    parts = split(envValue, ";");
    for i = 1:numel(parts)
        candidate = strtrim(parts(i));
        if strlength(candidate) > 0 && isfile(candidate)
            dependencyFiles(end + 1, 1) = candidate; %#ok<AGROW>
        elseif strlength(candidate) > 0 && isfile(fullfile(rootDir, candidate))
            dependencyFiles(end + 1, 1) = fullfile(rootDir, candidate); %#ok<AGROW>
        end
    end
end

currentDir = pwd;
cleanupDir = onCleanup(@() cd(currentDir));
cd(rootDir);

for i = 1:numel(dependencyFiles)
    dependencyPath = dependencyFiles(i);
    [~, ~, ext] = fileparts(dependencyPath);
    if strcmpi(ext, ".m")
        run(dependencyPath);
    elseif strcmpi(ext, ".mat")
        load(dependencyPath);
    end
end
end

function workbookData = readInterfaceWorkbook(excelPath)
workbookData = struct("Interface", struct(), "Calibration", struct());
try
    sheets = sheetnames(excelPath);
catch
    sheets = strings(0, 1);
end

if numel(sheets) < 1
    return;
end

signalSheet = findSheetByName(sheets, "signal");
calSheet = findSheetByName(sheets, "cal");

if strlength(signalSheet) == 0
    signalSheet = sheets(1);
end
if strlength(calSheet) == 0 && numel(sheets) >= 2
    calSheet = sheets(min(2, numel(sheets)));
end

workbookData.Interface = readSignalWorkbookSheet(excelPath, signalSheet);
if strlength(calSheet) > 0
    workbookData.Calibration = readCalibrationWorkbookSheet(excelPath, calSheet);
end
end

function sheetName = findSheetByName(sheets, targetName)
sheetName = "";
for i = 1:numel(sheets)
    if strcmpi(strtrim(string(sheets(i))), targetName)
        sheetName = string(sheets(i));
        return;
    end
end
end

function sheetData = readSignalWorkbookSheet(excelPath, sheetName)
raw = readcell(excelPath, "Sheet", sheetName);
sheetData = struct("SheetName", string(sheetName), "Items", table());

if isempty(raw)
    return;
end

headers = string(raw(1, :));
headers = strtrim(headers);
data = raw(2:end, :);

sheetData.Items = extractTabularRows(data, headers);
end

function sheetData = readCalibrationWorkbookSheet(excelPath, sheetName)
raw = readcell(excelPath, "Sheet", sheetName);
sheetData = struct("SheetName", string(sheetName), "Items", table());

if isempty(raw)
    return;
end

headers = string(raw(1, :));
headers = strtrim(headers);
data = raw(2:end, :);
sheetData.Items = extractTabularRows(data, headers);
end

function outTable = extractTabularRows(data, headers)
if isempty(data)
    outTable = table();
    return;
end

headerNames = standardizeHeaderNames(headers);
rows = cell(size(data, 1), numel(headerNames));
for r = 1:size(data, 1)
    for c = 1:numel(headerNames)
        if c <= size(data, 2)
            rows{r, c} = data{r, c};
        else
            rows{r, c} = "";
        end
    end
end

outTable = cell2table(rows, "VariableNames", cellstr(headerNames));
end

function headerNames = standardizeHeaderNames(headers)
headerNames = strings(size(headers));
for i = 1:numel(headers)
    headerNames(i) = sanitizeVariableName(headers(i), i);
end
end

function name = sanitizeVariableName(value, index)
name = string(value);
name = strtrim(name);
if strlength(name) == 0
    name = "Column" + string(index);
end
name = regexprep(name, "[^A-Za-z0-9_]", "_");
if ~isletter(extractBefore(name, 2)) && extractBefore(name, 2) ~= "_"
    name = "Col_" + name;
end
while contains(name, "__")
    name = replace(name, "__", "_");
end
name = matlab.lang.makeValidName(char(name));
end

function section = buildInputSignalSection(interfaceData)
section = mlreportgen.report.Section;
section.Title = "Input Signals";

append(section, mlreportgen.dom.Paragraph("Source: worksheet ""signal"" of the selected Excel file."));

if ~isempty(fieldnames(interfaceData)) && ~isempty(interfaceData.Items)
    inputSignals = selectSignalRowsByDirection(interfaceData.Items, "Input");
    append(section, tableToDom(selectSignalColumns(inputSignals)));
end
end

function section = buildOutputSignalSection(interfaceData)
section = mlreportgen.report.Section;
section.Title = "Output Signals";

append(section, mlreportgen.dom.Paragraph("Source: worksheet ""signal"" of the selected Excel file."));

if ~isempty(fieldnames(interfaceData)) && ~isempty(interfaceData.Items)
    outputSignals = selectSignalRowsByDirection(interfaceData.Items, "Output");
    append(section, tableToDom(selectSignalColumns(outputSignals)));
end
end

function section = buildCalibrationSection(calibrationData)
section = mlreportgen.report.Section;
section.Title = "Calibration";

append(section, mlreportgen.dom.Paragraph("Source: worksheet ""cal"" of the selected Excel file."));
if ~isempty(calibrationData.Items)
    append(section, tableToDom(selectCalibrationColumns(calibrationData.Items)));
end
end

function filtered = selectSignalColumns(dataTable)
preferred = ["SignalName", "Direction", "Description", "DataType", "InitialValue", "InitialValu", "Factor", "Offset", "Min", "Max", "Unit", "Dimensions"];
filtered = selectExistingColumns(dataTable, preferred);
if ~any(strcmpi(filtered.Properties.VariableNames, "Description"))
    filtered.Description = repmat(string(""), height(filtered), 1);
    if any(strcmpi(filtered.Properties.VariableNames, "Direction"))
        filtered = movevars(filtered, "Description", "After", "Direction");
    else
        filtered = movevars(filtered, "Description", "After", filtered.Properties.VariableNames{1});
    end
end
end

function filtered = selectCalibrationColumns(dataTable)
preferred = ["Name", "SWC", "Description", "Type", "DataType", "Value", "Min", "Max", "Unit", "Factor", "Offset", "Dimensions"];
filtered = selectExistingColumns(dataTable, preferred);
end

function filtered = selectExistingColumns(dataTable, preferred)
existing = string(dataTable.Properties.VariableNames);
ordered = strings(0, 1);
used = false(size(existing));
for i = 1:numel(preferred)
    match = find(~used & (strcmpi(existing, preferred(i)) | startsWith(existing, preferred(i), "IgnoreCase", true)), 1);
    if ~isempty(match)
        ordered(end + 1, 1) = existing(match); %#ok<AGROW>
        used(match) = true;
    end
end
if isempty(ordered)
    filtered = dataTable;
    return;
end

filtered = dataTable(:, cellstr(ordered));
filtered.Properties.VariableNames = cellstr(ordered);
end

function domTable = tableToDom(dataTable)
domTable = mlreportgen.dom.Table(width(dataTable));
domTable.Width = "100%";
domTable.Border = "solid";
domTable.ColSep = "solid";
domTable.RowSep = "solid";
domTable.TableEntriesInnerMargin = "4pt";

headerRow = mlreportgen.dom.TableRow;
for c = 1:width(dataTable)
    headerText = string(dataTable.Properties.VariableNames{c});
    headerText = replace(headerText, "_", " ");
    append(headerRow, mlreportgen.dom.TableEntry(makeParagraph(headerText)));
end
append(domTable, headerRow);

for r = 1:height(dataTable)
    row = mlreportgen.dom.TableRow;
    for c = 1:width(dataTable)
        value = dataTable{r, c};
        if ismissing(value) || (isstring(value) && strlength(value) == 0)
            textValue = "";
        elseif iscell(value)
            textValue = string(value{1});
        else
            textValue = string(value);
        end
        append(row, mlreportgen.dom.TableEntry(makeParagraph(textValue)));
    end
    append(domTable, row);
end
end

function para = makeParagraph(textValue)
para = mlreportgen.dom.Paragraph;
if strlength(string(textValue)) > 0
    append(para, char(string(textValue)));
end
end

function filtered = selectSignalRowsByDirection(dataTable, directionValue)
if isempty(dataTable) || ~ismember("Direction", string(dataTable.Properties.VariableNames))
    filtered = dataTable;
    return;
end

directionText = lower(strtrim(string(dataTable.Direction)));
keep = startsWith(directionText, lower(string(directionValue)));
filtered = dataTable(keep, :);
end

