function pdfFile = DdGeneration_AI(modelPath, excelPath, varargin)
% DdGeneration_AI  AI-Enhanced Detailed Design Document Generator
%   Generates ASPICE-compliant SDD PDF reports using deep model analysis
%   via the Simulink Agentic Toolkit tools for rich subsystem descriptions.
%
%   Inputs:
%       modelPath  - Full path to .slx/.mdl file
%       excelPath  - Full path to Excel interface/calibration workbook
%       varargin   - Optional 'ForceAnalyze', true  to force re-analysis
%                              'KnowledgeFile', 'path' to specify knowledge base
%
%   Outputs:
%       pdfFile    - Path to generated PDF report
%
%   Usage:
%       pdfFile = DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx');
%       pdfFile = DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx', 'ForceAnalyze', true);

    fprintf('=== DdGeneration_AI: AI-Enhanced SDD Report ===\n\n');

    %% Parse inputs
    p = inputParser;
    addParameter(p, 'ForceAnalyze', false, @islogical);
    addParameter(p, 'KnowledgeFile', '', @ischar);
    parse(p, varargin{:});
    forceAnalyze = p.Results.ForceAnalyze;
    userKnowledgeFile = p.Results.KnowledgeFile;

    %% 0) Resolve paths
    [modelDir, modelBase, ~] = fileparts(char(modelPath));
    if isempty(modelDir)
        modelDir = pwd;
    end
    modelName = string(modelBase);
    modelPath = fullfile(modelDir, modelBase + ".slx");
    if ~isfile(modelPath)
        modelPath = fullfile(modelDir, modelBase + ".mdl");
    end

    %% 1) Load or generate knowledge base
    knowledgeFile = fullfile(modelDir, modelName + "_model_knowledge.json");
    if ~isempty(userKnowledgeFile)
        knowledgeFile = userKnowledgeFile;
    end

    if forceAnalyze || ~isfile(knowledgeFile)
        fprintf('Generating deep model analysis...\n');
        knowledgeFile = analyzeModelDeepForSDD(modelPath, excelPath);
    else
        fprintf('Loading existing knowledge base: %s\n', knowledgeFile);
    end

    % Read knowledge base
    knowledgeJson = fileread(knowledgeFile);
    knowledgeBase = jsondecode(knowledgeJson);

    %% 2) Load model and report dependencies
    fprintf('Loading model: %s\n', modelName);
    load_system(modelPath);

    % DdGeneration_ASPICE.m is now in the same directory
    loadReportDependencies(modelDir);

    %% 3) Generate PDF report
    fprintf('Generating PDF report...\n');

    % Report file naming
    rptFileBase = fullfile(modelDir, modelName + "_DetailDesign_AI");
    rptFile = rptFileBase;
    pdfFile = rptFile + ".pdf";

    if isfile(pdfFile)
        fid = fopen(pdfFile, 'a');
        if fid < 0
            rptFile = rptFileBase + "_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            pdfFile = rptFile + ".pdf";
        else
            fclose(fid);
            delete(pdfFile);
        end
    end

    rpt = slreportgen.report.Report(rptFile, 'pdf');
    rpt.CompileModelBeforeReporting = false;

    %% ---- Title Page ----
    tp = mlreportgen.report.TitlePage;
    tp.Title = modelName + " Detailed Design Document (AI-Enhanced)";
    tp.Subtitle = sprintf("Source workbook: %s\nGenerated: %s\nAnalysis depth: %d subsystems", ...
        excelPath, knowledgeBase.analysisDate, knowledgeBase.analyzedSubsystems);
    append(rpt, tp);

    %% ---- Table of Contents ----
    append(rpt, mlreportgen.report.TableOfContents);

    %% ---- Input/Output/Calibration Sections ----
    if ~isempty(fieldnames(knowledgeBase.interfaceInfo))
        interfaceData = knowledgeBase.interfaceInfo;
        append(rpt, buildInputSignalSection(interfaceData.Interface));
        append(rpt, mlreportgen.dom.PageBreak);
        append(rpt, buildOutputSignalSection(interfaceData.Interface));
        append(rpt, mlreportgen.dom.PageBreak);
        append(rpt, buildCalibrationSection(interfaceData.Calibration));
        append(rpt, mlreportgen.dom.PageBreak);
    end

    %% ---- Subsystem Navigation Page ----
    navSec = mlreportgen.report.Section;
    navSec.Title = "Subsystem Navigation";
    append(navSec, mlreportgen.dom.Paragraph( ...
        "Click a subsystem name to jump to its corresponding report section."));

    % Build navigation table
    subNames = fieldnames(knowledgeBase.subsystems);
    navTable = mlreportgen.dom.Table(3);
    navTable.Width = '100%';
    navTable.Border = 'solid';
    navTable.ColSep = 'solid';
    navTable.RowSep = 'solid';
    navTable.TableEntriesInnerMargin = '4pt';

    % Header
    headerRow = mlreportgen.dom.TableRow;
    append(headerRow, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph('Subsystem')));
    append(headerRow, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph('Role')));
    append(headerRow, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph('Block Types')));
    append(navTable, headerRow);

    for i = 1:numel(subNames)
        sName = subNames{i};
        sInfo = knowledgeBase.subsystems.(sName);

        % Get first line of description as role summary
        descLines = split(sInfo.description, newline);
        roleSummary = strtrim(descLines(1));
        if strlength(roleSummary) > 100
            roleSummary = extractBefore(roleSummary, 100) + '...';
        end

        blockSummary = "";
        if isfield(sInfo, 'blockTypeSummary')
            blockSummary = string(sInfo.blockTypeSummary);
        end

        % Create link
        targetId = sectionTargetId(sName, 1, i);
        row = mlreportgen.dom.TableRow;

        linkPara = mlreportgen.dom.Paragraph(mlreportgen.dom.InternalLink(targetId, sName));
        append(row, mlreportgen.dom.TableEntry(linkPara));
        append(row, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph(roleSummary)));
        append(row, mlreportgen.dom.TableEntry(mlreportgen.dom.Paragraph(blockSummary)));
        append(navTable, row);
    end

    append(navSec, navTable);
    append(rpt, navSec);
    append(rpt, mlreportgen.dom.PageBreak);

    %% ---- Model Overview Chapter ----
    overviewSec = mlreportgen.report.Section;
    overviewSec.Title = "Model Overview";
    overviewSec.LinkTarget = 'section_model_overview_ai';

    % Use AI-generated overview text
    overviewPara = composeAIOverview(knowledgeBase);
    appendSectionDescription(overviewSec, overviewPara);
    appendDiagram(overviewSec, get_param(modelName, 'Handle'));
    append(rpt, overviewSec);

    %% ---- Subsystem Chapters (AI-Enhanced Descriptions) ----
    for i = 1:numel(subNames)
        sName = subNames{i};
        sInfo = knowledgeBase.subsystems.(sName);

        % Resolve full path
        sysPath = "";
        if isfield(sInfo, 'path')
            sysPath = sInfo.path;
        end

        sec = mlreportgen.report.Section;
        sec.Title = resolveEnhancedTitle(sName, sInfo);
        sec.LinkTarget = sectionTargetId(sName, 1, i);

        % ---- AI-generated rich description ----
        if isfield(sInfo, 'description') && strlength(string(sInfo.description)) > 0
            descText = string(sInfo.description);
            appendSectionDescription(sec, descText);
        else
            appendSectionDescription(sec, composeFallbackDescription(sName, sInfo));
        end

        % ---- Parameter table if available ----
        if isfield(sInfo, 'variableRefs') && ~isempty(sInfo.variableRefs)
            append(sec, mlreportgen.dom.Paragraph(' '));
            append(sec, mlreportgen.dom.Paragraph('Related calibration parameters:'));
            varList = sInfo.variableRefs;
            varStr = strjoin(varList, ', ');
            append(sec, mlreportgen.dom.Paragraph(varStr));
        end

        % ---- Child subsystem list ----
        if isfield(sInfo, 'childSubsystems') && ~isempty(sInfo.childSubsystems)
            append(sec, mlreportgen.dom.Paragraph(' '));
            childStr = strjoin(sInfo.childSubsystems, ', ');
            append(sec, mlreportgen.dom.Paragraph('Child components: ' + childStr));
        end

        % ---- Screenshot ----
        if strlength(sysPath) > 0 && bdIsLoaded(modelName)
            try
                appendDiagram(sec, get_param(sysPath, 'Handle'));
            catch
                % Diagram may not be available
            end
        end

        append(rpt, sec);
    end

    %% ---- Finalize ----
    close(rpt);
    fprintf('PDF report generated: %s\n', pdfFile);

    if usejava('desktop')
        try
            rptview(rpt);
        catch
            % Non-interactive mode
        end
    end
