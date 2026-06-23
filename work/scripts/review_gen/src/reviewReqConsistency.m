function result = reviewReqConsistency(modelName, reqExcelPath, varargin)
% reviewReqConsistency  Review consistency between software requirements and model
%   Compares Excel-defined signals/calibrations against actual Simulink model
%   implementation, reporting missing/extra/mismatched items.
%
%   Inputs:
%       modelName    - Model name or path (.slx)
%       reqExcelPath - Excel workbook with requirement definitions
%       varargin     - 'OutputDir' - report output directory
%
%   Usage:
%       result = reviewReqConsistency('Model.slx', 'requirements.xlsx');

    fprintf('=== Requirements-Model Consistency Review ===\n\n');
    result = struct('passed', true, 'score', 100, 'findings', {}, ...
        'summary', '', 'reportFile', '');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'reqExcelPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputDir', '', @ischar);
    parse(p, modelName, reqExcelPath, varargin{:});

    modelName = char(p.Results.modelName);
    reqExcelPath = char(p.Results.reqExcelPath);

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; modelBase = modelName; end
    outputDir = p.Results.OutputDir;
    if isempty(outputDir), outputDir = fullfile(modelDir, '_reviews'); end
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    %% Step 1: Read requirements from Excel
    fprintf('[1/4] Reading requirements from Excel: %s\n', reqExcelPath);
    reqSignals = readReqSignals(reqExcelPath);
    reqCals = readReqCalibrations(reqExcelPath);
    fprintf('      Requirements: %d signals, %d calibrations\n', ...
        numel(reqSignals), numel(reqCals));

    %% Step 2: Scan model
    fprintf('[2/4] Scanning model implementation...\n');
    load_system(modelName);

    % Get all ports recursively
    inports = find_system(modelBase, 'LookUnderMasks', 'all', 'BlockType', 'Inport');
    outports = find_system(modelBase, 'LookUnderMasks', 'all', 'BlockType', 'Outport');

    modelSignals = {};
    for i = 1:numel(inports)
        if strcmp(inports{i}, modelBase), continue; end
        try
            modelSignals{end+1} = struct( ...
                'name', get_param(inports{i}, 'Name'), ...
                'direction', 'Input', ...
                'dataType', get_param(inports{i}, 'OutDataTypeStr'), ...
                'path', inports{i}); %#ok<AGROW>
        catch, end
    end
    for i = 1:numel(outports)
        if strcmp(outports{i}, modelBase), continue; end
        try
            modelSignals{end+1} = struct( ...
                'name', get_param(outports{i}, 'Name'), ...
                'direction', 'Output', ...
                'dataType', get_param(outports{i}, 'OutDataTypeStr'), ...
                'path', outports{i}); %#ok<AGROW>
        catch, end
    end

    % Get calibration blocks (Constant/Gain with cal_ Value)
    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
    modelCals = {};
    seenCalNames = containers.Map();
    for i = 1:numel(allBlocks)
        if strcmp(allBlocks{i}, modelBase), continue; end
        try
            bt = get_param(allBlocks{i}, 'BlockType');
            if ~strcmp(bt, 'Constant') && ~strcmp(bt, 'Gain'), continue; end
            switch bt
                case 'Constant', val = strtrim(get_param(allBlocks{i}, 'Value'));
                case 'Gain', val = strtrim(get_param(allBlocks{i}, 'Gain'));
            end
            if ~startsWith(lower(val), 'cal_'), continue; end
            if ~isKey(seenCalNames, val)
                seenCalNames(val) = true;
                modelCals{end+1} = struct('name', val, 'blockType', bt); %#ok<AGROW>
            end
        catch, end
    end
    fprintf('      Model: %d signals, %d calibrations\n', numel(modelSignals), numel(modelCals));

    %% Step 3: Compare - Signals
    fprintf('[3/4] Comparing signals...\n');
    findings = {};
    score = 100;

    % Compare signal names (case-insensitive)
    reqSigNames = lower(arrayfun(@(x) x.name, reqSignals, 'UniformOutput', false));
    modelSigNames = lower(arrayfun(@(x) x.name, modelSignals, 'UniformOutput', false));

    % Signals in requirements but not in model
    for i = 1:numel(reqSignals)
        if ~any(strcmp(reqSigNames{i}, modelSigNames))
            findings{end+1} = struct( ...
                'category', 'signal_missing', 'severity', 'error', ...
                'item', reqSignals(i).name, ...
                'detail', sprintf('需求中定义了信号 "%s" (%s)，但模型中未找到', ...
                    reqSignals(i).name, reqSignals(i).direction)); %#ok<AGROW>
            score = score - 10;
        end
    end

    % Signals in model but not in requirements
    for i = 1:numel(modelSignals)
        if ~any(strcmp(modelSigNames{i}, reqSigNames))
            findings{end+1} = struct( ...
                'category', 'signal_extra', 'severity', 'warning', ...
                'item', modelSignals{i}.name, ...
                'detail', sprintf('模型中存在信号 "%s"，但需求中未定义', ...
                    modelSignals{i}.name)); %#ok<AGROW>
            score = score - 3;
        end
    end

    % Data type mismatches
    for i = 1:numel(reqSignals)
        for j = 1:numel(modelSignals)
            if strcmpi(reqSignals(i).name, modelSignals{j}.name)
                reqDt = lower(strtrim(reqSignals(i).dataType));
                modelDt = lower(strtrim(modelSignals{j}.dataType));
                if ~isempty(reqDt) && ~strcmp(reqDt, 'inherit: auto') && ...
                   ~isempty(modelDt) && ~strcmp(modelDt, 'inherit: auto') && ...
                   ~strcmp(reqDt, modelDt)
                    findings{end+1} = struct( ...
                        'category', 'datatype_mismatch', 'severity', 'major', ...
                        'item', reqSignals(i).name, ...
                        'detail', sprintf('信号 "%s" 数据类型不匹配: 需求=%s, 模型=%s', ...
                            reqSignals(i).name, reqDt, modelDt)); %#ok<AGROW>
                    score = score - 5;
                end
                break;
            end
        end
    end

    % Compare calibrations
    reqCalNames = lower(arrayfun(@(x) x.name, reqCals, 'UniformOutput', false));
    modelCalNames = lower(arrayfun(@(x) x.name, modelCals, 'UniformOutput', false));

    for i = 1:numel(reqCals)
        if ~any(strcmp(reqCalNames{i}, modelCalNames))
            findings{end+1} = struct( ...
                'category', 'cal_missing', 'severity', 'major', ...
                'item', reqCals(i).name, ...
                'detail', sprintf('需求中定义了标定 "%s"，但模型中未使用', ...
                    reqCals(i).name)); %#ok<AGROW>
            score = score - 8;
        end
    end

    for i = 1:numel(modelCals)
        if ~any(strcmp(modelCalNames{i}, reqCalNames))
            findings{end+1} = struct( ...
                'category', 'cal_extra', 'severity', 'warning', ...
                'item', modelCals{i}.name, ...
                'detail', sprintf('模型中使用标定 "%s"，但需求中未定义', ...
                    modelCals{i}.name)); %#ok<AGROW>
            score = score - 2;
        end
    end

    result.findings = findings;
    result.score = max(0, min(100, score));

    %% Step 4: Generate report
    fprintf('[4/4] Generating report...\n');
    result.reportFile = generateConsistencyReport(result, outputDir, modelBase, reqExcelPath);

    %% Summary
    nErr = sum(arrayfun(@(x) strcmp(x.severity,'error'), findings));
    nMaj = sum(arrayfun(@(x) strcmp(x.severity,'major'), findings));
    nWarn = sum(arrayfun(@(x) strcmp(x.severity,'warning'), findings));
    result.passed = nErr == 0;
    result.summary = sprintf('Score: %d/100 | %d error(s), %d major, %d warning(s)', ...
        result.score, nErr, nMaj, nWarn);

    fprintf('\n=== Review Complete ===\n');
    fprintf('Score: %d/100\n', result.score);
    fprintf('Errors:  %d (missing requirements)\n', nErr);
    fprintf('Major:   %d (type mismatches, missing cal)\n', nMaj);
    fprintf('Warning: %d (extra items)\n', nWarn);
    fprintf('Report: %s\n', result.reportFile);
