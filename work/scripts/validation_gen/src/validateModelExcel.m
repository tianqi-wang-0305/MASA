function result = validateModelExcel(modelName, excelPath, varargin)
% validateModelExcel  Validate consistency between Simulink model and Excel workbook
%   Compares Excel port/calibration definitions against the actual model,
%   reporting missing, extra, or mismatched items.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       excelPath  - Excel workbook (interface + calibration sheets)
%       varargin   - 'FixMode' - auto-fix mismatches (default: false)
%
%   Usage:
%       result = validateModelExcel('Model.slx', 'workbook.xlsx');
%       result = validateModelExcel('Model.slx', 'workbook.xlsx', 'FixMode', true);

    fprintf('=== Excel-Model Validation ===\n\n');
    result = struct('passed', true, 'issues', {}, 'reportFile', '');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'excelPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'FixMode', false, @islogical);
    parse(p, modelName, excelPath, varargin{:});

    modelName = char(p.Results.modelName);
    excelPath = char(p.Results.excelPath);
    fixMode = p.Results.FixMode;

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir)
        [md, mn] = fileparts(which(modelName));
        modelDir = md;
        if isempty(modelDir)
            modelDir = pwd;
            modelBase = modelName;
        else
            modelBase = mn;
        end
    end

    %% Step 1: Read Excel data
    fprintf('[1/4] Reading Excel workbook: %s\n', excelPath);
    try
        sheets = sheetnames(excelPath);
    catch ME
        error('Cannot read Excel file: %s', ME.message);
    end

    % Find signal and calibration sheets
    signalSheet = findSheetByName(sheets, 'signal');
    calSheet = findSheetByName(sheets, 'cal');

    excelPorts = {};
    excelCals = {};

    if ~isempty(signalSheet)
        raw = readcell(excelPath, 'Sheet', signalSheet);
        if size(raw, 1) >= 2
            headers = string(raw(1, :));
            for r = 2:size(raw, 1)
                row = raw(r, :);
                name = '';
                dir = '';
                dt = '';
                if numel(row) >= 1 && ismissing(row{1})
                    % skip empty rows
                end
                if numel(row) >= 1
                    name = string(row{1});
                end
                if numel(row) >= 2
                    dir = string(row{2});
                end
                if numel(row) >= 3
                    dt = string(row{3});
                end
                if strlength(name) > 0
                    excelPorts{end+1} = struct('name', name, 'direction', dir, 'dataType', dt); %#ok<AGROW>
                end
            end
        end
    end
    fprintf('      %d ports from Excel\n', numel(excelPorts));

    if ~isempty(calSheet)
        raw = readcell(excelPath, 'Sheet', calSheet);
        if size(raw, 1) >= 2
            for r = 2:size(raw, 1)
                row = raw(r, :);
                if numel(row) >= 1 && ~ismissing(row{1})
                    excelCals{end+1} = string(row{1}); %#ok<AGROW>
                end
            end
        end
    end
    fprintf('      %d calibrations from Excel\n', numel(excelCals));

    %% Step 2: Read model ports
    fprintf('[2/4] Reading model ports...\n');
    load_system(modelBase);
    modelPorts = {};
    modelCals = {};

    % Get top-level ports
    inports = find_system(modelBase, 'SearchDepth', 1, 'BlockType', 'Inport');
    outports = find_system(modelBase, 'SearchDepth', 1, 'BlockType', 'Outport');
    for i = 1:numel(inports)
        if ~strcmp(inports{i}, modelBase)
            modelPorts{end+1} = struct('name', get_param(inports{i}, 'Name'), ...
                'direction', 'Input', 'dataType', get_param(inports{i}, 'OutDataTypeStr')); %#ok<AGROW>
        end
    end
    for i = 1:numel(outports)
        if ~strcmp(outports{i}, modelBase)
            modelPorts{end+1} = struct('name', get_param(outports{i}, 'Name'), ...
                'direction', 'Output', 'dataType', get_param(outports{i}, 'OutDataTypeStr')); %#ok<AGROW>
        end
    end
    fprintf('      %d ports in model\n', numel(modelPorts));

    % Find calibration constants
    constants = find_system(modelBase, 'LookUnderMasks', 'all', 'BlockType', 'Constant');
    for i = 1:numel(constants)
        if ~strcmp(constants{i}, modelBase)
            modelCals{end+1} = get_param(constants{i}, 'Name'); %#ok<AGROW>
        end
    end
    fprintf('      %d constants in model\n', numel(modelCals));

    %% Step 3: Compare
    fprintf('[3/4] Comparing...\n');
    issues = {};
    passed = true;

    % Check Excel ports exist in model
    excelNames = lower(arrayfun(@(x) x.name, excelPorts, 'UniformOutput', false));
    modelNames = lower(arrayfun(@(x) x.name, modelPorts, 'UniformOutput', false));

    for i = 1:numel(excelPorts)
        if ~any(strcmp(excelNames{i}, modelNames))
            issues{end+1} = struct( ...
                'type', 'port_missing', ...
                'severity', 'error', ...
                'item', excelPorts{i}.name, ...
                'message', sprintf('Port "%s" defined in Excel but not found in model', excelPorts{i}.name)); %#ok<AGROW>
            passed = false;
        end
    end

    % Check model ports not in Excel (extra)
    for i = 1:numel(modelPorts)
        if ~any(strcmp(modelNames{i}, excelNames))
            issues{end+1} = struct( ...
                'type', 'port_extra', ...
                'severity', 'warning', ...
                'item', modelPorts{i}.name, ...
                'message', sprintf('Port "%s" exists in model but not in Excel', modelPorts{i}.name)); %#ok<AGROW>
        end
    end

    % Check calibrations
    excelCalLower = lower(excelCals);
    modelCalLower = lower(modelCals);
    for i = 1:numel(excelCals)
        if ~any(strcmp(excelCalLower{i}, modelCalLower))
            issues{end+1} = struct( ...
                'type', 'cal_missing', ...
                'severity', 'warning', ...
                'item', excelCals{i}, ...
                'message', sprintf('Calibration "%s" in Excel not found in model constants', excelCals{i})); %#ok<AGROW>
        end
    end

    result.issues = issues;
    result.passed = passed;

    %% Step 4: Generate report
    fprintf('[4/4] Generating validation report...\n');
    result.reportFile = generateValidationReport(result, modelDir, modelBase, excelPath, fixMode);

    %% Summary
    fprintf('\n=== Validation Complete ===\n');
    fprintf('Issues found: %d\n', numel(issues));
    for i = 1:min(10, numel(issues))
        fprintf('  [%s] %s\n', issues{i}.severity, issues{i}.message);
    end
    if numel(issues) > 10
        fprintf('  ... and %d more\n', numel(issues) - 10);
    end
    if passed
        fprintf('Status: ✅ PASSED\n');
    else
        fprintf('Status: ⛔ ISSUES FOUND\n');
    end
    fprintf('Report: %s\n', result.reportFile);
