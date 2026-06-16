function auditResult = run_model_advisor(modelPath)
if nargin < 1 || ~(ischar(modelPath) || isstring(modelPath)) || strlength(string(modelPath)) == 0
    error('必须提供有效的 Simulink 模型路径。');
end

modelPath = normalizePath(string(modelPath));
if ~isfile(modelPath)
    error('模型文件不存在: %s', modelPath);
end

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);

[~, modelName, ~] = fileparts(modelPath);
modelName = string(modelName);
cleanupObj = onCleanup(@() closeLoadedModel(modelName));

try
    load_system(modelPath);

    [namingViolations, namingStats] = check_naming_convention(modelName);
    [connectionViolations, connectionStats] = check_connection_rules(modelName);
    [hierarchyViolations, hierarchyStats] = check_hierarchy_integrity(modelName);
    advisorSummary = run_model_advisor_checks(modelName);

    issueGroups = struct();
    issueGroups.naming = namingViolations;
    issueGroups.connection = connectionViolations;
    issueGroups.hierarchy = hierarchyViolations;
    issueGroups.modelAdvisor = advisorSummary.violations;

    issues = [namingViolations(:); connectionViolations(:); hierarchyViolations(:); advisorSummary.violations(:)];

    auditResult = struct();
    auditResult.success = true;
    auditResult.model = char(modelPath);
    auditResult.model_name = char(modelName);
    auditResult.issues_count = numel(issues);
    auditResult.naming_count = numel(namingViolations);
    auditResult.connection_count = numel(connectionViolations);
    auditResult.hierarchy_count = numel(hierarchyViolations);
    auditResult.model_advisor_count = numel(advisorSummary.violations);
    auditResult.naming = namingStats;
    auditResult.connections = connectionStats;
    auditResult.hierarchy = hierarchyStats;
    auditResult.model_advisor = advisorSummary;
    auditResult.issue_groups = issueGroups;
    auditResult.summary = composeSummary(auditResult);
    auditResult.report_path = report_utils(auditResult);

    fprintf('%s\n', jsonencode(auditResult));
catch ME
    auditResult = struct();
    auditResult.success = false;
    auditResult.model = char(modelPath);
    auditResult.error = char(ME.message);
    fprintf('%s\n', jsonencode(auditResult));
end
end

function advisorSummary = run_model_advisor_checks(modelName)
advisorSummary = struct();
advisorSummary.executed = false;
advisorSummary.check_ids = defaultModelAdvisorCheckIds();
advisorSummary.violations = {};
advisorSummary.raw_output = '';

try
    resultArray = ModelAdvisor.run({char(modelName)}, advisorSummary.check_ids);
    advisorSummary.executed = true;
    advisorSummary.raw_output = strtrim(evalc('disp(resultArray)'));
catch ME
    advisorSummary.raw_output = char(ME.message);
    advisorSummary.violations = {sprintf('【Model Advisor】执行失败：%s', ME.message)};
end
end

function checkIds = defaultModelAdvisorCheckIds()
checkIds = {
    'mathworks.design.UnconnectedLinesPorts'
    'mathworks.jmaab.jc_0243'
    'mathworks.jmaab.jc_0247'
    'mathworks.jmaab.jc_0244'
    'mathworks.jmaab.db_0137'
    'mathworks.jmaab.jc_0531'
    'mathworks.jmaab.jc_0723'
    'mathworks.jmaab.jc_0773'
    'mathworks.jmaab.jc_0797'
    'mathworks.hism.hisf_0013'
    'mathworks.hism.hisl_0061'
    'mathworks.maab.db_0143'
};
end

function summaryText = composeSummary(auditResult)
parts = strings(0, 1);
parts(end + 1, 1) = sprintf('发现 %d 处问题。', auditResult.issues_count);
parts(end + 1, 1) = sprintf('命名违规 %d 处，连线违规 %d 处，层级违规 %d 处。', ...
    auditResult.naming_count, auditResult.connection_count, auditResult.hierarchy_count);
parts(end + 1, 1) = sprintf('Model Advisor 额外发现 %d 处问题或执行异常。', auditResult.model_advisor_count);
parts(end + 1, 1) = sprintf('模型最大层级深度为 %d，子系统总数为 %d。', ...
    auditResult.hierarchy.maxDepth, auditResult.hierarchy.subsystemCount);
summaryText = char(strjoin(parts, ' '));
end

function closeLoadedModel(modelName)
if bdIsLoaded(char(modelName))
    close_system(char(modelName), 0);
end
end

function p = normalizePath(pathStr)
p = replace(pathStr, '/', filesep);
p = replace(p, '\', filesep);
end