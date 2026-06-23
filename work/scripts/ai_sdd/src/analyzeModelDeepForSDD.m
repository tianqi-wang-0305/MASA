function knowledgeFile = analyzeModelDeepForSDD(modelPath, excelPath)
% analyzeModelDeepForSDD  Deep analysis of Simulink model using Agentic Toolkit tools
%   Generates a structured JSON knowledge base with rich subsystem descriptions
%   for use by DdGeneration_AI.m to produce ASPICE-compliant SDD reports.
%
%   Inputs:
%       modelPath  - Full path to .slx/.mdl file
%       excelPath  - Full path to Excel interface/calibration workbook
%
%   Outputs:
%       knowledgeFile - Path to generated JSON knowledge base file
%
%   Usage:
%       knowledgeFile = analyzeModelDeepForSDD('path/to/Model.slx', 'path/to/workbook.xlsx');

    fprintf('=== AI-Enhanced SDD: Deep Model Analysis ===\n\n');

    %% 0) Resolve paths
    [modelDir, modelBase, ~] = fileparts(char(modelPath));
    if isempty(modelDir)
        modelDir = pwd;
    end
    modelName = string(modelBase);

    % Ensure toolkit on path
    toolkitRoot = getToolkitRoot();
    addpath(toolkitRoot);

    %% 1) Load model and read Excel
    fprintf('[1/6] Loading model: %s\n', modelName);
    load_system(modelPath);

    fprintf('[2/6] Reading Excel workbook: %s\n', excelPath);
    interfaceInfo = readInterfaceWorkbook(excelPath);

    %% 2) Get full model hierarchy via model_overview
    fprintf('[3/6] Getting model hierarchy via model_overview...\n');
    try
        overviewResult = model_overview(char(modelName), "root", "full");
        overviewText = string(overviewResult);
    catch ME
        warning('model_overview failed: %s', ME.message);
        overviewText = "";
    end

    %% 3) Traverse all subsystems
    fprintf('[4/6] Analyzing subsystems...\n');
    allSystems = collectAllSubsystems(modelName);
    subsystemKnowledge = struct();

    for i = 1:numel(allSystems)
        sysPath = allSystems(i);
        sysName = string(get_param(sysPath, 'Name'));

        % Skip non-functional subsystems
        if shouldSkipSubsystem(sysPath)
            fprintf('  Skipping (non-functional): %s\n', sysName);
            continue;
        end

        fprintf('  Analyzing [%d/%d]: %s ... ', i, numel(allSystems), sysName);

        try
            sysKnowledge = analyzeSingleSubsystem(modelName, sysPath);
            subsystemKnowledge.(matlab.lang.makeValidName(sysName)) = sysKnowledge;
            fprintf('OK\n');
        catch ME
            fprintf('FAILED: %s\n', ME.message);
            subsystemKnowledge.(matlab.lang.makeValidName(sysName)) = struct(...
                'path', sysPath, ...
                'name', sysName, ...
                'analysisError', ME.message);
        end
    end

    %% 4) Resolve top-level workspace variables
    fprintf('[5/6] Resolving workspace variables...\n');
    workspaceVars = resolveModelVariables(modelName);

    %% 5) Compile knowledge base and write JSON
    fprintf('[6/6] Writing knowledge base...\n');

    knowledgeBase = struct();
    knowledgeBase.modelName = modelName;
    knowledgeBase.modelPath = modelPath;
    knowledgeBase.excelPath = excelPath;
    knowledgeBase.analysisDate = string(datetime('now'));
    knowledgeBase.overviewText = overviewText;
    knowledgeBase.interfaceInfo = interfaceInfo;
    knowledgeBase.workspaceVariables = workspaceVars;
    knowledgeBase.subsystems = subsystemKnowledge;
    knowledgeBase.totalSubsystems = numel(allSystems);
    knowledgeBase.analyzedSubsystems = numel(fieldnames(subsystemKnowledge));

    % Write JSON
    knowledgeFile = fullfile(modelDir, modelName + "_model_knowledge.json");
    knowledgeJson = jsonencode(knowledgeBase, 'PrettyPrint', true);
    fid = fopen(knowledgeFile, 'w');
    if fid < 0
        error('Cannot write knowledge file: %s', knowledgeFile);
    end
    fwrite(fid, knowledgeJson, 'char');
    fclose(fid);

    fprintf('\n=== Analysis complete ===\n');
    fprintf('Knowledge base written to: %s\n', knowledgeFile);
    fprintf('Analyzed %d / %d subsystems\n', ...
        knowledgeBase.analyzedSubsystems, knowledgeBase.totalSubsystems);
