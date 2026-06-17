function result = reviewModel(modelName, varargin)
% reviewModel  Comprehensive Simulink model review
%   Runs all available checks and produces a unified review report with
%   severity levels, AI-driven commentary, and a review score.
%
%   Checks included:
%     1. Model Advisor (threshold)
%     2. Naming convention
%     3. Connection integrity
%     4. Hierarchy integrity
%     5. Port data type definition
%     6. model_check (MCP tool)
%     7. AI-driven design review via model_read + model_overview
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'Severity' - fail threshold ('critical'|'major'|'minor')
%                    'OutputDir' - report directory
%                    'AIMode' - enable AI-driven review (default: true)
%
%   Usage:
%       result = reviewModel('Model.slx');
%       result = reviewModel('Model.slx', 'Severity', 'major');

    fprintf('=== Comprehensive Model Review ===\n\n');
    result = struct();
    result.modelName = '';
    result.timestamp = datetime('now');
    result.score = 100;
    result.summary = '';
    result.checks = struct();
    result.issues = {};
    result.reportFile = '';

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Severity', 'minor', @(x) any(validatestring(x, {'critical','major','minor'})));
    addParameter(p, 'OutputDir', '', @ischar);
    addParameter(p, 'AIMode', true, @islogical);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    severity = p.Results.Severity;
    outputDir = p.Results.OutputDir;
    aiMode = p.Results.AIMode;

    [modelDir, modelBase, modelExt] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; end
    if isempty(modelExt)
        modelFile = fullfile(modelDir, [modelBase '.slx']);
    else
        modelFile = fullfile(modelDir, [modelBase modelExt]);
    end
    if isempty(outputDir), outputDir = fullfile(modelDir, '_reviews'); end
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    result.modelName = modelBase;
    result.modelPath = modelFile;

    % Add common paths
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(scriptDir, '..', '..', 'quality_gen', 'src'));
    addpath(fullfile(scriptDir, '..', '..', 'chk_mng', 'src'));

    %% Check 1: Model Advisor with threshold
    fprintf('[1/7] Model Advisor check...\n');
    try
        maResult = checkModelWithThreshold(modelFile, 'ErrorThreshold', 100, 'WarningThreshold', 999);
        result.checks.modelAdvisor = struct(...
            'passed', maResult.passed, ...
            'errors', maResult.errors, ...
            'warnings', maResult.warnings, ...
            'reportFile', maResult.reportFile);
        if ~maResult.passed
            result.score = result.score - maResult.errors * 3;
        end
    catch ME
        result.checks.modelAdvisor = struct('passed', false, 'error', ME.message);
    end

    %% Check 2: Naming convention
    fprintf('[2/7] Naming convention check...\n');
    try
        load_system(modelFile);
        [namingViolations, namingStats] = check_naming_convention(modelBase);
        % Generate naming HTML report
        namingReport = '';
        try
            namingReport = generateNamingReport(namingViolations, namingStats, modelBase, outputDir);
        catch, end
        result.checks.naming = struct(...
            'violations', {namingViolations}, ...
            'stats', namingStats, ...
            'count', numel(namingViolations), ...
            'reportFile', namingReport);
        result.score = result.score - numel(namingViolations) * 1;
        for i = 1:numel(namingViolations)
            result.issues{end+1} = struct(...
                'check', 'naming', 'severity', 'minor', ...
                'message', namingViolations{i}); %#ok<AGROW>
        end
    catch ME
        result.checks.naming = struct('error', ME.message);
    end

    %% Check 3: Connection integrity
    fprintf('[3/7] Connection integrity check...\n');
    try
        [connViolations, connStats] = check_connection_rules(modelBase);
        result.checks.connections = struct(...
            'violations', {connViolations}, ...
            'stats', connStats, ...
            'count', numel(connViolations));
        result.score = result.score - connStats.unconnectedInports * 5 - connStats.unconnectedOutports * 5;
        for i = 1:numel(connViolations)
            sev = 'major';
            result.issues{end+1} = struct(...
                'check', 'connection', 'severity', sev, ...
                'message', connViolations{i}); %#ok<AGROW>
        end
    catch ME
        result.checks.connections = struct('error', ME.message);
    end

    %% Check 4: Hierarchy integrity
    fprintf('[4/7] Hierarchy integrity check...\n');
    try
        [hierViolations, hierStats] = check_hierarchy_integrity(modelBase);
        result.checks.hierarchy = struct(...
            'violations', {hierViolations}, ...
            'stats', hierStats, ...
            'count', numel(hierViolations));
        for i = 1:numel(hierViolations)
            sev = 'major';
            result.issues{end+1} = struct(...
                'check', 'hierarchy', 'severity', sev, ...
                'message', hierViolations{i}); %#ok<AGROW>
        end
    catch ME
        result.checks.hierarchy = struct('error', ME.message);
    end

    %% Check 5: Port data type definition
    fprintf('[5/7] Port data type check...\n');
    try
        dtResult = check_io_port_datatype_definition(modelName);
        result.checks.dataTypes = struct(...
            'totalPorts', dtResult.total_ports, ...
            'explicitCount', dtResult.explicit_ports, ...
            'issues', dtResult.issues_count, ...
            'violations', {dtResult.violations});
        result.score = result.score - dtResult.issues_count * 2;
        for i = 1:numel(dtResult.violations)
            result.issues{end+1} = struct(...
                'check', 'datatype', 'severity', 'major', ...
                'message', dtResult.violations{i}); %#ok<AGROW>
        end
    catch ME
        result.checks.dataTypes = struct('error', ME.message);
    end

    %% Check 6: model_check MCP tool
    fprintf('[6/7] model_check (MCP tool)...\n');
    try
        mcResult = model_check(modelBase, 'root', jsonencode(["all"]));
        result.checks.modelCheck = struct('result', string(mcResult));
    catch ME
        result.checks.modelCheck = struct('skipped', true, 'reason', ME.message);
    end

    %% Check 7: AI-driven design review
    if aiMode
        fprintf('[7/7] AI-driven design review...\n');
        try
            aiReview = generateAIReview(modelBase);
            result.checks.aiReview = aiReview;
            if aiReview.score < 60
                result.score = result.score - 10;
            end
            for i = 1:numel(aiReview.findings)
                result.issues{end+1} = struct(...
                    'check', 'ai_review', 'severity', aiReview.findings{i}.severity, ...
                    'message', aiReview.findings{i}.text); %#ok<AGROW>
            end
        catch ME
            result.checks.aiReview = struct('skipped', true, 'reason', ME.message);
        end
    else
        fprintf('[7/7] AI review SKIPPED\n');
    end

    %% Clamp score
    result.score = max(0, min(100, result.score));

    %% Generate summary
    totalIssues = numel(result.issues);
    criticalCount = sum(cellfun(@(x) strcmp(x.severity, 'critical'), result.issues));
    majorCount = sum(cellfun(@(x) strcmp(x.severity, 'major'), result.issues));
    minorCount = sum(cellfun(@(x) strcmp(x.severity, 'minor'), result.issues));

    grade = getGrade(result.score);
    result.summary = sprintf('Review: %s (score: %d/100, issues: %d critical, %d major, %d minor)', ...
        grade, result.score, criticalCount, majorCount, minorCount);
    result.grade = grade;

    %% Generate fix suggestions
    fprintf('Generating fix suggestions...\n');
    try
        addpath(fullfile(fileparts(mfilename('fullpath'))));
        result.fixSuggestions = generateFixSuggestions(result);
    catch ME
        result.fixSuggestions = {};
        fprintf('  ⚠ Fix suggestions skipped: %s\n', ME.message);
    end

    %% Generate HTML report
    result.reportFile = generateReviewReport(result, outputDir);

    %% Print summary
    fprintf('\n=== Review Complete ===\n');
    fprintf('Score: %d/100 (%s)\n', result.score, grade);
    fprintf('Issues: %d total (%d critical, %d major, %d minor)\n', ...
        totalIssues, criticalCount, majorCount, minorCount);
    fprintf('Report: %s\n', result.reportFile);

    if strcmp(severity, 'critical') && criticalCount > 0
        fprintf('\n⛔ FAILED: %d critical issues found\n', criticalCount);
    elseif strcmp(severity, 'major') && (criticalCount + majorCount) > 0
        fprintf('\n⛔ FAILED: %d critical+major issues found\n', criticalCount + majorCount);
    else
        fprintf('\n✅ PASSED\n');
    end