end

%% ================== Report Building Helpers ==================

function overviewText = composeAIOverview(knowledgeBase)
% Compose model overview from analysis results
    overviewText = strings(0, 1);
    modelName = knowledgeBase.modelName;

    % Opening statement
    overviewText(end+1) = sprintf('【%s 模型概述】', modelName);
    overviewText(end+1) = sprintf('本模型共包含 %d 个子系统模块，已深度分析 %d 个。', ...
        knowledgeBase.totalSubsystems, knowledgeBase.analyzedSubsystems);

    % Count block types across model
    allTypes = {};
    subNames = fieldnames(knowledgeBase.subsystems);
    for i = 1:numel(subNames)
        sInfo = knowledgeBase.subsystems.(subNames{i});
        if isfield(sInfo, 'blockTypeSummary')
            allTypes{end+1} = string(sInfo.blockTypeSummary); %#ok<AGROW>
        end
    end

    % Interface summary
    if isfield(knowledgeBase, 'interfaceInfo') && ~isempty(fieldnames(knowledgeBase.interfaceInfo))
        if isfield(knowledgeBase.interfaceInfo, 'Interface') && ...
           ~isempty(knowledgeBase.interfaceInfo.Interface)
            items = knowledgeBase.interfaceInfo.Interface.Items;
            if ~isempty(items) && ismember('Direction', string(items.Properties.VariableNames))
                inputCount = sum(startsWith(lower(strtrim(string(items.Direction))), 'input'));
                outputCount = sum(startsWith(lower(strtrim(string(items.Direction))), 'output'));
                calCount = 0;
                if isfield(knowledgeBase.interfaceInfo, 'Calibration') && ...
                   ~isempty(knowledgeBase.interfaceInfo.Calibration)
                    calCount = height(knowledgeBase.interfaceInfo.Calibration.Items);
                end
                overviewText(end+1) = sprintf('接口规模：%d 个输入信号，%d 个输出信号，%d 个标定参数。', ...
                    inputCount, outputCount, calCount);
            end
        end
    end

    % Subsystem roles summary
    overviewText(end+1) = '以下是各子系统的功能分布：';
    for i = 1:min(15, numel(subNames))  % Show first 15
        sName = subNames{i};
        sInfo = knowledgeBase.subsystems.(sName);
        descLines = split(string(sInfo.description), newline);
        if numel(descLines) >= 1
            roleLine = strtrim(descLines(1));
            if strlength(roleLine) > 80
                roleLine = extractBefore(roleLine, 80) + '...';
            end
            overviewText(end+1) = sprintf('  • %s: %s', sName, roleLine); %#ok<AGROW>
        end
    end
    if numel(subNames) > 15
        overviewText(end+1) = sprintf('  ...及其他 %d 个子系统（详情见各子系统章节）', numel(subNames) - 15);
    end

    overviewText = strjoin(overviewText, newline);