end

%% ================== Helper Functions ==================

function knowledge = analyzeSingleSubsystem(modelName, sysPath)
% Analyze one subsystem using model_read and model_query_params
    knowledge = struct();
    knowledge.path = sysPath;
    knowledge.name = string(get_param(sysPath, 'Name'));

    % --- model_read: get signal flow and algorithm ---
    try
        scopeId = resolveBlockScopeId(sysPath);
        readResult = string(model_read(char(modelName), "root", scopeId));
        knowledge.modelReadSuccess = true;
    catch ME
        readResult = "MCP unavailable: " + ME.message;
        knowledge.modelReadSuccess = false;
    end
    knowledge.modelReadOutput = char(readResult);

    % Parse key info from model_read output
    try
        knowledge.parsedInfo = parseModelReadOutput(readResult);
    catch ME
        knowledge.parsedInfo = struct('variableRefs',{},'keyBlocks',{},'signalFlow',"",'hasStateflow',false,'hasMathOps',false,'hasLogicOps',false,'hasLookup',false);
    end

    % --- model_query_params: get block parameters ---
    try
        paramsResult = model_query_params(char(modelName), ...
            jsonencode({scopeId}), jsonencode(["all"]), "false");
        knowledge.blockParams = string(paramsResult);
    catch ME
        knowledge.blockParams = "query_params failed: " + ME.message;
    end

    % --- resolve key params ---
    knowledge.variables = struct();
    try
        if isfield(knowledge.parsedInfo, 'variableRefs') && ~isempty(knowledge.parsedInfo.variableRefs)
            try
                encoded = jsonencode(knowledge.parsedInfo.variableRefs);
                if ~isempty(encoded)
                    varResult = model_resolve_params(char(modelName), encoded);
                    knowledge.resolvedVariables = string(varResult);
                end
            catch ME
                knowledge.resolvedVariables = "resolve: " + ME.message;
            end
        end
    catch ME
        knowledge.resolvedVariables = "resolve failed: " + ME.message;
    end

    % --- Get direct children subsystems ---
    children = getDirectSubsystems(sysPath);
    knowledge.childSubsystems = strings(0, 1);
    for j = 1:numel(children)
        knowledge.childSubsystems(end+1) = string(get_param(children{j}, 'Name'));
    end

    % --- Count block types ---
    knowledge.blockTypeSummary = summarizeDominantBlocks(sysPath);

    % --- Get port info ---
    knowledge.inputPorts = getDirectPortNames(sysPath, 'Inport');
    knowledge.outputPorts = getDirectPortNames(sysPath, 'Outport');

    % --- Generate rich description ---
    try
        knowledge.description = composeRichDescription(knowledge);
    catch ME
        knowledge.description = sprintf('【%s】信号处理模块（描述生成异常：%s）', knowledge.name, ME.message);
    end
    catch ME
        st = ME.stack;
        stackStr = '';
        for si = 1:min(5, numel(st))
            stackStr = [stackStr sprintf('  %s:%d\n', st(si).file, st(si).line)]; %#ok<AGROW>
        end
        knowledge.description = sprintf('【%s】分析失败：%s', sysPath, ME.message);
        knowledge.analysisError = sprintf('%s\nStack:\n%s', ME.message, stackStr);
    end
end

