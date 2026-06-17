function result = generateTraceMatrix(modelName, excelPath, varargin)
% generateTraceMatrix  Generate Requirement Traceability Matrix for Simulink model
%   Traces Excel signals and calibrations to Simulink model blocks, producing
%   an HTML traceability matrix showing which requirements are covered.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       excelPath  - Excel workbook with interface/calibration definitions
%       varargin   - 'OutputDir' - report directory (default: model dir)
%
%   Usage:
%       result = generateTraceMatrix('Model.slx', 'workbook.xlsx');

    fprintf('=== Requirement Traceability Matrix ===\n\n');
    result = struct('traces', {}, 'orphans', {}, 'reportFile', '');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'excelPath', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputDir', '', @ischar);
    parse(p, modelName, excelPath, varargin{:});

    modelName = char(p.Results.modelName);
    excelPath = char(p.Results.excelPath);

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; modelBase = modelName; end
    outputDir = p.Results.OutputDir;
    if isempty(outputDir), outputDir = modelDir; end

    %% Step 1: Read Excel requirements
    fprintf('[1/4] Reading Excel requirements: %s\n', excelPath);
    try
        sheets = sheetnames(excelPath);
    catch
        error('Cannot read Excel: %s', excelPath);
    end

    signalSheet = findSheetByName(sheets, 'signal');
    calSheet = findSheetByName(sheets, 'cal');

    reqs = {};
    if ~isempty(signalSheet)
        raw = readcell(excelPath, 'Sheet', signalSheet);
        if size(raw, 1) >= 2
            for r = 2:size(raw, 1)
                row = raw(r, :);
                if numel(row) >= 1 && ~ismissing(row{1})
                    reqs{end+1} = struct( ...
                        'source', 'Excel:signal', ...
                        'id', sprintf('SIG_%d', r-1), ...
                        'name', string(row{1}), ...
                        'type', 'signal'); %#ok<AGROW>
                end
            end
        end
    end
    if ~isempty(calSheet)
        raw = readcell(excelPath, 'Sheet', calSheet);
        if size(raw, 1) >= 2
            for r = 2:size(raw, 1)
                row = raw(r, :);
                if numel(row) >= 1 && ~ismissing(row{1})
                    reqs{end+1} = struct( ...
                        'source', 'Excel:cal', ...
                        'id', sprintf('CAL_%d', r-1), ...
                        'name', string(row{1}), ...
                        'type', 'calibration'); %#ok<AGROW>
                end
            end
        end
    end
    fprintf('      %d requirements from Excel\n', numel(reqs));

    %% Step 2: Scan model for matches
    fprintf('[2/4] Scanning model for traceable blocks...\n');
    load_system(modelBase);
    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'Type', 'Block');

    traces = {};
    orphans = {};

    for r = 1:numel(reqs)
        req = reqs{r};
        reqLower = lower(req.name);
        found = false;

        for b = 1:numel(allBlocks)
            blk = allBlocks{b};
            try
                blkName = lower(get_param(blk, 'Name'));
                blkType = get_param(blk, 'BlockType');

                % Check if block name contains or matches requirement name
                if contains(blkName, reqLower) || contains(reqLower, blkName)
                    traces{end+1} = struct( ...
                        'reqId', req.id, ...
                        'reqName', req.name, ...
                        'reqType', req.type, ...
                        'reqSource', req.source, ...
                        'blockPath', blk, ...
                        'blockType', blkType, ...
                        'matchMethod', 'name_match'); %#ok<AGROW>
                    found = true;
                end
            catch
                % Skip blocks that error
            end
        end

        if ~found
            orphans{end+1} = req; %#ok<AGROW>
        end
    end

    result.traces = traces;
    result.orphans = orphans;

    %% Step 3: Generate traceability matrix
    fprintf('[3/4] Generating traceability matrix...\n');
    result.reportFile = generateTraceReport(result, outputDir, modelBase, excelPath);

    %% Step 4: Summary by subsystem
    fprintf('[4/4] Aggregating by subsystem...\n');
    subSystems = find_system(modelBase, 'LookUnderMasks', 'all', 'BlockType', 'SubSystem');
    subTraces = struct();
    for i = 1:numel(subSystems)
        sysPath = subSystems{i};
        sysName = get_param(sysPath, 'Name');
        count = 0;
        for t = 1:numel(traces)
            if contains(traces{t}.blockPath, sysPath)
                count = count + 1;
            end
        end
        if count > 0
            subTraces.(matlab.lang.makeValidName(sysName)) = count;
        end
    end
    result.bySubsystem = subTraces;

    %% Summary
    fprintf('\n=== Trace Matrix Complete ===\n');
    fprintf('Requirements: %d\n', numel(reqs));
    fprintf('Traced:       %d\n', numel(traces));
    fprintf('Orphans:      %d\n', numel(orphans));
    fprintf('Coverage:     %.1f%%\n', ...
        (numel(traces) / max(numel(reqs), 1)) * 100);
    if ~isempty(orphans)
        fprintf('\nUntraced requirements:\n');
        for i = 1:min(5, numel(orphans))
            fprintf('  ⚠ %s (%s)\n', orphans{i}.name, orphans{i}.source);
        end
        if numel(orphans) > 5
            fprintf('  ... and %d more\n', numel(orphans) - 5);
        end
    end
    fprintf('Report: %s\n', result.reportFile);
