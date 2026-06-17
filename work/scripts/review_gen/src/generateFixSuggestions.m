function suggestions = generateFixSuggestions(reviewResult)
% generateFixSuggestions  Generate specific fix suggestions from review results
%   Takes the result struct from reviewModel() and produces actionable
%   fix recommendations for each issue found.
%
%   Inputs:
%       reviewResult - result struct from reviewModel()
%
%   Outputs:
%       suggestions - cell array of fix suggestion structs

    fprintf('Generating fix suggestions...\n');
    suggestions = {};

    if ~isfield(reviewResult, 'issues') || isempty(reviewResult.issues)
        suggestions{end+1} = struct(...
            'severity', 'info', ...
            'category', 'general', ...
            'issue', 'No issues found', ...
            'suggestion', '模型无问题，无需修改');
        return;
    end

    %% Generate suggestions for each issue
    for i = 1:numel(reviewResult.issues)
        iss = reviewResult.issues{i};
        sug = generateSingleSuggestion(iss);
        if ~isempty(sug)
            suggestions{end+1} = sug; %#ok<AGROW>
        end
    end

    %% Add prioritized action plan
    suggestions = addActionPlan(suggestions);

    fprintf('Generated %d fix suggestions\n', numel(suggestions));
end

function sug = generateSingleSuggestion(iss)
% Generate a specific fix suggestion for one issue
    sug = [];
    msg = iss.message;
    check = iss.check;
    sev = iss.severity;

    switch check
        case 'naming'
            sug = suggestNamingFix(msg);
        case 'connection'
            sug = suggestConnectionFix(msg);
        case 'hierarchy'
            sug = suggestHierarchyFix(msg);
        case 'datatype'
            sug = suggestDatatypeFix(msg);
        case 'ai_review'
            sug = suggestAIReviewFix(msg);
        otherwise
            sug = struct('severity', sev, 'category', check, ...
                'issue', msg, 'suggestion', '请人工审查此问题');
    end
end

function sug = suggestNamingFix(msg)
% Suggest fix for naming convention violations
    sug = struct();
    sug.category = 'naming';
    sug.severity = 'minor';

    % Extract the block/port name from message
    tokens = regexp(msg, '"([^"]+)"', 'tokens');
    if isempty(tokens)
        sug.issue = msg;
        sug.suggestion = '请检查命名是否符合规范';
        return;
    end
    name = tokens{1}{1};
    sug.issue = msg;

    % Generate fix suggestion based on pattern
    if contains(msg, '端口') || contains(msg, '信号命名')
        % Signal naming fix: suggest adding type prefix
        sug.suggestion = sprintf('将 "%s" 重命名为带数据类型前缀的格式，如 u16%s（根据实际类型选择 u8/s16/f32/b 等）', name, name);
        sug.example = sprintf('u16%s  → uint16 端口', name);
        sug.command = sprintf('模型浏览器中右键 "%s" → 重命名，或使用 /setPortTypes 自动设置', name);

    elseif contains(msg, '标定') || contains(msg, 'cal_')
        % Calibration naming fix: suggest cal_ prefix
        sug.suggestion = sprintf('将 "%s" 重命名为 cal_{type}%s 格式，如 cal_u16%s', name, name, name);
        sug.example = sprintf('cal_u16%s  → uint16 标定参数', name);
        sug.command = sprintf('在模块 "%s" 的属性对话框中将 Name 修改为 cal_u16%s', name, name);

    elseif contains(msg, '通用占位')
        % Generic name fix
        sug.suggestion = sprintf('将 "%s" 替换为有业务含义的名称', name);
        sug.example = sprintf('例如将 "%s" 改为 SpeedController / FilterStage / LogicGate 等', name);

    elseif contains(msg, '基本命名')
        sug.suggestion = sprintf('名称 "%s" 包含非法字符，请只使用 A-Z、a-z、0-9 和下划线', name);
        sug.command = sprintf('在模块属性中将 "%s" 改为合法名称', name);

    else
        sug.suggestion = sprintf('请检查 "%s" 是否符合项目命名规范', name);
    end