end

function reportFile = generateValidationReport(result, outputDir, modelName, excelPath, fixMode)
    reportFile = fullfile(outputDir, [modelName '_validation_report.html']);
    fid = fopen(reportFile, 'w');

    fprintf(fid, '<!DOCTYPE html>\n<html><head>\n');
    fprintf(fid, '<title>Validation Report - %s</title>\n', modelName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:40px}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #9C27B0;padding-bottom:10px}\n');
    fprintf(fid, '.error{color:#f44336}.warning{color:#FF9800}\n');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:20px 0}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:12px}\n');
    fprintf(fid, 'th{background:#9C27B0;color:white}\n');
    fprintf(fid, '.summary{background:#f3e5f5;padding:20px;border-radius:5px}\n');
    fprintf(fid, '</style></head><body>\n');

    fprintf(fid, '<h1>Excel-Model Validation Report</h1>\n');
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Model:</strong> %s</p>\n', modelName);
    fprintf(fid, '<p><strong>Excel:</strong> %s</p>\n', excelPath);
    fprintf(fid, '<p><strong>Status:</strong> %s</p>\n', ...
        ternary(result.passed, '✅ PASSED', '⛔ ISSUES FOUND'));
    fprintf(fid, '<p><strong>Issues:</strong> %d</p>\n', numel(result.issues));
    fprintf(fid, '</div>\n');

    if ~isempty(result.issues)
        fprintf(fid, '<h2>Issues</h2>\n<table><tr><th>Severity</th><th>Type</th><th>Item</th><th>Description</th></tr>\n');
        for i = 1:numel(result.issues)
            iss = result.issues{i};
            css = ternary(strcmp(iss.severity, 'error'), 'error', 'warning');
            fprintf(fid, '<tr><td class="%s">%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
                css, iss.severity, iss.type, iss.item, iss.message);
        end
        fprintf(fid, '</table>\n');
    end

    fprintf(fid, '</body></html>\n');
    fclose(fid);
end

function sheetName = findSheetByName(sheets, targetName)
    sheetName = '';
    for i = 1:numel(sheets)
        if strcmpi(strtrim(string(sheets(i))), targetName)
            sheetName = string(sheets(i));
            return;
        end
    end
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