end

function titleText = resolveEnhancedTitle(sysName, sysInfo)
% Determine the best title for a subsystem section
    titleText = strtrim(string(sysName));

    % Get role from description for subtitle
    if isfield(sysInfo, 'description')
        descLines = split(string(sysInfo.description), newline);
        if numel(descLines) >= 1
            roleLine = strtrim(descLines(1));
            roleLine = regexprep(roleLine, '^【[^】]+】\s*', ''); % Remove 【xxx】 prefix
            roleLine = regexprep(roleLine, '[。\.].*$', ''); % Take only first sentence
            if strlength(roleLine) > 0 && strlength(roleLine) < 80
                titleText = titleText + " — " + roleLine;
            end
        end
    end
end

function descText = composeFallbackDescription(sysName, sysInfo)
% Generate fallback description when no AI analysis is available
    descText = strings(0, 1);
    descText(end+1) = sprintf('【%s】信号处理与功能传递模块。', sysName);

    if isfield(sysInfo, 'inputPorts') && ~isempty(sysInfo.inputPorts)
        portStr = strjoin(arrayfun(@(x) string(x), sysInfo.inputPorts, 'UniformOutput', false), '、');
        descText(end+1) = sprintf('输入：%s。', portStr); %#ok<AGROW>
    end
    if isfield(sysInfo, 'outputPorts') && ~isempty(sysInfo.outputPorts)
        portStr = strjoin(arrayfun(@(x) string(x), sysInfo.outputPorts, 'UniformOutput', false), '、');
        descText(end+1) = sprintf('输出：%s。', portStr); %#ok<AGROW>
    end
    descText = strjoin(descText, newline);
end

%% --- Report DOM Helpers (mirrored from DdGeneration_ASPICE.m) ---

function targetId = sectionTargetId(sysId, level, index)
    sanitized = regexprep(string(sysId), '[^A-Za-z0-9]', '_');
    targetId = char('section_ai_' + sanitized + '_' + string(level) + '_' + string(index));
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
        diag.SnapshotFormat = 'pdf';
        diag.Scaling = 'auto';
        diag.Width = '6.8in';
        diag.MaxWidth = '6.8in';
        diag.MaxHeight = '9.0in';
        append(sec, diag);
    catch diagramError
        append(sec, mlreportgen.dom.Paragraph('Diagram snapshot unavailable: ' + string(diagramError.message)));
    end