function info = parseModelReadOutput(readText)
% Extract structured information from model_read output
    info = struct();
    info.variableRefs = {};
    info.keyBlocks = {};
    info.signalFlow = "";
    info.hasStateflow = false;
    info.hasMathOps = false;
    info.hasLogicOps = false;
    info.hasLookup = false;

    if strlength(readText) == 0
        return;
    end

    lines = split(readText, newline);
    blockTypes = {};
    variableRefs = {};

    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if strlength(line) == 0
            continue;
        end

        % Detect variable references (@Param(X))
        varMatches = regexp(line, '@Param\(([^)]+)\)', 'tokens');
        for j = 1:numel(varMatches)
            if ~isempty(varMatches{j})
                variableRefs{end+1} = varMatches{j}{1}; %#ok<AGROW>
            end
        end

        % Detect key block types
        if contains(line, '@Gain(')
            blockTypes{end+1} = 'Gain'; %#ok<AGROW>
        end
        if contains(line, '@Sum(') || contains(line, '@Add(')
            blockTypes{end+1} = 'Sum'; %#ok<AGROW>
        end
        if contains(line, '@Product(') || contains(line, '@Divide(')
            blockTypes{end+1} = 'Product'; %#ok<AGROW>
        end
        if contains(line, '@Integrator(')
            blockTypes{end+1} = 'Integrator'; %#ok<AGROW>
        end
        if contains(line, '@TransferFcn(') || contains(line, '@DiscreteFilter(')
            blockTypes{end+1} = 'Filter'; %#ok<AGROW>
        end
        if contains(line, '@Lookup')
            blockTypes{end+1} = 'LookupTable'; %#ok<AGROW>
        end
        if contains(line, '@Switch(') || contains(line, '@Relational(')
            blockTypes{end+1} = 'Switch/Compare'; %#ok<AGROW>
        end
        if contains(line, '@Saturate(')
            blockTypes{end+1} = 'Saturation'; %#ok<AGROW>
        end
        if contains(line, '@UnitDelay(') || contains(line, '@Delay(')
            blockTypes{end+1} = 'Delay/Memory'; %#ok<AGROW>
        end
        if contains(line, 'Stateflow') || contains(line, 'Chart')
            info.hasStateflow = true;
        end
    end

    info.variableRefs = unique(variableRefs);
    info.keyBlocks = unique(blockTypes);
    info.hasMathOps = any(contains(info.keyBlocks, {'Gain', 'Sum', 'Product', 'Integrator', 'Filter'}));
    info.hasLogicOps = any(contains(info.keyBlocks, {'Switch/Compare', 'Saturation'}));
    info.hasLookup = any(contains(info.keyBlocks, 'LookupTable'));

    % Extract signal flow description (first few meaningful lines)
    flowLines = {};
    for i = 1:min(20, numel(lines))
        line = strtrim(lines(i));
        if strlength(line) > 0 && ...
           ~startsWith(lower(line), {'status:', 'model:', 'scope:', 'token', 'blocks:', 'interfaces:'})
            flowLines{end+1} = line; %#ok<AGROW>
        end
    end
    info.signalFlow = strjoin(flowLines, ' | ');
end

function desc = composeRichDescription(knowledge)
% Generate a rich natural-language description from the knowledge structure
    desc = strings(0, 1);
    sysName = knowledge.name;
    parsed = knowledge.parsedInfo;
    blockSummary = knowledge.blockTypeSummary;

    % ---- Opening: role identification ----
    lowerName = lower(sysName);
    rolePhrase = inferRolePhrase(lowerName, blockSummary, parsed);
    desc(end+1) = sprintf('【%s】%s。', sysName, rolePhrase);

    % ---- Interface description ----
    inPorts = knowledge.inputPorts;
    outPorts = knowledge.outputPorts;
    if ~isempty(inPorts)
        inStr = strjoin(arrayfun(@(x) string(x), inPorts, 'UniformOutput', false), '、');
        desc(end+1) = sprintf('输入接口：%s。', inStr);
    end
    if ~isempty(outPorts)
        outStr = strjoin(arrayfun(@(x) string(x), outPorts, 'UniformOutput', false), '、');
        desc(end+1) = sprintf('输出接口：%s。', outStr);
    end

    % ---- Algorithm / signal flow description ----
    if strlength(blockSummary) > 0 && ~contains(blockSummary, '接口/层级组织')
        desc(end+1) = composeAlgorithmDescription(parsed, blockSummary);
    end

    % ---- Child subsystems ----
    if ~isempty(knowledge.childSubsystems)
        childStr = strjoin(knowledge.childSubsystems, '、');
        desc(end+1) = sprintf('包含子功能模块：%s。', childStr);
    end

    % ---- Variable/calibration dependency ----
    if ~isempty(parsed.variableRefs)
        varList = parsed.variableRefs;
        if numel(varList) > 6
            varStr = strjoin(varList(1:6), '、') + sprintf('等共%d个标定/参数变量', numel(varList));
        else
            varStr = strjoin(varList, '、');
        end
        desc(end+1) = sprintf('依赖标定参数/变量：%s。', varStr);
    end

    % ---- Stateflow note ----
    if parsed.hasStateflow
        desc(end+1) = '本模块包含Stateflow状态机，实现状态转移和模式切换逻辑。';
    end

    % ---- Model_read output excerpt (as reference) ----
    readText = knowledge.modelReadOutput;
    if strlength(readText) > 0
        excerpt = extractBefore(readText, 300);
        excerpt = strtrim(regexprep(excerpt, '\s+', ' '));
        desc(end+1) = sprintf('信号流解析：%s', excerpt);
    end

    desc = strjoin(desc, newline);