end

function sug = suggestConnectionFix(msg)
% Suggest fix for connection integrity issues
    sug = struct();
    sug.category = 'connection';
    sug.severity = 'major';

    if contains(msg, '悬空') || contains(msg, '未完成')
        sug.issue = msg;
        sug.suggestion = '找到悬空信号线，将其连接到目标模块端口，或删除未使用的线';
        sug.command = '在模型中用鼠标点击悬空线 → 拖拽到目标端口，或按 Delete 删除';
    elseif contains(msg, '输入端口') && contains(msg, '未连接')
        tokens = regexp(msg, '".*?"', 'match');
        if ~isempty(tokens)
            portName = strrep(tokens{1}, '"', '');
            sug.issue = msg;
            sug.suggestion = sprintf('输入端口 %s 未连接信号源，请接入正确的信号或添加 Ground 模块占位', portName);
            sug.command = sprintf('从信号源拖线到 %s，或添加 Simulink/Sources/Ground 模块', portName);
        end
    elseif contains(msg, '输出端口') && contains(msg, '未连接')
        tokens = regexp(msg, '".*?"', 'match');
        if ~isempty(tokens)
            portName = strrep(tokens{1}, '"', '');
            sug.issue = msg;
            sug.suggestion = sprintf('输出端口 %s 未连接，请接入下游模块或添加 Terminator 占位', portName);
            sug.command = sprintf('从 %s 拖线到目标模块，或添加 Simulink/Sinks/Terminator', portName);
        end
    else
        sug.issue = msg;
        sug.suggestion = '检查模型连线，确保所有端口都已正确连接';
    end
end

function sug = suggestHierarchyFix(msg)
% Suggest fix for hierarchy issues
    sug = struct();
    sug.category = 'hierarchy';
    sug.severity = 'major';

    if contains(msg, '嵌套深度')
        tokens = regexp(msg, '\d+', 'match');
        if numel(tokens) >= 2
            sug.issue = msg;
            sug.suggestion = sprintf('子系统嵌套过深（%s层），建议将深层逻辑提取为独立的参考模型或简化层次结构', tokens{2});
            sug.command = '使用 Model Reference 替代深层嵌套的 Subsystem';
        end
    elseif contains(msg, '游离')
        tokens = regexp(msg, '".*?"', 'match');
        if ~isempty(tokens)
            sug.issue = msg;
            sug.suggestion = sprintf('模块 %s 为游离模块，请将其移入正确的父级子系统', strrep(tokens{1}, '"', ''));
        end
    else
        sug.issue = msg;
        sug.suggestion = '检查模型层次结构是否合理';
    end
end

function sug = suggestDatatypeFix(msg)
% Suggest fix for data type issues
    sug = struct();
    sug.category = 'datatype';
    sug.severity = 'major';

    tokens = regexp(msg, '".*?"', 'match');
    if ~isempty(tokens)
        portName = strrep(tokens{1}, '"', '');
        sug.issue = msg;

        % Try to infer the correct type from the port name
        inferredType = inferTypeFromName(portName);
        if ~isempty(inferredType)
            sug.suggestion = sprintf('端口 "%s" 的数据类型未显式定义，请在模块属性中将 OutDataTypeStr 设置为 "%s"', portName, inferredType);
            sug.command = sprintf('选中 "%s" → Ctrl+I → 信号属性 → 将 Output data type 设为 %s', portName, inferredType);
            sug.example = sprintf('或使用 /setPortTypes 自动批量设置');
        else
            sug.suggestion = sprintf('端口 "%s" 的数据类型未显式定义，请在模块属性中明确设置数据类型', portName);
            sug.command = sprintf('选中 "%s" → Ctrl+I → 信号属性 → 设置 Output data type', portName);
        end
    else
        sug.issue = msg;
        sug.suggestion = '明确设置端口数据类型，避免使用 Inherit: auto';
    end
end

