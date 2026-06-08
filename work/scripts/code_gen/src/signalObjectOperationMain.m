function signalObjectOperationMain()
% SIGNALOBJECTOPERATIONMAIN 信号线与SignalObject绑定操作主程序
% 支持两种操作：1.绑定信号(配置信号线绑定及AUTOSAR属性) 2.解除信号绑定(取消MustResolveToSignalObject+清理文件/变量)

% ===================== 功能选择：绑定信号 / 解除信号绑定 =====================
% 弹出选择对话框，让用户选择执行的操作
operationChoice = questdlg(...
    '请选择要执行的操作：', ...
    '操作选择', ...
    '绑定信号', ...
    '解除信号绑定', ...
    '绑定信号');  % 默认选择“绑定信号”

% 根据用户选择执行对应操作
switch operationChoice
    case '绑定信号'
        % 调用配置绑定函数（可传入是否清空base workspace，默认true）
        addlinesignalandobject(true);
    case '解除信号绑定'
        % 调用取消绑定函数（新增清理逻辑）
        unset_signal_must_resolve();
end

end

% ------------------------------ 子函数1：绑定信号（原addlinesignalandobject逻辑） ------------------------------
function addlinesignalandobject(clearBase)
% addlinesignalandobject(clearBase)
% - 按 Y 坐标将选中的 Inport/Outport 与 信号线 一一配对
% - 为信号线设置 Name，并把 MustResolveToSignalObject 设为 'on'
% - 尝试识别端口的数据类型（Data Type），将该类型写入到创建的 Simulink.Signal.DataType
% - 识别端口维度（Dimensions），写入 Simulink.Signal.Dimensions；若默认/继承则记为 -1
% - 仅在 base workspace 中创建这些必要的 Simulink.Signal 变量
% - 生成 <model>_signals.m，可执行 m 文件以便恢复这些变量及其 DataType 与 Dimensions
%
% 参数：
% clearBase (可选, logical) - 是否在开始时清空 base workspace（默认 true）
%
% 注意：
% - 若要获得编译后的端口类型（Compiled types）与维度，需先更新模型（Ctrl+D 或 set_param(model,'SimulationCommand','update')）。
%   脚本会尝试读取编译信息（若可用），否则回退到块的可用参数。
if nargin < 1
    clearBase = true;
end

model = bdroot;
if isempty(model)
    error('请先打开一个 Simulink 模型。');
end

% 可选：清空 base workspace（按你的需求）
if clearBase
    try
        evalin('base','clear');
    catch ME
        warning('清空 base workspace 失败：%s', ME.message);
    end
end

% 获取当前选中对象（blocks/lines）
sel = find_system(model, 'FindAll', 'on', 'Selected', 'on');

% 在函数局部区分端口与信号线
portH = [];
lineH = [];
for i = 1:numel(sel)
    h = sel(i);
    try
        bt = get_param(h,'BlockType');
        if ismember(bt, {'Inport','Outport'})
            portH(end+1) = h; %#ok<SAGROW>
            continue;
        end
    catch
        % ignore
    end
    try
        if strcmp(get(h,'Type'),'line')
            lineH(end+1) = h; %#ok<SAGROW>
        end
    catch
        % ignore
    end
end

if isempty(portH) || isempty(lineH)
    error('请同时选中端口和信号线。');
end
if numel(portH) ~= numel(lineH)
    error('端口与信号线数量不一致，请选中相同数量的端口与线。');
end

% 计算用于配对的 Y 值
portY = zeros(numel(portH),1);
for k = 1:numel(portH)
    pos = get_param(portH(k),'Position'); % [left top right bottom]
    portY(k) = pos(2);
end
lineY = zeros(numel(lineH),1);
for k = 1:numel(lineH)
    pts = get(lineH(k),'Points');
    if isempty(pts)
        lineY(k) = NaN;
    else
        lineY(k) = pts(1,2);
    end
end

[~, pIdx] = sort(portY);
[~, lIdx] = sort(lineY);

created = cell(0,4); % {varname, originalSignalName, dataType, dimensions}