end

function rolePhrase = inferRolePhrase(lowerName, blockSummary, parsed)
% Infer the functional role of a subsystem
    % Check name-based patterns first (highest confidence)
    if contains(lowerName, {'command', 'arbit', 'decision', 'judge', 'ctrl'})
        rolePhrase = '控制决策与逻辑仲裁模块，负责输入信号的条件判断、状态裁决和指令输出';
    elseif contains(lowerName, {'tailgate', 'tail'})
        rolePhrase = '尾门控制模块，处理尾门请求判定和动作裁决';
    elseif contains(lowerName, {'light', 'lamp', 'indicator'})
        rolePhrase = '状态指示与灯光控制模块，根据系统状态驱动指示信号';
    elseif contains(lowerName, {'motor', 'drive', 'actuat'})
        rolePhrase = '执行驱动模块，将控制指令映射为具体执行器输出';
    elseif contains(lowerName, {'filter', 'smooth'})
        rolePhrase = '信号滤波与平滑处理模块，对输入信号进行滤波整形';
    elseif contains(lowerName, {'fault', 'diag', 'monitor'})
        rolePhrase = '故障诊断与监控模块，检测系统异常状态并生成故障标志';
    elseif contains(lowerName, {'enable', 'protect', 'safe'})
        rolePhrase = '安全保护与使能控制模块，根据安全条件使能或禁止输出';
    elseif contains(lowerName, {'calc', 'compute', 'math'})
        rolePhrase = '数学运算与信号变换模块，执行数值计算和信号整形';
    % Check block-type patterns
    elseif parsed.hasStateflow
        rolePhrase = '状态机控制模块，通过有限状态机实现模式切换和状态管理';
    elseif parsed.hasLookup && parsed.hasMathOps
        rolePhrase = '标定查表与运算模块，结合查表和数学运算实现非线性映射';
    elseif parsed.hasLogicOps && parsed.hasMathOps
        rolePhrase = '逻辑判断与运算模块，综合条件判断和数值计算';
    elseif parsed.hasMathOps && ~parsed.hasLogicOps
        rolePhrase = '信号运算与变换模块，对输入信号进行数学变换和处理';
    elseif parsed.hasLogicOps && ~parsed.hasMathOps
        rolePhrase = '逻辑判断模块，执行条件判断和信号选择';
    elseif contains(blockSummary, 'Lookup') || contains(blockSummary, 'Table')
        rolePhrase = '标定查表模块，通过查表实现参数化映射关系';
    elseif contains(blockSummary, 'Delay') || contains(blockSummary, 'Memory') || contains(blockSummary, 'UnitDelay')
        rolePhrase = '时序保持与状态传递模块，维持信号时序和状态记忆';
    elseif contains(blockSummary, 'Switch') || contains(blockSummary, 'Compare')
        rolePhrase = '条件路由与信号选择模块，根据条件切换信号通路';
    elseif contains(blockSummary, 'Gain') || contains(blockSummary, 'Sum') || contains(blockSummary, 'Product')
        rolePhrase = '信号运算与缩放模块，执行增益、求和等数学运算';
    elseif contains(blockSummary, 'Integrator') || contains(blockSummary, 'TransferFcn') || contains(blockSummary, 'Filter')
        rolePhrase = '动态系统与滤波模块，实现连续/离散传递函数和滤波算法';
    elseif contains(blockSummary, 'Relational') || contains(blockSummary, 'Logic')
        rolePhrase = '逻辑比较模块，执行信号比较和布尔逻辑运算';
    else
        rolePhrase = '信号处理与功能传递模块，完成局部信号处理任务';
    end