end

%% ================== Excel Reading ==================

function signals = readReqSignals(excelPath)
    signals = struct('name', {}, 'direction', {}, 'dataType', {});
    try
        sheets = sheetnames(excelPath);
    catch, return; end

    % Find signal sheet
    sigSheet = '';
    for i = 1:numel(sheets)
        if contains(lower(sheets{i}), 'signal')
            sigSheet = sheets{i}; break;
        end
    end
    if isempty(sigSheet), return; end

    try
        raw = readcell(excelPath, 'Sheet', sigSheet);
        if size(raw, 1) < 2, return; end
        headers = lower(string(raw(1, :)));
        for r = 2:size(raw, 1)
            row = raw(r, :);
            name = ''; dir = ''; dt = '';
            for c = 1:numel(headers)
                if c > numel(row), continue; end
                if ismissing(row{c}) || isempty(row{c}), continue; end
                val = strtrim(string(row{c}));
                if strlength(val) == 0, continue; end
                if contains(headers{c}, 'name') || contains(headers{c}, 'port')
                    name = val;
                elseif contains(headers{c}, 'dir') || contains(headers{c}, 'type') && ~contains(headers{c}, 'data')
                    dir = val;
                elseif contains(headers{c}, 'data') || contains(headers{c}, 'type') && contains(headers{c}, 'data')
                    dt = val;
                end
            end
            if strlength(name) > 0
                signals(end+1) = struct('name', char(name), 'direction', char(dir), 'dataType', char(dt)); %#ok<AGROW>
            end
        end
    catch, end
