function feature2SignalEditor(featureFile, outputMat)
% feature2SignalEditor  将 Gherkin .feature 测试用例转为 Simulink.SimulationData.Dataset .mat 格式
%   解析 .feature 文件中的 Given inputs 刺激描述，生成 Signal Editor 可加载的数据文件。
%
%   输入:
%       featureFile  - .feature 文件路径
%       outputMat   - 输出 .mat 文件路径（可选，默认同目录下 *_stimulus.mat）
%
%   输出:
%       将 Simulink.SimulationData.Dataset 保存到 .mat 文件
%
%   用法:
%       % 单个 feature 文件转换
%       feature2SignalEditor('tests/Foc_2024b_NominalTests.feature');
%
%       % 指定输出路径
%       feature2SignalEditor('tests/test.feature', 'data/stimulus.mat');
%
%       % 批量转换目录下所有 .feature 文件
%       feature2SignalEditor(pwd);
%
%   支持的特征语法:
%       const(50)                     - 常值
%       step(0 -> 100 @ 2s)           - 阶跃
%       pulse(width=1s, period=5s)     - 脉冲
%       ramp(0 -> 100 over 5s)         - 斜坡
%       sine(amp=1, freq=0.5, phase=0) - 正弦
%       timeseries([t1 t2],[v1 v2])    - 自定义时序

    %% 输入处理
    arguments
        featureFile (1,1) string
        outputMat (1,1) string = ""
    end

    % 如果是目录，批量处理
    if exist(featureFile, 'dir')
        featureFiles = dir(fullfile(featureFile, '*.feature'));
        if isempty(featureFiles)
            error('No .feature files found in directory: %s', featureFile);
        end
        for i = 1:numel(featureFiles)
            fPath = fullfile(featureFile, featureFiles(i).name);
            oPath = fullfile(featureFile, ...
                strrep(featureFiles(i).name, '.feature', '_stimulus.mat'));
            feature2SignalEditor(fPath, oPath);
        end
        return;
    end

    if ~isfile(featureFile)
        error('Feature file not found: %s', featureFile);
    end

    if outputMat == ""
        [fDir, fName, ~] = fileparts(featureFile);
        outputMat = fullfile(fDir, fName + "_stimulus.mat");
    end

    fprintf('=== feature2SignalEditor ===\n');
    fprintf('Feature: %s\n', featureFile);
    fprintf('Output:  %s\n\n', outputMat);

    %% 1) 解析 .feature 文件
    featureText = string(fileread(featureFile));
    scenarios = parseFeatureScenarios(featureText);
    fprintf('Parsed %d scenario(s)\n\n', numel(scenarios));

    if isempty(scenarios)
        warning('No scenarios found in feature file.');
        return;
    end

    %% 2) 为每个 Scenario 生成 Dataset
    allDatasets = cell(1, numel(scenarios));
    allScenarioNames = strings(numel(scenarios), 1);

    for s = 1:numel(scenarios)
        sc = scenarios(s);
        allScenarioNames(s) = sc.title;

        % 创建 Dataset
        ds = Simulink.SimulationData.Dataset();
        ds.Name = matlab.lang.makeValidName(sc.title);

        % 遍历 Given inputs，生成对应信号
        for i = 1:size(sc.inputs, 1)
            signalName = sc.inputs{i, 1};
            stimulusExpr = sc.inputs{i, 2};
            simTime = sc.simTime;

            % 解析刺激表达式，生成 timeseries
            ts = parseStimulus(signalName, stimulusExpr, simTime);

            % 添加到 Dataset
            el = Simulink.SimulationData.Signal();
            el.Name = char(signalName);
            el.BlockPath = struct('BlockPath', '');
            el.PortType = 'inport';
            el.Values = ts;
            ds = ds.addElement(el);
        end

        allDatasets{s} = ds;
        fprintf('  [%d/%d] %s: %d signal(s)\n', ...
            s, numel(scenarios), sc.title, size(sc.inputs, 1));
    end

    %% 3) 保存 .mat 文件
    % 主 Dataset 包含所有场景
    if numel(scenarios) == 1
        root = allDatasets{1};
    else
        root = Simulink.SimulationData.Dataset();
        root.Name = 'root';
        for s = 1:numel(scenarios)
            root = root.addElement(allDatasets{s});
        end
    end

    % 额外保存每个场景的独立变量，方便按名称引用
    signalEditorData = struct();
    signalEditorData.root = root;
    for s = 1:numel(scenarios)
        varName = matlab.lang.makeValidName(allScenarioNames(s));
        signalEditorData.(varName) = allDatasets{s};
    end

    save(outputMat, '-struct', 'signalEditorData');
    fprintf('\nSaved: %s\n', outputMat);
    fprintf('  root: Simulink.SimulationData.Dataset (%d scenario(s))\n', numel(scenarios));
    for s = 1:numel(scenarios)
        varName = matlab.lang.makeValidName(allScenarioNames(s));
        fprintf('  %s: Simulink.SimulationData.Dataset (%d signal(s))\n', ...
            varName, allDatasets{s}.numElements);
    end
    fprintf('\nDone.\n');