end

function algDesc = composeAlgorithmDescription(parsed, blockSummary)
% Describe the algorithm based on identified block types and patterns
    parts = {};
    blockTypes = parsed.keyBlocks;

    if parsed.hasStateflow
        parts{end+1} = '通过Stateflow状态机实现模式切换和状态管理逻辑';
    end
    if parsed.hasLookup
        parts{end+1} = '采用查表方式实现非线性映射或标定参数化计算';
    end
    if any(contains(blockTypes, 'Filter'))
        parts{end+1} = '包含滤波算法对信号进行平滑处理';
    end
    if any(contains(blockTypes, 'Integrator'))
        parts{end+1} = '包含积分环节实现累加或动态过程模拟';
    end
    if any(contains(blockTypes, 'Gain'))
        parts{end+1} = '通过增益模块对信号进行缩放调整';
    end
    if any(contains(blockTypes, 'Sum'))
        parts{end+1} = '通过求和模块进行信号合成或偏差计算';
    end
    if any(contains(blockTypes, 'Product'))
        parts{end+1} = '包含乘法/除法运算实现信号比例变换';
    end
    if any(contains(blockTypes, 'Saturation'))
        parts{end+1} = '包含限幅模块对输出进行上下界约束';
    end
    if any(contains(blockTypes, 'Switch/Compare'))
        parts{end+1} = '通过条件比较和切换实现信号路由选择';
    end
    if any(contains(blockTypes, 'Delay/Memory'))
        parts{end+1} = '包含延迟/保持单元实现时序逻辑';
    end

    if isempty(parts)
        algDesc = sprintf('包含模块类型：%s。', blockSummary);
    else
        algDesc = sprintf('算法特征：%s。', strjoin(parts, '；'));
    end
end

function scopeId = resolveBlockScopeId(sysPath)
    sidValue = string(get_param(sysPath, 'SID'));
    scopeId = regexprep(sidValue, '^blk_', '');
    if strlength(scopeId) == 0
        scopeId = 'root';
    end
end

function systems = collectAllSubsystems(modelName)
% Collect all subsystems in the model hierarchy
    allSystems = unique([string(modelName); string(find_system(modelName, ...
        'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', ...
        'Type', 'Block', ...
        'BlockType', 'SubSystem'))], 'stable');

    % Filter out non-functional ones
    keep = true(size(allSystems));
    for i = 1:numel(allSystems)
        if shouldSkipSubsystem(allSystems(i))
            keep(i) = false;
        end
    end
    systems = allSystems(keep);
end

function tf = shouldSkipSubsystem(sysPath)
    tf = false;
    try
        sysName = lower(string(get_param(sysPath, 'Name')));
    catch
        sysName = '';
    end
    try
        maskType = lower(string(get_param(sysPath, 'MaskType')));
    catch
        maskType = '';
    end
    try
        blockType = lower(string(get_param(sysPath, 'BlockType')));
    catch
        blockType = '';
    end

    if contains(sysName, 'event listener') || contains(sysName, 'eventlistener') || ...
       contains(maskType, 'event listener') || contains(sysName, 'enumerated constant') || ...
       contains(maskType, 'enumerated constant') || strcmpi(blockType, 'EnumeratedConstant')
        tf = true;
    end
end

function rootPath = getToolkitRoot()
% Find the simulink-agentic-toolkit root directory
    % Check environment variable first
    envPath = string(getenv('SATK_ROOT'));
    if strlength(envPath) > 0 && exist(envPath, 'dir')
        rootPath = char(envPath);
        return;
    end

    % Search relative to this script
    scriptPath = fileparts(mfilename('fullpath'));
    candidates = {
        fullfile(scriptPath, '..', '..', '..', 'simulink-agentic-toolkit');
        fullfile(scriptPath, '..', '..', '..', '..', 'simulink-agentic-toolkit');
        fullfile(scriptPath, '..', '..', 'simulink-agentic-toolkit');
    };

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'dir') && exist(fullfile(candidates{i}, 'tools', 'model_overview', 'model_overview.p'), 'file')
            rootPath = candidates{i};
            return;
        end
    end

    % Default: assume it's on MATLAB path
    rootPath = '';