% 主循环：配对、命名、开启 MustResolveToSignalObject、识别 DataType/Dimensions、创建 workspace 变量
for i = 1:numel(portH)
    ph = portH(pIdx(i));
    lh = lineH(lIdx(i));

    % 获取端口名称
    try
        sigName = get_param(ph, 'Name');
    catch
        sigName = '';
    end
    if isempty(sigName)
        warning('端口句柄 %g 名称为空，跳过该配对。', ph);
        continue;
    end

    % 给线命名
    try
        set_param(lh, 'Name', sigName);
    catch
        try
            set(lh, 'Name', sigName);
        catch
            warning('无法为线句柄 %g 设置 Name。', lh);
        end
    end

    % 设置 MustResolveToSignalObject = 'on'
    try
        set_param(lh, 'MustResolveToSignalObject', 'on');
    catch
        try
            set(lh, 'MustResolveToSignalObject', true);
        catch
            warning('无法为线句柄 %g 设置 MustResolveToSignalObject。', lh);
        end
    end

    % 识别端口数据类型与维度
    dt = tryGetPortDataType(ph, model);
    dim = tryGetPortDimensions(ph, model); % 数值或 -1

    % 在 base workspace 中创建 Simulink.Signal 并写入 DataType/Dimensions
    varname = matlab.lang.makeValidName(sigName);
    try
        sigObj = Simulink.Signal;
        % DataType
        if ~isempty(dt)
            try
                sigObj.DataType = dt;
            catch
                warning('无法将 DataType "%s" 赋给 Simulink.Signal 对象（变量 %s）。', dt, varname);
            end
        end
        % Dimensions（默认/继承 -> -1）
        try
            sigObj.Dimensions = dim;
        catch ME
            warning('无法设置 Dimensions %s 到变量 %s：%s', mat2str(dim), varname, ME.message);
        end

        sigObj.Description = sprintf('Signal from model "%s", original name "%s"', model, sigName);
        assignin('base', varname, sigObj);
        created(end+1,1) = {varname}; %#ok<SAGROW>
        created(end,2) = {sigName};
        created(end,3) = {dt};
        created(end,4) = {dim};
        fprintf('信号线 %g 已设名: %s, DataType: %s, Dimensions: %s\n', ...
            lh, sigName, ternary(dt, '<unknown>', dt), dimToStr(dim));
    catch ME
        warning('创建 workspace 变量 %s 失败：%s', varname, ME.message);
    end
end