end

%% ================== Feature 文件解析 ==================

function scenarios = parseFeatureScenarios(featureText)
% 解析 .feature 文件，提取每个 Scenario 的 Given inputs
    scenarios = struct('title', {}, 'description', {}, 'inputs', {}, 'simTime', {});

    % 提取默认仿真时间（从 When 语句）
    defaultSimTime = 10.0; % seconds
    whenMatch = regexpi(featureText, ...
        'When\s+simulate\s+for\s+([\d.]+)\s*s', 'tokens', 'once');
    if ~isempty(whenMatch) && ~isempty(whenMatch{1})
        defaultSimTime = str2double(whenMatch{1});
        if isnan(defaultSimTime) || defaultSimTime <= 0
            defaultSimTime = 10.0;
        end
    end

    % 按 Feature: 行分割
    parts = split(featureText, newline);

    % 提取每个 Scenario
    scenarioIdx = 0;
    inScenario = false;
    currentTitle = "";
    currentDesc = "";
    currentInputs = cell(0, 2);
    currentSimTime = defaultSimTime;

    for i = 1:numel(parts)
        line = strtrim(parts(i));

        % 跳过空行和注释
        if strlength(line) == 0 || startsWith(line, '#') || startsWith(line, '//')
            continue;
        end

        % 新 Scenario 开始
        scMatch = regexpi(line, '^Scenario:\s*(.+)', 'tokens', 'once');
        if ~isempty(scMatch)
            % 保存前一个 Scenario
            if inScenario && ~isempty(currentInputs)
                scenarioIdx = scenarioIdx + 1;
                scenarios(scenarioIdx) = struct(...
                    'title', currentTitle, ...
                    'description', currentDesc, ...
                    'inputs', {currentInputs}, ...
                    'simTime', currentSimTime); %#ok<AGROW>
            end

            % 开始新 Scenario
            inScenario = true;
            currentTitle = strtrim(string(scMatch{1}));
            currentDesc = "";
            currentInputs = cell(0, 2);
            currentSimTime = defaultSimTime;
            continue;
        end

        if ~inScenario
            continue;
        end

        % Description
        descMatch = regexpi(line, '^\s*Description:\s*(.+)', 'tokens', 'once');
        if ~isempty(descMatch)
            currentDesc = strtrim(string(descMatch{1}));
            continue;
        end

        % Given inputs - 解析 "  * signalName = stimulus"
        inputMatch = regexpi(line, '^\s*\*\s+(\w+)\s*=\s*(.+)', 'tokens', 'once');
        if ~isempty(inputMatch)
            signalName = strtrim(string(inputMatch{1}));
            stimulus = strtrim(string(inputMatch{2}));
            currentInputs(end+1, :) = {signalName, stimulus}; %#ok<AGROW>
            continue;
        end

        % When simulate - 可能有更具体的仿真时间
        whenMatch2 = regexpi(line, ...
            'When\s+simulate\s+for\s+([\d.]+)\s*s', 'tokens', 'once');
        if ~isempty(whenMatch2) && ~isempty(whenMatch2{1})
            customTime = str2double(whenMatch2{1});
            if ~isnan(customTime) && customTime > 0
                currentSimTime = customTime;
            end
            continue;
        end
    end

    % 保存最后一个 Scenario
    if inScenario && ~isempty(currentInputs)
        scenarioIdx = scenarioIdx + 1;
        scenarios(scenarioIdx) = struct(...
            'title', currentTitle, ...
            'description', currentDesc, ...
            'inputs', {currentInputs}, ...
            'simTime', currentSimTime); %#ok<AGROW>
    end
end

%% ================== 刺激表达式解析 ==================

