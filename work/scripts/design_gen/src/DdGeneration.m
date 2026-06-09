rootDir = fileparts(mfilename("fullpath"));
if strlength(rootDir) == 0
    rootDir = pwd;
end

addpath(rootDir);
rptModel = promptForModelFile();
modelFile = rptModel.FilePath;
modelName = rptModel.ModelName;
modelDir = rptModel.ModelDir;
excelInfo = promptForExcelFile(modelDir);

loadReportDependencies(modelDir);
load_system(modelName);
loadedModel = modelName;
interfaceData = readInterfaceWorkbook(excelInfo.FilePath);

rptFileBase = fullfile(modelDir, modelName + "_DetailDesign");
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

% 封面
tp = mlreportgen.report.TitlePage;
tp.Title = modelName + " Simulink Report";
tp.Subtitle = "Auto-generated model documentation";
append(rpt, tp);

% 目录
append(rpt, mlreportgen.report.TableOfContents);

if ~isempty(interfaceData)
    append(rpt, buildInputSignalSection(interfaceData.Interface));
    append(rpt, mlreportgen.dom.PageBreak);
    append(rpt, buildOutputSignalSection(interfaceData.Interface));
    append(rpt, mlreportgen.dom.PageBreak);
    append(rpt, buildCalibrationSection(interfaceData.Calibration));
    append(rpt, mlreportgen.dom.PageBreak);
end

% 子系统导航页：点击名称跳转到对应章节
systems = collectReportSystems(loadedModel);

navSec = mlreportgen.report.Section;
navSec.Title = "Subsystem Navigation";
append(navSec, mlreportgen.dom.Paragraph( ...
    "Click a subsystem name to jump to its corresponding report section."));

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
    targetId = sectionTargetId(sys, loadedModel, k);
    if sys == string(loadedModel)
        linkText = "Model Overview";
        descriptionText = getModelDescription(sys);
    else
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

% 页面 1：根模型概览
sec = mlreportgen.report.Section;
sec.Title = "Model Overview";
sec.LinkTarget = sectionTargetId(loadedModel, loadedModel, 1);
appendSectionDescription(sec, getModelDescription(loadedModel));
appendDiagram(sec, get_param(loadedModel, "Handle"));
append(rpt, sec);
append(rpt, mlreportgen.dom.PageBreak);

for k = 1:numel(systems)
    sys = systems(k);

    % 跳过根模型，根模型已单独出过一页
    if sys == string(loadedModel)
        continue;
    end

    sec = mlreportgen.report.Section;
    sec.Title = get_param(sys, "Name");
    sec.LinkTarget = sectionTargetId(sys, loadedModel, k);

    appendSectionDescription(sec, getModelDescription(sys));
    appendDiagram(sec, get_param(sys, "Handle"));

    append(rpt, sec);
    append(rpt, mlreportgen.dom.PageBreak);
end

close(rpt);
if usejava("desktop")
    rptview(rpt);
end

function modelInfo = promptForModelFile()
if usejava("desktop")
    [modelFile, modelDir] = uigetfile({"*.slx;*.mdl", "Simulink Models (*.slx, *.mdl)"}, ...
        "Select a Simulink model file");
    if isequal(modelFile, 0)
        error("No model file selected.");
    end
    modelPath = string(fullfile(modelDir, modelFile));
else
    modelPath = input("Enter the full path of the Simulink model file: ", "s");
    if strlength(string(modelPath)) == 0
        error("No model file selected.");
    end
    modelPath = string(modelPath);
end

[modelDir, modelBase, modelExt] = fileparts(modelPath);
modelPath = string(fullfile(modelDir, [modelBase modelExt]));

modelInfo = struct();
modelInfo.FilePath = modelPath;
modelInfo.ModelName = string(modelBase);
modelInfo.ModelDir = string(modelDir);
end

function loadReportDependencies(rootDir)
dependencyFiles = promptForDependencyFiles(rootDir);

currentDir = pwd;
cleanupDir = onCleanup(@() cd(currentDir));
cd(rootDir);