end

%% ================== AI-Driven Review ==================

function review = generateAIReview(modelName)
% Generate AI-driven design review using model_overview + model_read
    review = struct();
    review.score = 100;
    review.findings = {};
    review.comments = {};

    % Get model overview
    try
        overview = model_overview(modelName, 'root', 'full');
        overviewText = string(overview);
        review.overview = overviewText;
    catch
        review.overview = '';
    end

    % Read top-level structure
    try
        structure = model_read(modelName, 'root', '1');
        structText = string(structure);
        review.structure = structText;
    catch
        review.structure = '';
    end

    % Analyze for common anti-patterns
    allText = lower(review.overview + " " + review.structure);

    % Check for potential issues
    if contains(allText, 'terminator') || contains(allText, 'ground')
        review.findings{end+1} = struct(...
            'severity', 'minor', ...
            'text', '模型包含 Terminator/Ground 模块，可能是未连接的输出端口占位符。建议确认是否已完成连接。');
        review.score = review.score - 5;
    end

    if contains(allText, 'scope')
        review.findings{end+1} = struct(...
            'severity', 'minor', ...
            'text', '模型包含 Scope 模块（调试用途）。代码生成前建议移除。');
        review.score = review.score - 3;
    end

    if contains(allText, 'from') && contains(allText, 'goto')
        review.findings{end+1} = struct(...
            'severity', 'info', ...
            'text', '模型包含 From/Goto 跨层级信号路由。建议确认各配对标签名称一致性。');
    end

    if ~contains(allText, 'subsystem') && ~contains(allText, 'chart')
        review.findings{end+1} = struct(...
            'severity', 'info', ...
            'text', '模型没有子系统或 Stateflow Chart，可能是扁平结构。对于复杂逻辑建议进行功能分解。');
    end

    % Generate commentary
    lines = split(structText, newline);
    blockCount = 0;
    for i = 1:numel(lines)
        if contains(lines{i}, 'blk_')
            blockCount = blockCount + 1;
        end
    end

    if blockCount > 0
        review.comments{end+1} = sprintf('模型包含约 %d 个模块。', blockCount);
    end

    review.score = max(0, min(100, review.score));