function ts = parseStimulus(signalName, expr, simTime)
% 解析刺激表达式，返回 timeseries 对象
%   支持的语法:
%     const(value)
%     step(from -> to @ time)
%     pulse(width=..., period=..., delay=...)
%     ramp(from -> to over duration)
%     sine(amp=..., freq=..., phase=..., offset=...)
%     timeseries(timeVec, valueVec)

    expr = strtrim(string(expr));

    % 1) const
    if startsWith(expr, 'const(', 'IgnoreCase', true)
        ts = parseConst(expr, simTime);
        return;
    end

    % 2) step
    if startsWith(expr, 'step(', 'IgnoreCase', true)
        ts = parseStep(expr, simTime);
        return;
    end

    % 3) pulse
    if startsWith(expr, 'pulse(', 'IgnoreCase', true)
        ts = parsePulse(expr, simTime);
        return;
    end

    % 4) ramp
    if startsWith(expr, 'ramp(', 'IgnoreCase', true)
        ts = parseRamp(expr, simTime);
        return;
    end

    % 5) sine
    if startsWith(expr, 'sine(', 'IgnoreCase', true)
        ts = parseSine(expr, simTime);
        return;
    end

    % 6) timeseries
    if startsWith(expr, 'timeseries(', 'IgnoreCase', true)
        ts = parseTimeseries(expr, simTime);
        return;
    end

    % 7) 未知格式：尝试由数据类型推断
    warning('Unknown stimulus expression "%s" for signal "%s". Using const(0).', expr, signalName);
    ts = parseConst('const(0)', simTime);
end

%% ================== 各类型解析器 ==================

function ts = parseConst(expr, simTime)
% const(50) → 常值 timeseries
    value = extractNumericArg(expr, 'const');
    if isnan(value)
        value = 0;
    end
    ts = createStepTimeseries(value, value, 0, simTime);
end

function ts = parseStep(expr, simTime)
% step(0 -> 100 @ 2s) → 阶跃
    inner = extractInner(expr, 'step');
    tokens = regexp(inner, '([\d.\-+eE]+)\s*->\s*([\d.\-+eE]+)\s*@\s*([\d.]+)\s*s?', 'tokens');
    if isempty(tokens)
        ts = parseConst('const(0)', simTime);
        return;
    end
    fromVal = str2double(tokens{1}{1});
    toVal = str2double(tokens{1}{2});
    stepTime = str2double(tokens{1}{3});

    if isnan(fromVal), fromVal = 0; end
    if isnan(toVal), toVal = 100; end
    if isnan(stepTime), stepTime = simTime * 0.2; end

    ts = createStepTimeseries(fromVal, toVal, stepTime, simTime);
end

function ts = parsePulse(expr, simTime)
% pulse(width=1s, period=5s, delay=0s) → 脉冲
    params = parseParams(expr, 'pulse');
    width = getParam(params, 'width', 1.0);
    period = getParam(params, 'period', simTime);
    delay = getParam(params, 'delay', 0.0);

    % 生成脉冲序列
    numPeriods = ceil((simTime - delay) / period);
    if numPeriods < 1
        % 单脉冲
        t = [0, delay, delay + width, simTime];
        v = [0, 0, 1, 0];
    else
        segs = cell(numPeriods * 2 + 1, 2);
        segIdx = 1;
        segs{segIdx, 1} = 0;
        segs{segIdx, 2} = 0;
        segIdx = segIdx + 1;

        for p = 1:numPeriods
            startT = delay + (p - 1) * period;
            if startT > simTime
                break;
            end
            endT = min(startT + width, simTime);
            segs{segIdx, 1} = startT;
            segs{segIdx, 2} = 1;
            segIdx = segIdx + 1;
            segs{segIdx, 1} = endT;
            segs{segIdx, 2} = 0;
            segIdx = segIdx + 1;
        end

        t = zeros(segIdx - 1, 1);
        v = zeros(segIdx - 1, 1);
        for i = 1:(segIdx - 1)
            t(i) = segs{i, 1};
            v(i) = segs{i, 2};
        end
    end

    % 确保不超过 simTime
    t = min(t, simTime);
    t = unique([t(:); simTime]);
    v = interp1(t, v, t, 'previous');

    ts = timeseries(v(:), t(:));
    ts.Name = 'pulse';
    ts.TimeInfo.Units = 'seconds';
end

function ts = parseRamp(expr, simTime)
% ramp(0 -> 100 over 5s) → 斜坡
    inner = extractInner(expr, 'ramp');
    tokens = regexp(inner, '([\d.\-+eE]+)\s*->\s*([\d.\-+eE]+)\s*over\s*([\d.]+)\s*s?', 'tokens');
    if isempty(tokens)
        ts = parseConst('const(0)', simTime);
        return;
    end
    fromVal = str2double(tokens{1}{1});
    toVal = str2double(tokens{1}{2});
    duration = str2double(tokens{1}{3});

    if isnan(fromVal), fromVal = 0; end
    if isnan(toVal), toVal = 100; end
    if isnan(duration) || duration <= 0, duration = simTime; end

    rampEnd = min(duration, simTime);
    % 1000 点采样以保持平滑
    nPoints = 1000;
    t = linspace(0, simTime, nPoints)';
    v = fromVal + (toVal - fromVal) * min(t / rampEnd, 1);

    ts = timeseries(v(:), t(:));
    ts.Name = 'ramp';
    ts.TimeInfo.Units = 'seconds';