end

function cals = readReqCalibrations(excelPath)
    cals = struct('name', {}, 'dataType', {});
    try
        sheets = sheetnames(excelPath);
    catch, return; end

    calSheet = '';
    for i = 1:numel(sheets)
        if contains(lower(sheets{i}), 'cal')
            calSheet = sheets{i}; break;
        end
    end
    if isempty(calSheet), return; end

    try
        raw = readcell(excelPath, 'Sheet', calSheet);
        if size(raw, 1) < 2, return; end
        headers = lower(string(raw(1, :)));
        for r = 2:size(raw, 1)
            row = raw(r, :);
            name = ''; dt = '';
            for c = 1:numel(headers)
                if c > numel(row), continue; end
                if ismissing(row{c}) || isempty(row{c}), continue; end
                val = strtrim(string(row{c}));
                if strlength(val) == 0, continue; end
                if contains(headers{c}, 'name')
                    name = val;
                elseif contains(headers{c}, 'data') || contains(headers{c}, 'type')
                    dt = val;
                end
            end
            if strlength(name) > 0
                cals(end+1) = struct('name', char(name), 'dataType', char(dt)); %#ok<AGROW>
            end
        end
    catch, end
end

%% ================== HTML Report ==================

function reportFile = generateConsistencyReport(result, outputDir, modelName, excelPath)
    reportFile = fullfile(outputDir, [modelName '_req_consistency.html']);
    fid = fopen(reportFile, 'w');

    nErr = sum(arrayfun(@(x) strcmp(x.severity,'error'), result.findings));
    nMaj = sum(arrayfun(@(x) strcmp(x.severity,'major'), result.findings));
    nWarn = sum(arrayfun(@(x) strcmp(x.severity,'warning'), result.findings));

    gradeColor = 'green';
    if result.score < 60, gradeColor = 'red';
    elseif result.score < 80, gradeColor = 'orange'; end

    fprintf(fid, '<!DOCTYPE html><html><head><meta charset="UTF-8">\n');
    fprintf(fid, '<title>Requirements-Model Consistency - %s</title>\n', modelName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:-apple-system,sans-serif;margin:40px;background:#fafafa}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:3px solid %s;padding-bottom:10px}\n', gradeColor);
    fprintf(fid, '.error{background:#ffebee;border-left:4px solid #f44336;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.major{background:#fff3e0;border-left:4px solid #FF9800;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.warning{background:#e8f5e9;border-left:4px solid #FF9800;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.card{background:white;border-radius:8px;padding:20px;margin:20px 0;box-shadow:0 2px 4px rgba(0,0,0,0.1)}\n');
    fprintf(fid, 'table{width:100%%;border-collapse:collapse;margin:10px 0}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:10px;text-align:left}\n');
    fprintf(fid, 'th{background:#37474F;color:white}\n');
    fprintf(fid, '.score{font-size:48px;font-weight:bold;text-align:center;color:%s}\n', gradeColor);
    fprintf(fid, '</style></head><body>\n');

    fprintf(fid, '<h1>%s 需求-模型一致性 Review</h1>\n', modelName);
    fprintf(fid, '<p>需求来源: %s</p>\n', excelPath);

    fprintf(fid, '<div class="card">\n');
    fprintf(fid, '<div class="score">%d / 100</div>\n', result.score);
    fprintf(fid, '<table><tr><th>类型</th><th>数量</th></tr>\n');
    fprintf(fid, '<tr style="background:#ffebee"><td>❌ 需求定义但模型缺失 (Error)</td><td>%d</td></tr>\n', nErr);
    fprintf(fid, '<tr style="background:#fff3e0"><td>🟠 不匹配 (Major)</td><td>%d</td></tr>\n', nMaj);
    fprintf(fid, '<tr style="background:#e8f5e9"><td>🟡 模型多余 (Warning)</td><td>%d</td></tr>\n', nWarn);
    fprintf(fid, '</table>\n');
    fprintf(fid, '</div>\n');

    if ~isempty(result.findings)
        fprintf(fid, '<div class="card"><h2>详细问题列表</h2>\n');
        for i = 1:numel(result.findings)
            f = result.findings{i};
            fprintf(fid, '<div class="%s">\n', f.severity);
            fprintf(fid, '<strong>[%s]</strong> %s<br>\n', f.category, f.item);
            fprintf(fid, '<span style="color:#666">%s</span>\n', f.detail);
            fprintf(fid, '</div>\n');
        end
        fprintf(fid, '</div>\n');
    end

    fprintf(fid, '<div class="card"><h2>总结</h2><p>%s</p></div>\n', result.summary);
    fprintf(fid, '</body></html>\n');
    fclose(fid);
end