end

function workspaceVars = resolveModelVariables(modelName)
% Resolve key workspace variables
    workspaceVars = struct();
    try
        % Get all workspace variables used by the model
        params = get_param(modelName, 'ParameterArgumentNames');
        if isempty(params)
            return;
        end
        varNames = strsplit(strtrim(params), ',');
        for i = 1:numel(varNames)
            vName = strtrim(varNames{i});
            if strlength(vName) > 0 && evalin('base', ['exist(''', vName, ''', ''var'')'])
                val = evalin('base', vName);
                if isnumeric(val)
                    workspaceVars.(matlab.lang.makeValidName(vName)) = val;
                end
            end
        end
    catch
        % Silent fail - variables may not be in base workspace
    end
end

function names = getDirectPortNames(sysPath, blockType)
    blocks = find_system(sysPath, 'SearchDepth', 1, 'BlockType', blockType);
    names = strings(0, 1);
    for i = 1:numel(blocks)
        if string(blocks{i}) == string(sysPath)
            continue;
        end
        names(end+1) = string(get_param(blocks{i}, 'Name')); %#ok<AGROW>
    end
end

function summary = summarizeDominantBlocks(sysPath)
    blocks = find_system(sysPath, 'SearchDepth', 1);
    counts = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for i = 1:numel(blocks)
        blockPath = string(blocks{i});
        if blockPath == string(sysPath)
            continue;
        end
        try
            blockType = string(get_param(blockPath, 'BlockType'));
        catch
            blockType = '';
        end
        if blockType == 'SubSystem' || blockType == 'Inport' || blockType == 'Outport'
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
        summary = '接口/层级组织';
        return;
    end

    keysList = string(keys(counts));
    valuesList = zeros(numel(keysList), 1);
    for i = 1:numel(keysList)
        valuesList(i) = counts(char(keysList(i)));
    end

    [~, order] = sort(valuesList, 'descend');
    selected = keysList(order(1:min(4, numel(order))));
    summary = strjoin(selected.', '、');
end

function children = getDirectSubsystems(parentPath)
    blocks = find_system(parentPath, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    children = strings(0, 1);
    for i = 1:numel(blocks)
        blockPath = string(blocks{i});
        if blockPath == string(parentPath)
            continue;
        end
        if shouldSkipSubsystem(blockPath)
            continue;
        end
        children(end+1) = blockPath; %#ok<AGROW>
    end
end

%% --- Excel reading helpers (mirrored from DdGeneration_ASPICE.m) ---

function workbookData = readInterfaceWorkbook(excelPath)
    workbookData = struct('Interface', struct(), 'Calibration', struct());
    try
        sheets = sheetnames(excelPath);
    catch
        sheets = strings(0, 1);
    end
    if numel(sheets) < 1
        return;
    end

    signalSheet = findSheetByName(sheets, 'signal');
    calSheet = findSheetByName(sheets, 'cal');
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
    sheetName = '';
    for i = 1:numel(sheets)
        if strcmpi(strtrim(string(sheets(i))), targetName)
            sheetName = string(sheets(i));
            return;
        end
    end
end

function sheetData = readSignalWorkbookSheet(excelPath, sheetName)
    raw = readcell(excelPath, 'Sheet', sheetName);
    sheetData = struct('SheetName', string(sheetName), 'Items', table());
    if isempty(raw)
        return;
    end
    headers = string(raw(1, :));
    headers = strtrim(headers);
    data = raw(2:end, :);
    sheetData.Items = extractTabularRows(data, headers);
end

function sheetData = readCalibrationWorkbookSheet(excelPath, sheetName)
    raw = readcell(excelPath, 'Sheet', sheetName);
    sheetData = struct('SheetName', string(sheetName), 'Items', table());
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
                rows{r, c} = '';
            end
        end
    end
    outTable = cell2table(rows, 'VariableNames', cellstr(headerNames));
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
        name = 'Column' + string(index);
    end
    name = regexprep(name, '[^A-Za-z0-9_]', '_');
    if ~isletter(extractBefore(name, 2)) && extractBefore(name, 2) ~= '_'
        name = 'Col_' + name;
    end
    while contains(name, '__')
        name = replace(name, '__', '_');
    end
    name = matlab.lang.makeValidName(char(name));
end