end

function ts = parseSine(expr, simTime)
% sine(amp=1, freq=0.5, phase=0, offset=0, bias=0) → 正弦
    params = parseParams(expr, 'sine');
    amp = getParam(params, 'amp', 1.0);
    freq = getParam(params, 'freq', 0.5);
    phase = getParam(params, 'phase', 0.0);
    offset = getParam(params, 'offset', 0.0);
    bias = getParam(params, 'bias', NaN);

    if ~isnan(bias)
        offset = bias;
    end

    % 每个周期至少 20 个点
    nPoints = max(100, ceil(freq * simTime * 20));
    t = linspace(0, simTime, nPoints)';
    v = offset + amp * sin(2 * pi * freq * t + phase);

    ts = timeseries(v(:), t(:));
    ts.Name = 'sine';
    ts.TimeInfo.Units = 'seconds';
end

function ts = parseTimeseries(expr, simTime)
% timeseries([0 1 2 3], [0 10 10 0]) → 自定义时序
    inner = extractInner(expr, 'timeseries');
    % 匹配两个方括号数组
    tokens = regexp(inner, '\[([^\]]+)\]\s*,\s*\[([^\]]+)\]', 'tokens');
    if isempty(tokens)
        % 尝试匹配圆括号
        tokens = regexp(inner, '\(([^\)]+)\)\s*,\s*\(([^\)]+)\)', 'tokens');
    end
    if isempty(tokens)
        ts = parseConst('const(0)', simTime);
        return;
    end

    tVec = str2num(tokens{1}{1}); %#ok<ST2NM>
    vVec = str2num(tokens{1}{2}); %#ok<ST2NM>

    if isempty(tVec) || isempty(vVec)
        ts = parseConst('const(0)', simTime);
        return;
    end

    % 确保时间递增
    tVec = tVec(:);
    vVec = vVec(:);

    % 如果数据不足，用最后一个值填充到 simTime
    if tVec(end) < simTime
        tVec = [tVec; simTime];
        vVec = [vVec; vVec(end)];
    end

    ts = timeseries(vVec(:), tVec(:));
    ts.Name = 'timeseries';
    ts.TimeInfo.Units = 'seconds';
end

%% ================== 通用辅助函数 ==================

function ts = createStepTimeseries(fromVal, toVal, stepTime, simTime)
% 创建阶跃 timeseries
    epsilon = max(simTime * 1e-6, 1e-6);
    t = [0; stepTime; stepTime + epsilon; simTime];
    v = [fromVal; fromVal; toVal; toVal];
    ts = timeseries(v, t);
    ts.Name = 'step';
    ts.TimeInfo.Units = 'seconds';
end

function inner = extractInner(expr, funcName)
% 提取函数括号内的内容
    pattern = funcName + "\(";
    startIdx = strfind(lower(expr), lower(pattern));
    if isempty(startIdx)
        inner = expr;
        return;
    end
    inner = extractBetween(expr, startIdx(1) + strlength(char(pattern)), strlength(expr) - 1);
    if isempty(inner)
        inner = expr;
    else
        inner = strtrim(string(inner));
    end
end

function value = extractNumericArg(expr, funcName)
% 提取单个数值参数
    inner = extractInner(expr, funcName);
    % 去掉尾部的闭合括号
    if endsWith(inner, ')')
        inner = extractBefore(inner, strlength(inner));
    end
    value = str2double(strtrim(inner));
end

function params = parseParams(expr, funcName)
% 解析 key=value 参数表
    inner = extractInner(expr, funcName);
    params = struct();

    % 提取所有 key=value 对
    tokens = regexp(inner, '(\w+)\s*=\s*([\d.+\-eE]+)\s*s?', 'tokens');
    for i = 1:numel(tokens)
        key = strtrim(tokens{i}{1});
        val = str2double(tokens{i}{2});
        params.(key) = val;
    end
end

function value = getParam(params, name, default)
% 从 params 结构获取参数值
    if isfield(params, name)
        value = params.(name);
        if isnan(value)
            value = default;
        end
    else
        value = default;
    end
end