for i = 1:numel(dependencyFiles)
    dependencyPath = dependencyFiles(i);
    [~, ~, ext] = fileparts(dependencyPath);
    if strcmpi(ext, ".m")
        scriptText = fileread(dependencyPath);
        evalin("base", scriptText);
    elseif strcmpi(ext, ".mat")
        loadStatement = "load('" + strrep(dependencyPath, "'", "''") + "');";
        evalin("base", loadStatement);
    end
end
end

function excelInfo = promptForExcelFile(defaultDir)
if usejava("desktop")
    [excelFile, excelDir] = uigetfile({"*.xlsx;*.xls;*.xlsm", "Excel Files (*.xlsx, *.xls, *.xlsm)"}, ...
        "Select interface/calibration Excel file", string(defaultDir));
    if isequal(excelFile, 0)
        error("No Excel file selected.");
    end
    excelPath = fullfile(excelDir, excelFile);
else
    excelPath = input("Enter the full path of the Excel file: ", "s");
    if strlength(string(excelPath)) == 0
        error("No Excel file selected.");
    end
end

excelInfo = struct();
excelInfo.FilePath = string(excelPath);
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

function idx = findHeaderIndex(headers, candidates)
idx = 0;
normalizedHeaders = lower(strtrim(headers));
for i = 1:numel(candidates)
    candidate = lower(strtrim(candidates(i)));
    match = find(normalizedHeaders == candidate | startsWith(normalizedHeaders, candidate), 1);
    if ~isempty(match)
        idx = match;
        return;
    end
end
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

function targetId = sectionTargetId(sys, modelName, index)
if sys == modelName
    targetId = "section_model_overview";
else
    sanitizedName = regexprep(string(sys), "[^A-Za-z0-9]", "_");
    targetId = "section_" + sanitizedName + "_" + string(index);
end
targetId = char(targetId);
end

function systems = collectReportSystems(modelName)
subsystemPaths = string(find_system(modelName, ...
    "LookUnderMasks","all", ...
    "FollowLinks","on", ...
    "Type","Block", ...
    "BlockType","SubSystem"));
stateflowChartPaths = collectStateflowChartPaths(modelName);

allSystems = unique([string(modelName); subsystemPaths; stateflowChartPaths], "stable");

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

function chartPaths = collectStateflowChartPaths(modelName)
chartPaths = strings(0, 1);

try
    root = sfroot;
    charts = root.find("-isa", "Stateflow.Chart");
catch
    return;
end

modelPrefix = string(modelName) + "/";
for i = 1:numel(charts)
    try
        chartPath = string(charts(i).Path);
    catch
        continue;
    end

    if strlength(chartPath) == 0
        continue;
    end

    if strcmpi(chartPath, string(modelName)) || startsWith(chartPath, modelPrefix)
        chartPaths(end + 1, 1) = chartPath; %#ok<AGROW>
    end
end

chartPaths = unique(chartPaths, "stable");
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
    append(sec, mlreportgen.dom.Paragraph( ...
        "Diagram snapshot unavailable for this level: " + string(diagramError.message)));
end
end

function dependencyFiles = promptForDependencyFiles(rootDir)
dependencyFiles = strings(0, 1);
if usejava("desktop")
    [files, depDir] = uigetfile({"*.m;*.mat", "MATLAB Files (*.m, *.mat)"}, ...
        "Select dependency .m or .mat files", "MultiSelect", "on");
    if isequal(files, 0)
        return;
    end

    if ischar(files) || isstring(files)
        files = cellstr(files);
    end

    for i = 1:numel(files)
        dependencyFiles(end + 1, 1) = string(fullfile(depDir, files{i})); %#ok<AGROW>
    end
else
    answer = input("Enter dependency file paths separated by semicolons, or press Enter to skip: ", "s");
    if strlength(string(answer)) == 0
        return;
    end

    parts = split(string(answer), ";");
    for i = 1:numel(parts)
        candidate = strtrim(parts(i));
        if strlength(candidate) > 0
            if isfile(candidate)
                dependencyFiles(end + 1, 1) = candidate; %#ok<AGROW>
            elseif isfile(fullfile(rootDir, candidate))
                dependencyFiles(end + 1, 1) = fullfile(rootDir, candidate); %#ok<AGROW>
            end
        end
    end
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