end

function reportFile = generateTraceReport(result, outputDir, modelName, excelPath)
    reportFile = fullfile(outputDir, [modelName '_trace_matrix.html']);
    fid = fopen(reportFile, 'w');

    fprintf(fid, '<!DOCTYPE html>\n<html><head>
<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Trace Matrix - %s</title>\n', modelName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:40px}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #4CAF50;padding-bottom:10px}\n');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:20px 0;font-size:13px}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:8px 12px;text-align:left}\n');
    fprintf(fid, 'th{background:#4CAF50;color:white}\n');
    fprintf(fid, 'tr:nth-child(even){background:#f8f8f8}\n');
    fprintf(fid, '.orphan{background:#ffebee}.traced{background:#e8f5e9}\n');
    fprintf(fid, '.summary{background:#e8f5e9;padding:20px;border-radius:5px;margin:20px 0}\n');
    fprintf(fid, '.badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px}\n');
    fprintf(fid, '.badge-signal{background:#e3f2fd;color:#1565C0}\n');
    fprintf(fid, '.badge-cal{background:#fff3e0;color:#E65100}\n');
    fprintf(fid, '</style></head><body>\n');

    total = numel(result.traces) + numel(result.orphans);
    coverage = total > 0 ? round(numel(result.traces)/total*100) : 0;

    fprintf(fid, '<h1>Requirement Traceability Matrix</h1>\n');
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Model:</strong> %s</p>\n', modelName);
    fprintf(fid, '<p><strong>Source:</strong> %s</p>\n', excelPath);
    fprintf(fid, '<p><strong>Total Requirements:</strong> %d</p>\n', total);
    fprintf(fid, '<p><strong>Traced:</strong> %d (%d%%)</p>\n', numel(result.traces), coverage);
    fprintf(fid, '<p><strong>Untraced:</strong> %d</p>\n', numel(result.orphans));
    fprintf(fid, '</div>\n');

    % Trace table
    if ~isempty(result.traces)
        fprintf(fid, '<h2>Traced Requirements</h2>\n');
        fprintf(fid, '<table><tr><th>Req ID</th><th>Req Name</th><th>Type</th><th>Block Path</th><th>Block Type</th></tr>\n');
        for i = 1:numel(result.traces)
            t = result.traces{i};
            badge = ternary(strcmp(t.reqType, 'signal'), ...
                '<span class="badge badge-signal">Signal</span>', ...
                '<span class="badge badge-cal">Calibration</span>');
            fprintf(fid, '<tr class="traced"><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>\n', ...
                t.reqId, t.reqName, badge, t.blockPath, t.blockType);
        end
        fprintf(fid, '</table>\n');
    end

    % Orphan table
    if ~isempty(result.orphans)
        fprintf(fid, '<h2>Untraced Requirements (Orphans)</h2>\n');
        fprintf(fid, '<table><tr><th>Req ID</th><th>Req Name</th><th>Type</th><th>Source</th></tr>\n');
        for i = 1:numel(result.orphans)
            o = result.orphans{i};
            badge = ternary(strcmp(o.type, 'signal'), ...
                '<span class="badge badge-signal">Signal</span>', ...
                '<span class="badge badge-cal">Calibration</span>');
            fprintf(fid, '<tr class="orphan"><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
                o.id, o.name, badge, o.source);
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
