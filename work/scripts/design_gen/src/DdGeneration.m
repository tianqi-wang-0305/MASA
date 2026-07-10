rootDir = fileparts(mfilename("fullpath"));
if strlength(rootDir) == 0
    rootDir = pwd;
end

addpath(rootDir);
rptModel = promptForModelFile();
modelName = rptModel.ModelName;
modelDir = rptModel.ModelDir;
excelInfo = promptForExcelFile(modelDir);

loadReportDependencies(modelDir);
load_system(modelName);
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
tp.Title = modelName + " Detail Design";
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

% 第四章节：子系统导航
systems = collectReportSystems(modelName);
topLevelSystems = getChildSubsystems(systems, modelName);

navSec = mlreportgen.report.Section;
navSec.Title = "Subsystem Navigation";
navSec.LinkTarget = "section_subsystem_navigation";
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
    targetId = sectionTargetId(sys.Path, modelName);
    if sys.Path == string(modelName)
        linkText = "Model Overview";
        descriptionText = getModelDescription(sys.Path);
    else
        linkText = sys.Name;
        descriptionText = getModelDescription(sys.Path);
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
sec.LinkTarget = sectionTargetId(modelName, modelName);
appendSectionDescription(sec, getModelDescription(modelName));
appendDiagram(sec, get_param(modelName, "Handle"));
append(rpt, sec);
append(rpt, mlreportgen.dom.PageBreak);

for k = 1:numel(topLevelSystems)
    sec = buildSubsystemSection(topLevelSystems(k), systems, modelName);
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

signalSheet = findSheetByName(sheets, ["signals", "signal"]);
calSheet = findSheetByName(sheets, ["calibration", "cal"]);

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

function sheetName = findSheetByName(sheets, targetNames)
sheetName = "";
for i = 1:numel(sheets)
    currentName = strtrim(string(sheets(i)));
    for j = 1:numel(targetNames)
        if strcmpi(currentName, string(targetNames(j)))
            sheetName = string(sheets(i));
            return;
        end
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
preferred = ["PortName", "SignalName", "Direction", "DataType", "Dimensions", "Description"];
filtered = selectExistingColumns(dataTable, preferred);
end

function filtered = selectCalibrationColumns(dataTable)
preferred = ["Name", "BlockType", "DataType", "Value", "Min", "Max", "Unit", "Description"];
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

function targetId = sectionTargetId(sys, modelName)
if string(sys) == string(modelName)
    targetId = "section_model_overview";
else
    sanitizedName = regexprep(string(sys), "[^A-Za-z0-9]", "_");
    targetId = "section_" + sanitizedName;
end
targetId = char(targetId);
end

function systems = collectReportSystems(modelName)
systems = struct("Path", {}, "Name", {}, "ParentPath", {}, "Depth", {});
visited = strings(0, 1);
visitSubsystemChildren(string(modelName), string(modelName), 0);

    function visitSubsystemChildren(containerPath, parentPath, depth)
        childPaths = find_system(containerPath, ...
            "LookUnderMasks", "all", ...
            "FollowLinks", "on", ...
            "SearchDepth", 1, ...
            "Type", "Block", ...
            "BlockType", "SubSystem");
        childPaths = string(childPaths);
        childPaths = childPaths(childPaths ~= string(containerPath));
        childPaths = filterRenderableSubsystems(childPaths);
        childPaths = sortSubsystemsByDiagramOrder(childPaths);

        for i = 1:numel(childPaths)
            childPath = childPaths(i);
            if any(visited == childPath)
                continue;
            end

            visited(end + 1, 1) = childPath; %#ok<AGROW>
            childInfo = struct();
            childInfo.Path = childPath;
            childInfo.Name = string(get_param(childPath, "Name"));
            childInfo.ParentPath = parentPath;
            childInfo.Depth = depth + 1;
            systems(end + 1, 1) = childInfo; %#ok<AGROW>

            visitSubsystemChildren(childPath, childPath, depth + 1);
        end
    end

    function filteredPaths = filterRenderableSubsystems(candidatePaths)
        keep = true(size(candidatePaths));
        for i = 1:numel(candidatePaths)
            sys = candidatePaths(i);

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

        filteredPaths = candidatePaths(keep);
    end

    function orderedPaths = sortSubsystemsByDiagramOrder(candidatePaths)
        if numel(candidatePaths) < 2
            orderedPaths = candidatePaths;
            return;
        end

        positions = zeros(numel(candidatePaths), 4);
        for i = 1:numel(candidatePaths)
            try
                positions(i, :) = double(get_param(candidatePaths(i), "Position"));
            catch
                positions(i, :) = [inf, inf, inf, inf];
            end
        end

        [~, order] = sortrows(positions(:, [2, 1]));
        orderedPaths = candidatePaths(order);
    end
end

function descriptionText = getModelDescription(sys)
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

function appendSectionNavigation(sec, currentPath, parentPath, modelName)
currentPath = string(currentPath);
parentPath = string(parentPath);
modelName = string(modelName);

navParagraph = mlreportgen.dom.Paragraph;

if currentPath == modelName
    append(navParagraph, mlreportgen.dom.InternalLink("section_subsystem_navigation", "Back to subsystem navigation"));
    append(sec, navParagraph);
    return;
end

append(navParagraph, mlreportgen.dom.Text("Navigation: "));

if parentPath == modelName
    parentTarget = sectionTargetId(modelName, modelName);
    parentLabel = "Model Overview";
    append(navParagraph, mlreportgen.dom.InternalLink(parentTarget, "Back to model overview"));
    append(navParagraph, mlreportgen.dom.Text(" | "));
    append(navParagraph, mlreportgen.dom.InternalLink("section_subsystem_navigation", "Back to subsystem navigation"));
else
    parentTarget = sectionTargetId(parentPath, modelName);
    append(navParagraph, mlreportgen.dom.InternalLink(parentTarget, "Back to previous level"));
    append(navParagraph, mlreportgen.dom.Text(" | "));
    append(navParagraph, mlreportgen.dom.InternalLink(sectionTargetId(modelName, modelName), "Back to model overview"));
end
append(sec, navParagraph);
end

function section = buildSubsystemSection(sys, systems, modelName)
section = mlreportgen.report.Section;
section.Title = sys.Name;
section.LinkTarget = sectionTargetId(sys.Path, modelName);

appendSectionDescription(section, getModelDescription(sys.Path));
appendDiagram(section, get_param(sys.Path, "Handle"));
appendSectionNavigation(section, sys.Path, sys.ParentPath, modelName);

childSystems = getChildSubsystems(systems, sys.Path);
for i = 1:numel(childSystems)
    append(section, buildSubsystemSection(childSystems(i), systems, modelName));
end
end

function childSystems = getChildSubsystems(systems, parentPath)
if isempty(systems)
    childSystems = systems;
    return;
end

parentPaths = string({systems.ParentPath});
childSystems = systems(parentPaths == string(parentPath));
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