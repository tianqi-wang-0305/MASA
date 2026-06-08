function export_simulink_top_ports(modelName, excelFileName)
    % 读取Simulink模型最外层(顶层)的输入和输出端口信息及其数据类型，并导出到Excel
    % 输入参数:
    %   modelName - Simulink模型名称
    %   excelFileName - 输出的Excel文件名
    
    % 示例用法:
    % export_simulink_top_ports('your_model_name', 'simulink_top_ports.xlsx');
    
    % 检查模型是否存在
    if ~exist([modelName '.slx'], 'file') && ~exist([modelName '.mdl'], 'file')
        error('模型 %s 不存在', modelName);
    end
    
    % 加载模型但不打开窗口
    load_system(modelName);
    modelLoaded = true;  % 标记模型已加载
    
    try
        % 获取模型中的所有输入和输出端口
        inputPorts = find_system(modelName, 'FindAll', 'on', 'BlockType', 'Inport');
        outputPorts = find_system(modelName, 'FindAll', 'on', 'BlockType', 'Outport');
        
        % 初始化结果单元格数组
        results = cell(1, 4);  % 标题行
        results(1, :) = {'端口类型', '端口模块名称', '信号名称', '数据类型'};
        currentRow = 2;
        
        % 处理输入端口 - 只保留顶层端口
        if ~isempty(inputPorts)
            for i = 1:length(inputPorts)
                portHandle = inputPorts(i);
                
                % 获取模块的完整路径
                fullPath = get_param(portHandle, 'Parent');
                
                % 判断是否为顶层模块 (父路径就是模型本身)
                if strcmp(fullPath, modelName)
                    % 获取端口模块名称
                    blockName = get_param(portHandle, 'Name');
                    
                    % 获取信号名称 - 兼容不同版本的方法
                    try
                        signalName = get_param(portHandle, 'SignalName');
                    catch
                        try
                            portNumber = get_param(portHandle, 'Port');
                            lineHandles = get_param(portHandle, 'LineHandles');
                            if ~isempty(lineHandles.Outport)
                                signalName = get_param(lineHandles.Outport, 'Name');
                            else
                                signalName = '未命名信号';
                            end
                        catch
                            signalName = '未命名信号';
                        end
                    end
                    if isempty(signalName)
                        signalName = '未命名信号';
                    end
                    
                    % 获取数据类型
                    try
                        dataType = get_param(portHandle, 'OutDataTypeStr');
                    catch
                        dataType = get_param(portHandle, 'DataTypeStr');
                    end
                    if isempty(dataType)
                        dataType = '默认类型';
                    end
                    
                    % 存储到结果中
                    results(currentRow, :) = {'输入', blockName, signalName, dataType};
                    currentRow = currentRow + 1;
                end
            end
        end
        
        % 处理输出端口 - 只保留顶层端口
        if ~isempty(outputPorts)
            for i = 1:length(outputPorts)
                portHandle = outputPorts(i);
                
                % 获取模块的完整路径
                fullPath = get_param(portHandle, 'Parent');
                
                % 判断是否为顶层模块 (父路径就是模型本身)
                if strcmp(fullPath, modelName)
                    % 获取端口模块名称
                    blockName = get_param(portHandle, 'Name');
                    
                    % 获取信号名称
                    try
                        signalName = get_param(portHandle, 'SignalName');
                    catch
                        try
                            portNumber = get_param(portHandle, 'Port');
                            lineHandles = get_param(portHandle, 'LineHandles');
                            if ~isempty(lineHandles.Inport)
                                signalName = get_param(lineHandles.Inport, 'Name');
                            else
                                signalName = '未命名信号';
                            end
                        catch
                            signalName = '未命名信号';
                        end
                    end
                    if isempty(signalName)
                        signalName = '未命名信号';
                    end
                    
                    % 获取数据类型
                    try
                        dataType = get_param(portHandle, 'OutDataTypeStr');
                    catch
                        dataType = get_param(portHandle, 'DataTypeStr');
                    end
                    if isempty(dataType)
                        dataType = '默认类型';
                    end
                    
                    % 存储到结果中
                    results(currentRow, :) = {'输出', blockName, signalName, dataType};
                    currentRow = currentRow + 1;
                end
            end
        end
        
        % 检查是否找到任何顶层端口
        if currentRow == 2  % 只包含标题行
            warning('在模型 %s 中未找到任何顶层输入或输出端口', modelName);
            % 关闭模型
            if modelLoaded
                close_system(modelName, 0); % 0表示不保存更改
            end
            return;
        end
        
        % 导出到Excel
        writecell(results, excelFileName);
        disp(['成功导出 ', num2str(currentRow - length(outputPorts) - 2), ' 个顶层输入端口和 ', ...
              num2str(length(outputPorts)), ' 个顶层输出端口信息到 ', excelFileName]);
        
    catch err
        disp(['发生错误: ', err.message]);
    end
    
    % 关闭模型
    if modelLoaded
        close_system(modelName, 0); % 0表示不保存更改
    end
end
