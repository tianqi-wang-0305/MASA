function Excel2Port()
% 定义全局变量
global ModelSignalName Direction SignalType InitialValue;
% 设置全局变量的值
ModelSignalName = 'ModelSignalName';
Direction = 'Direction';
SignalType = 'SignalType';
InitialValue = 'InitialValue';
% Excel 文件路径
pathToExcel = 'D:\PowerSAR\tools\test_HGQ\TMS_ASW_Interface_20251106_R1.xlsx'; % 请根据需要修改路径
% 指定需要遍历的工作表名称
specifiedSheets = {'Sys_ComIf', 'Sys_IoIf'};  % 根据需要修改工作表名称
% 创建或打开 Simulink 模型
% ==================================================================
% 创建带时间戳的模型名称
% ==================================================================
% 自定义模型名前缀（可修改）
modelPrefix = 'TMS';  % << 修改此处自定义前缀 >>
% 生成时间戳 (格式: yyyymmdd_HHMMSS)
timeStamp = datestr(now, 'yyyymmdd_HHMM');
% 组合完整模型名
modelName = [modelPrefix '_' timeStamp];
% ==================================================================
if ~bdIsLoaded(modelName)
    new_system(modelName);
    open_system(modelName);
else
    open_system(modelName);
end
% 定义位置参数
inputXPos = 50;        % 输入块的 x 坐标
outputXPos = 1250;      % 输出块的 x 坐标
intermediateXPosIn = 250;  % Terminator模块的x坐标
intermediateXPosOut = 1000;  % Ground模块的x坐标
verticalSpacing = 50;  % 块之间的垂直间距
% 分别维护输入和输出的当前Y坐标
overallInputCurrentY = 100;   % 输入块的初始Y坐标
overallOutputCurrentY = 100;  % 输出块的初始Y坐标
% 遍历指定的工作表
for sheetIndex = 1:length(specifiedSheets)
    sheetName = specifiedSheets{sheetIndex};  % 当前工作表名称
    
    % 尝试读取Excel数据
    try
        data = readtable(pathToExcel, 'Sheet', sheetName);
    catch ME
        disp(['Error reading sheet ' sheetName ': ' ME.message]);
        continue;  % 跳过此工作表
    end
    
    % 去除列名中的空格
    data.Properties.VariableNames = strtrim(data.Properties.VariableNames);
    % 检查必要的列是否存在
    requiredColumns = {ModelSignalName, Direction, SignalType};
    if ~all(ismember(requiredColumns, data.Properties.VariableNames))
        disp(['Missing required columns in sheet ' sheetName]);
        disp(data.Properties.VariableNames);  % 输出当前列名
        continue;  % 跳过此工作表
    end
    
    % 每个工作表的输入和输出初始位置
    inputCurrentY = overallInputCurrentY;   % 输入的当前Y坐标
    outputCurrentY = overallOutputCurrentY;  % 输出的当前Y坐标
    % 遍历信号数据
    for i = 1:height(data)
        signal = data(i, :);
        % 获取信号名称，添加验证
        blockName = signal.(ModelSignalName){1};  % 获取信号名称
        blockPath = [modelName '/' blockName];  % 块的完整路径
        % 调用添加信号块的子函数（添加连接辅助模块的功能）
        [inputCurrentY, outputCurrentY] = addSignalBlock(signal, blockPath, ...
            inputCurrentY, outputCurrentY, inputXPos, intermediateXPosIn, outputXPos, ...
            intermediateXPosOut, verticalSpacing, modelName);
    end
    % 更新整体Y坐标基础
    overallInputCurrentY = inputCurrentY;   % 更新下一工作表的输入Y坐标
    overallOutputCurrentY = outputCurrentY;  % 更新下一工作表的输出Y坐标
end
% 布局与保存模型
% Simulink.BlockDiagram.arrangeSystem(modelName);
save_system(modelName);
disp(['Model ' modelName ' created and saved successfully.']);
end
function [inputCurrentY, outputCurrentY] = addSignalBlock(signal, blockPath, ...
inputCurrentY, outputCurrentY, inputXPos, terminatorXPos, outputXPos, ...
groundXPos, verticalSpacing, modelName)
global ModelSignalName Direction SignalType InitialValue;
try
    % 根据信号方向添加块
    if strcmpi(signal.(Direction), 'Rx')
        % 添加输入块
        add_block('simulink/Sources/In1', blockPath, ...
            'Position', [inputXPos, inputCurrentY, inputXPos + 30, inputCurrentY + 20]);
        
        % 设置数据类型
        set_param(blockPath, 'OutDataTypeStr', signal.(SignalType){1});
        % 设置初始值（仅对输入信号）
        if isfield(signal, InitialValue) && ~isempty(signal.(InitialValue))
            set_param(blockPath, 'Value', num2str(signal.(InitialValue)));
        end
        
        % 在输入端口右侧添加Terminator模块并连线
        terminatorName = [blockPath '_Terminator'];
        terminatorPos = [terminatorXPos, inputCurrentY, terminatorXPos + 30, inputCurrentY + 20];
        add_block('simulink/Sinks/Terminator', terminatorName, ...
                 'Position', terminatorPos);
        % 连接Inport到Terminator
        add_line(modelName, [get_param(blockPath, 'Name') '/1'], ...
                [get_param(terminatorName, 'Name') '/1'], ...
                'autorouting', 'smart');
        
        % 更新输入Y坐标
        inputCurrentY = inputCurrentY + verticalSpacing;
        
    elseif strcmpi(signal.(Direction), 'Tx')
        % 添加输出块
        add_block('simulink/Sinks/Out1', blockPath, ...
            'Position', [outputXPos, outputCurrentY, outputXPos + 30, outputCurrentY + 20]);
        
        % 设置数据类型
        set_param(blockPath, 'OutDataTypeStr', signal.(SignalType){1});
        
        % 在输出端口左侧添加Ground模块并连线
        groundName = [blockPath '_Ground'];
        groundPos = [groundXPos, outputCurrentY, groundXPos + 30, outputCurrentY + 20];
        add_block('simulink/Sources/Ground', groundName, ...
                 'Position', groundPos);
        % 连接Ground到Outport
        add_line(modelName, [get_param(groundName, 'Name') '/1'], ...
                [get_param(blockPath, 'Name') '/1'], ...
                'autorouting', 'smart');
        % 更新输出Y坐标
        outputCurrentY = outputCurrentY + verticalSpacing;
    else
        disp(['Unknown signal direction for ' blockPath]);
    end
    
catch ME
    % 出现错误时提示错误信息
    disp(['ERROR in addSignalBlock: ' ME.message]);
    rethrow(ME);
end
end