end

function loadReportDependencies(rootDir)
    dependencyFiles = strings(0, 1);
    envValue = string(getenv('SDD_DEPENDENCY_FILES'));
    if strlength(envValue) > 0
        parts = split(envValue, ';');
        for i = 1:numel(parts)
            candidate = strtrim(parts(i));
            if strlength(candidate) > 0 && isfile(candidate)
                dependencyFiles(end+1) = candidate; %#ok<AGROW>
            elseif strlength(candidate) > 0 && isfile(fullfile(rootDir, candidate))
                dependencyFiles(end+1) = fullfile(rootDir, candidate); %#ok<AGROW>
            end
        end
    end
    currentDir = pwd;
    cleanupDir = onCleanup(@() cd(currentDir));
    cd(rootDir);
    for i = 1:numel(dependencyFiles)
        [~, ~, ext] = fileparts(dependencyFiles(i));
        if strcmpi(ext, '.m')
            run(dependencyFiles(i));
        elseif strcmpi(ext, '.mat')
            load(dependencyFiles(i));
        end
    end
end

%% --- Table building helpers (mirrored from DdGeneration_ASPICE.m) ---

function section = buildInputSignalSection(interfaceData)
    section = mlreportgen.report.Section;
    section.Title = 'Input Signals';
    append(section, mlreportgen.dom.Paragraph('Source: worksheet "signal" of the selected Excel file.'));
    if ~isempty(fieldnames(interfaceData)) && ~isempty(interfaceData.Items)
        inputSignals = selectSignalRowsByDirection(interfaceData.Items, 'Input');
        append(section, tableToDom(selectSignalColumns(inputSignals)));
    end
end

function section = buildOutputSignalSection(interfaceData)
    section = mlreportgen.report.Section;
    section.Title = 'Output Signals';
    append(section, mlreportgen.dom.Paragraph('Source: worksheet "signal" of the selected Excel file.'));
    if ~isempty(fieldnames(interfaceData)) && ~isempty(interfaceData.Items)
        outputSignals = selectSignalRowsByDirection(interfaceData.Items, 'Output');
        append(section, tableToDom(selectSignalColumns(outputSignals)));
    end
end

function section = buildCalibrationSection(calibrationData)
    section = mlreportgen.report.Section;
    section.Title = 'Calibration';
    append(section, mlreportgen.dom.Paragraph('Source: worksheet "cal" of the selected Excel file.'));
    if ~isempty(calibrationData.Items)
        append(section, tableToDom(selectCalibrationColumns(calibrationData.Items)));
    end
end

function filtered = selectSignalColumns(dataTable)
    preferred = ["SignalName", "Direction", "Description", "DataType", "InitialValue", ...
                 "Factor", "Offset", "Min", "Max", "Unit", "Dimensions"];
    filtered = selectExistingColumns(dataTable, preferred);
    if ~any(strcmpi(filtered.Properties.VariableNames, 'Description'))
        filtered.Description = repmat(string(''), height(filtered), 1);
        if any(strcmpi(filtered.Properties.VariableNames, 'Direction'))
            filtered = movevars(filtered, 'Description', 'After', 'Direction');
        else
            filtered = movevars(filtered, 'Description', 'After', filtered.Properties.VariableNames{1});
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
        match = find(~used & (strcmpi(existing, preferred(i)) | ...
            startsWith(existing, preferred(i), 'IgnoreCase', true)), 1);
        if ~isempty(match)
            ordered(end+1) = existing(match); %#ok<AGROW>
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
    domTable.Width = '100%';
    domTable.Border = 'solid';
    domTable.ColSep = 'solid';
    domTable.RowSep = 'solid';
    domTable.TableEntriesInnerMargin = '4pt';

    headerRow = mlreportgen.dom.TableRow;
    for c = 1:width(dataTable)
        headerText = string(dataTable.Properties.VariableNames{c});
        headerText = replace(headerText, '_', ' ');
        append(headerRow, mlreportgen.dom.TableEntry(makeParagraph(headerText)));
    end
    append(domTable, headerRow);

    for r = 1:height(dataTable)
        row = mlreportgen.dom.TableRow;
        for c = 1:width(dataTable)
            value = dataTable{r, c};
            if ismissing(value) || (isstring(value) && strlength(value) == 0)
                textValue = '';
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
    if isempty(dataTable) || ~ismember('Direction', string(dataTable.Properties.VariableNames))
        filtered = dataTable;
        return;
    end
    directionText = lower(strtrim(string(dataTable.Direction)));
    keep = startsWith(directionText, lower(string(directionValue)));
    filtered = dataTable(keep, :);
end