% 生成可执行 m 文件以恢复这些变量（含 DataType 与 Dimensions）
if ~isempty(created)
    safeModelName = matlab.lang.makeValidName(model);
    outFile = fullfile(pwd, [safeModelName, '_signals.m']);
    fid = fopen(outFile,'w');
    if fid == -1
        warning('无法在当前目录创建文件 %s，请检查权限。', outFile);
    else
        fprintf(fid, '%% 自动生成：在 base workspace 中创建 Simulink.Signal 变量 - 模型 %s\n', model);
        fprintf(fid, '%% 运行此文件将在当前工作区中创建下列 Simulink.Signal 变量（包含 DataType 与 Dimensions，如能设置）\n\n');
        for k = 1:size(created,1)
            v = created{k,1};
            orig = created{k,2};
            dt = created{k,3};
            dim = created{k,4};
            fprintf(fid, '%s = Simulink.Signal;\n', v);
            if ~isempty(dt)
                escdt = strrep(dt, '''', '''''');
                fprintf(fid, '%s.DataType = ''%s'';\n', v, escdt);
            end
            % 写入 Dimensions（数值或 -1）
            fprintf(fid, '%s.Dimensions = %s;\n', v, dimsLiteral(dim));
            escOrig = strrep(orig, '''', '''''');
            fprintf(fid, '%s.Description = ''Original signal name: %s'';\n\n', v, escOrig);
        end
        fclose(fid);
        fprintf('已生成 m 文件：%s\n', outFile);
    end
else
    disp('未创建任何 workspace 变量，未生成 m 文件。');
end

end

% ------------------------------ 子函数2：解除信号绑定（新增清理.m文件/工作区变量逻辑） ------------------------------
function unset_signal_must_resolve()
% unset_signal_must_resolve
% 取消选中信号线的 MustResolveToSignalObject 属性（解除信号绑定）
% 新增：清理对应.m文件中的信号变量 + 清除base workspace中的对应变量

model = bdroot;
if isempty(model)
    error('请先打开一个Simulink模型。');
end

sel = find_system(model, 'FindAll', 'on', 'Selected', 'on');

% 过滤出信号线
isLine = false(size(sel));
for i = 1:length(sel)
    try
        if strcmp(get(sel(i), 'Type'), 'line')
            isLine(i) = true;
        end
    catch
        % 不是line，忽略
    end
end

lineHandles = sel(isLine);

if isempty(lineHandles)
    error('请至少选中一条信号线。');
end

% 收集需要清理的信号名称
signalNamesToClean = {};
for i = 1:length(lineHandles)
    lh = lineHandles(i);
    try
        % 1. 取消MustResolveToSignalObject属性
        set(lh, 'MustResolveToSignalObject', false);
        sigName = get(lh, 'Name'); % 获取信号线名称
        if ~isempty(sigName)
            signalNamesToClean{end+1} = matlab.lang.makeValidName(sigName); % 转为合法变量名
        end
        fprintf('信号线 %d 已取消勾选MustResolveToSignalObject（解除绑定），信号名：%s\n', lh, sigName);
    catch ME
        fprintf('句柄 %d 无法解除信号绑定，原因：%s\n', lh, ME.message);
    end
end

% 2. 清理base workspace中的对应信号变量
if ~isempty(signalNamesToClean)
    try
        for i = 1:length(signalNamesToClean)
            varName = signalNamesToClean{i};
            % 检查变量是否存在，存在则删除
            if evalin('base', ['exist(''', varName, ''',''var'')']) == 1
                evalin('base', ['clear ', varName]);
                fprintf('已清除base workspace中的信号变量：%s\n', varName);
            end
        end
    catch ME
        warning('清理base workspace变量失败：%s', ME.message);
    end
end

% 3. 清理模型对应的_signals.m文件中的对应信号
safeModelName = matlab.lang.makeValidName(model);
signalMFile = fullfile(pwd, [safeModelName, '_signals.m']);
if exist(signalMFile, 'file') == 2 % 文件存在
    try
        % 读取.m文件内容
        fid = fopen(signalMFile, 'r');
        fileContent = fread(fid, '*char')';
        fclose(fid);

        % 逐个删除对应信号的代码块
        cleanedContent = fileContent;
        for i = 1:length(signalNamesToClean)
            varName = signalNamesToClean{i};
            % 匹配信号变量的代码块（格式：var = Simulink.Signal; ... 空行）
            pattern = [varName, ' = Simulink\.Signal;[\s\S]*?\n\n'];
            cleanedContent = regexprep(cleanedContent, pattern, '');
        end

        % 写入清理后的内容（若内容为空则删除文件）
        if isempty(strtrim(cleanedContent))
            delete(signalMFile);
            fprintf('已删除空的信号配置文件：%s\n', signalMFile);
        else
            fid = fopen(signalMFile, 'w');
            fwrite(fid, cleanedContent);
            fclose(fid);
            fprintf('已清理信号配置文件 %s 中的对应信号\n', signalMFile);
        end
    catch ME
        warning('清理信号配置文件 %s 失败：%s', signalMFile, ME.message);
    end
end

disp('批量解除信号绑定+清理完成!');
end

% ------------------------------ 辅助子函数（原addlinesignalandobject中的辅助函数） ------------------------------
function out = ternary(condTrueStr, fallback, actual)
% 如果 actual 为空返回 fallback，否则返回 actual（用于打印）
if isempty(actual)
    out = fallback;
else
    out = actual;
end
end

function s = dimToStr(dim)
% 维度用于日志显示
if isnumeric(dim)
    if isscalar(dim)
        s = num2str(dim);
    else
        s = mat2str(dim);
    end
else
    s = '<unknown>';
end
end

function lit = dimsLiteral(dim)
% 维度用于生成 m 文件的字面量
if isnumeric(dim)
    if isscalar(dim)
        lit = num2str(dim);
    else
        lit = mat2str(dim);
    end
else
    lit = '-1';
end
end

function dt = tryGetPortDataType(portHandle, model)
% 尝试多种方法读取端口的数据类型，返回字符串或空
dt = '';

% 优先尝试编译后类型
try
    dt = get_param(portHandle, 'CompiledPortDataType');
    if ischar(dt) && ~isempty(dt)
        return;
    end
catch
end

% 其他可能的属性
try
    c = get_param(portHandle, 'CompiledPortDataTypes');
    if ~isempty(c)
        if isstruct(c)
            f = fieldnames(c);
            if ~isempty(f)
                val = c.(f{1});
                if iscell(val) && ~isempty(val)
                    dt = val{1};
                    if ~isempty(dt), return; end
                elseif ischar(val)
                    dt = val;
                    return;
                end
            end
        elseif ischar(c)
            dt = c; return;
        elseif iscell(c) && ~isempty(c)
            dt = c{1}; return;
        end
    end
catch
end

% 回退参数
try
    dt = get_param(portHandle, 'OutDataTypeStr');
    if ischar(dt) && ~isempty(dt), return; end
catch
end
try
    dt = get_param(portHandle, 'PortDataType');
    if ischar(dt) && ~isempty(dt), return; end
catch
end
try
    dt = get_param(portHandle, 'DataType');
    if ischar(dt) && ~isempty(dt), return; end
catch
end

dt = ''; % 无法获取
end

function dim = tryGetPortDimensions(portHandle, model)
% 识别端口维度；若默认/继承则返回 -1
% 返回值：
%   - 标量数值（如 1、12）
%   - 数组维度向量（如 [1 12]）
%   - -1 表示继承/未知
dim = -1;

% 优先尝试编译后的维度（不同版本键名可能不同）
try
    cd = get_param(portHandle, 'CompiledPortDimensions');
    if ~isempty(cd)
        dim = normalizeDimValue(cd);
        if ~isempty(dim), return; end
    end
catch
end

% 部分版本直接提供已编译维度为结构或字符串
try
    c = get_param(portHandle, 'CompiledPortWidths');
    % 有些版本返回 width 数值（标量），将其作为总元素数
    if ~isempty(c) && isnumeric(c)
        if isscalar(c) && c > 0
            dim = c;
            return;
        end
    end
catch
end

% 回退到端口/块属性
% 常见参数：PortDimensions / Dimensions / OutPortDimensions / OutDimensions
candidates = {'PortDimensions','Dimensions','OutPortDimensions','OutDimensions'};
for k = 1:numel(candidates)
    try
        val = get_param(portHandle, candidates{k});
        if ~isempty(val)
            d = normalizeDimValue(val);
            if ~isempty(d)
                dim = d;
                return;
            end
        end
    catch
        % ignore
    end
end

% 仍无法获取 → -1 继承
dim = -1;
end

function d = normalizeDimValue(val)
% 将各种可能的维度表示归一化为：
%   - 标量数值 N
%   - 行向量 [a b ...]
%   - [] 表示无法解析（由调用者处理为 -1）
d = [];
try
    if isnumeric(val)
        if isscalar(val)
            d = val;
        elseif isvector(val)
            d = reshape(val, 1, []);
        else
            % 多维矩阵，取 size 作为维度向量
            d = size(val);
        end
        return;
    end
    if ischar(val)
        t = strtrim(val);
        if isempty(t)
            d = [];
            return;
        end
        % 若是类似 '[1 12]' 的文本
        if startsWith(t,'[') && endsWith(t,']')
            nums = regexp(t, '[-+]?\d+', 'match');
            if ~isempty(nums)
                d = str2double(nums);
                d = reshape(d,1,[]);
                return;
            end
        end
        % 若是纯数字
        if ~isempty(regexp(t, '^\s*[-+]?\d+\s*$', 'once'))
            d = str2double(t);
            return;
        end
        % 其它字符串无法解析
        d = [];
        return;
    end
    if iscell(val)
        % 有些属性返回 cell 包裹的维度/宽度
        for i = 1:numel(val)
            d = normalizeDimValue(val{i});
            if ~isempty(d), return; end
        end
        d = [];
        return;
    end
catch
    d = [];
end
end