function sug = suggestAIReviewFix(msg)
% Suggest fix for AI review findings
    sug = struct();
    sug.category = 'ai_review';
    sug.severity = 'minor';
    sug.issue = msg;

    if contains(msg, 'Terminator') || contains(msg, 'Ground')
        sug.suggestion = '检查 Terminator/Ground 模块对应的端口是否已完成连接，完成后可删除占位模块';
    elseif contains(msg, 'Scope')
        sug.suggestion = 'Scope 模块用于调试，代码生成前应删除或通过模型设置禁用';
        sug.command = '删除 Scope 模块，或设置其参数为 "Display time" off';
    elseif contains(msg, 'From') && contains(msg, 'Goto')
        sug.suggestion = '检查所有 From/Goto 标签是否配对，确保标签名称一致且无拼写错误';
        sug.command = '使用 Model Explorer 搜索所有 From/Goto 块，核对标签名';
    elseif contains(msg, '子系统') || contains(msg, '扁平')
        sug.suggestion = '建议将功能模块封装为子系统，提高模型可读性和可维护性';
    else
        sug.suggestion = '请人工审查此 AI 建议';
    end
end

function typeName = inferTypeFromName(name)
% Infer data type from signal name prefix
    prefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};
    types = {'int8','int16','int32','int64','uint8','uint16','uint32','uint64','single','double','half','boolean','boolean'};

    for i = 1:numel(prefixes)
        if startsWith(name, prefixes{i})
            % Check it's followed by a letter (not part of a longer word)
            rest = name(length(prefixes{i})+1:end);
            if ~isempty(rest) && isletter(rest(1))
                typeName = types{i};
                return;
            end
        end
    end
    % Also check cal_ prefix
    if startsWith(name, 'cal_')
        rest = name(5:end);
        for i = 1:numel(prefixes)
            if startsWith(rest, prefixes{i})
                typeName = types{i};
                return;
            end
        end
    end
    typeName = '';
end

function suggestions = addActionPlan(suggestions)
% Add a prioritized action plan at the end
    if isempty(suggestions)
        return;
    end

    % Count by severity
    nCrit = sum(arrayfun(@(s) strcmp(s.severity, 'critical'), suggestions));
    nMaj = sum(arrayfun(@(s) strcmp(s.severity, 'major'), suggestions));
    nMin = sum(arrayfun(@(s) strcmp(s.severity, 'minor'), suggestions));

    plan = struct();
    plan.severity = 'info';
    plan.category = 'action_plan';
    plan.issue = sprintf('共 %d 个问题（%d critical, %d major, %d minor）', ...
        numel(suggestions), nCrit, nMaj, nMin);

    % Build action plan text
    lines = {};
    lines{end+1} = '【修改优先级建议】';
    lines{end+1} = '';
    if nCrit > 0
        lines{end+1} = '🔴 第1优先级（critical）：必须先修复';
        lines{end+1} = '   影响：代码生成失败或模型无法编译';
        lines{end+1} = '   建议：立即处理，修复后重新 Review';
        lines{end+1} = '';
    end
    if nMaj > 0
        lines{end+1} = '🟠 第2优先级（major）：建议尽快修复';
        lines{end+1} = '   影响：可能导致功能异常或不符合规范';
        lines{end+1} = '   建议：在本轮迭代中修复';
        lines{end+1} = '';
    end
    if nMin > 0
        lines{end+1} = '🟡 第3优先级（minor）：可延后处理';
        lines{end+1} = '   影响：代码质量或可读性';
        lines{end+1} = '   建议：在代码生成前统一清理';
        lines{end+1} = '';
    end
    lines{end+1} = '【快速修复工具】';
    lines{end+1} = '  /setPortTypes   → 自动修正端口数据类型';
    lines{end+1} = '  /autoLayout     → 自动布局对齐';
    lines{end+1} = '  /checkModel     → 零误差门限验证';
    lines{end+1} = '';

    plan.suggestion = strjoin(lines, newline);
    suggestions{end+1} = plan; %#ok<AGROW>
end