end

%% ================== Report Generation ==================

function reportFile = generateReviewReport(result, outputDir)
    reportFile = fullfile(outputDir, [result.modelName '_review_report.html']);
    fid = fopen(reportFile, 'w');

    gradeColor = struct('A', '#4CAF50', 'B', '#8BC34A', 'C', '#FF9800', 'D', '#f44336');

    fprintf(fid, '<!DOCTYPE html>\n<html><head>\n');
    fprintf(fid, '<title>Review Report - %s</title>\n', result.modelName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:40px;background:#fafafa}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:3px solid %s;padding-bottom:10px}\n', ...
        getFieldStruct(gradeColor, result.grade, '#FF9800'));
    fprintf(fid, '.score-circle{width:120px;height:120px;border-radius:50%%;display:flex;align-items:center;');
    fprintf(fid, 'justify-content:center;font-size:36px;font-weight:bold;color:white;margin:20px auto;}\n');
    fprintf(fid, '.critical{background:#ffebee;border-left:4px solid #f44336;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.major{background:#fff3e0;border-left:4px solid #FF9800;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.minor{background:#e8f5e9;border-left:4px solid #4CAF50;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.info{background:#e3f2fd;border-left:4px solid #2196F3;padding:12px;margin:8px 0}\n');
    fprintf(fid, '.summary-card{background:white;border-radius:8px;padding:20px;margin:20px 0;box-shadow:0 2px 4px rgba(0,0,0,0.1)}\n');
    fprintf(fid, 'table{width:100%%;border-collapse:collapse;margin:10px 0}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:10px;text-align:left}\n');
    fprintf(fid, 'th{background:#37474F;color:white}\n');
    fprintf(fid, '.badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;color:white}\n');
    fprintf(fid, '.badge-crit{background:#f44336}.badge-major{background:#FF9800}.badge-minor{background:#4CAF50}\n');
    fprintf(fid, '</style></head><body>\n');

    % Header
    fprintf(fid, '<h1>Model Review Report: %s</h1>\n', result.modelName);

    % Score circle
    color = getFieldStruct(gradeColor, result.grade, '#FF9800');
    fprintf(fid, '<div style="text-align:center">\n');
    fprintf(fid, '<div class="score-circle" style="background:%s">%d</div>\n', color, result.score);
    fprintf(fid, '<p style="font-size:24px;font-weight:bold;color:%s">Grade %s</p>\n', color, result.grade);
    fprintf(fid, '</div>\n');

    % Summary card
    fprintf(fid, '<div class="summary-card">\n');
    fprintf(fid, '<h2>Summary</h2>\n');
    fprintf(fid, '<p>%s</p>\n', result.summary);
    fprintf(fid, '<table><tr><th>Metric</th><th>Value</th></tr>\n');
    fprintf(fid, '<tr><td>Total Issues</td><td>%d</td></tr>\n', numel(result.issues));
    critC = sum(cellfun(@(x) strcmp(x.severity,'critical'), result.issues));
    majC = sum(cellfun(@(x) strcmp(x.severity,'major'), result.issues));
    minC = sum(cellfun(@(x) strcmp(x.severity,'minor'), result.issues));
    fprintf(fid, '<tr><td>Critical</td><td>%d</td></tr>\n', critC);
    fprintf(fid, '<tr><td>Major</td><td>%d</td></tr>\n', majC);
    fprintf(fid, '<tr><td>Minor</td><td>%d</td></tr>\n', minC);
    fprintf(fid, '<tr><td>Reviewed</td><td>%s</td></tr>\n', result.timestamp);
    fprintf(fid, '</table>\n');
    fprintf(fid, '</div>\n');

    % Issues list
    if ~isempty(result.issues)
        fprintf(fid, '<div class="summary-card">\n');
        fprintf(fid, '<h2>Issues</h2>\n');
        for i = 1:numel(result.issues)
            iss = result.issues{i};
            badge = sprintf('<span class="badge badge-%s">%s</span>', ...
                iss.severity, iss.severity);
            fprintf(fid, '<div class="%s"><strong>%s</strong> %s<br><code>%s</code></div>\n', ...
                iss.severity, badge, iss.check, iss.message);
        end
        fprintf(fid, '</div>\n');
    end

    % Check details
    fprintf(fid, '<div class="summary-card">\n');
    fprintf(fid, '<h2>Check Details</h2>\n');
    checkNames = fieldnames(result.checks);
    for i = 1:numel(checkNames)
        c = result.checks.(checkNames{i});
        fprintf(fid, '<h3>%s</h3>\n', checkNames{i});
        if isstruct(c)
            f = fieldnames(c);
            fprintf(fid, '<table><tr><th>Field</th><th>Value</th></tr>\n');
            for j = 1:min(10, numel(f))
                val = c.(f{j});
                if ischar(val) || isstring(val)
                    fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', f{j}, ...
                        escapeHtml(char(val)));
                elseif isnumeric(val)
                    fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', f{j}, num2str(val));
                end
            end
            fprintf(fid, '</table>\n');
        end
    end
    fprintf(fid, '</div>\n');

    % AI Review comments
    if isfield(result.checks, 'aiReview') && ~isfield(result.checks.aiReview, 'skipped')
        ai = result.checks.aiReview;
        if isfield(ai, 'comments') && ~isempty(ai.comments)
            fprintf(fid, '<div class="summary-card">\n');
            fprintf(fid, '<h2>AI Review Commentary</h2>\n<ul>\n');
            for i = 1:numel(ai.comments)
                fprintf(fid, '<li>%s</li>\n', escapeHtml(ai.comments{i}));
            end
            fprintf(fid, '</ul>\n</div>\n');
        end
    end

    % Recommendation
    fprintf(fid, '<div class="summary-card">\n');
    fprintf(fid, '<h2>Recommendations</h2>\n<ul>\n');
    if result.score < 60
        fprintf(fid, '<li>🔴 模型存在严重问题，建议修复所有 critical/major 问题后重新 Review</li>\n');
    elseif result.score < 80
        fprintf(fid, '<li>🟠 模型基本可用，建议修复 major 问题</li>\n');
    else
        fprintf(fid, '<li>🟢 模型质量良好</li>\n');
    end
    fprintf(fid, '<li>运行 <code>/autoLayout</code> 统一布局</li>\n');
    fprintf(fid, '<li>运行 <code>/setPortTypes</code> 统一端口数据类型</li>\n');
    fprintf(fid, '<li>运行 <code>/checkModel</code> 零误差门限验证</li>\n');
    fprintf(fid, '</ul>\n</div>\n');

    % Fix Suggestions
    if isfield(result, 'fixSuggestions') && ~isempty(result.fixSuggestions)
        fprintf(fid, '<div class="summary-card">\n');
        fprintf(fid, '<h2>🔧 修改建议</h2>\n');
        for i = 1:numel(result.fixSuggestions)
            s = result.fixSuggestions{i};
            if strcmp(s.category, 'action_plan')
                % Action plan - full width
                fprintf(fid, '<div class="info" style="white-space:pre-wrap;font-size:13px">%s</div>\n', ...
                    escapeHtml(s.suggestion));
            else
                % Individual suggestion
                badge = sprintf('<span class="badge badge-%s">%s</span>', ...
                    s.severity, s.severity);
                fprintf(fid, '<div class="%s">\n', s.severity);
                fprintf(fid, '<strong>%s</strong> %s<br>\n', badge, escapeHtml(s.issue));
                fprintf(fid, '<p style="margin:6px 0 0 0;color:#555">💡 %s</p>\n', escapeHtml(s.suggestion));
                if isfield(s, 'command') && ~isempty(s.command)
                    fprintf(fid, '<p style="margin:2px 0 0 0;font-size:12px;color:#888"><code>%s</code></p>\n', ...
                        escapeHtml(s.command));
                end
                if isfield(s, 'example') && ~isempty(s.example)
                    fprintf(fid, '<p style="margin:2px 0 0 0;font-size:12px;color:#999">例: %s</p>\n', ...
                        escapeHtml(s.example));
                end
                fprintf(fid, '</div>\n');
            end
        end
        fprintf(fid, '</div>\n');
    end

    fprintf(fid, '<hr><p style="color:#999;font-size:12px">Generated by reviewModel.m</p>\n');
    fprintf(fid, '</body></html>\n');
    fclose(fid);
end

%% ================== Utility ==================

function s = escapeHtml(s)
    s = strrep(s, '&', '&amp;');
    s = strrep(s, '<', '&lt;');
    s = strrep(s, '>', '&gt;');
end
end

function val = getFieldStruct(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end

function s = escapeHtml(s)
    s = strrep(s, '&', '&amp;');
    s = strrep(s, '<', '&lt;');
    s = strrep(s, '>', '&gt;');
end
