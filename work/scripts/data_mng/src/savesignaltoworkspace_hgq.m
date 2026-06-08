% filepath: export_ports_datatype_as_parameters.m
% 将选中端口的数据类型配置为Simulink.Parameter并导入到workspace

model = bdroot;
if isempty(model)
    error('请先打开一个Simulink模型。');
end

sel = find_system(model, 'FindAll', 'on', 'Selected', 'on');

% 过滤出Inport和Outport
portHandles = [];
for i = 1:length(sel)
    try
        blockType = get_param(sel(i), 'BlockType');
        if strcmp(blockType, 'Inport') || strcmp(blockType, 'Outport')
            portHandles = [portHandles; sel(i)];
        end
    catch
        % 不是block
    end
end

if isempty(portHandles)
    error('请至少选中一个Inport或Outport端口。');
end

for i = 1:length(portHandles)
    h = portHandles(i);
    sigName = get_param(h, 'Name');
    dataType = get_param(h, 'OutDataTypeStr');
    % 创建Simulink.Signal对象
	param = Simulink.Signal;
    param.CoderInfo.StorageClass = 'ExportedGlobal';
    param.CoderInfo.Identifier = '';
    param.CoderInfo.Alignment = -1;
    param.Description = '';
    param.DataType = dataType;
    param.Min = [];
    param.Max = [];
    param.DocUnits = '';
    param.Dimensions = -1;
    param.DimensionsMode = 'auto';
    param.Complexity = 'auto';
    param.SampleTime = -1;
    param.InitialValue = '';
    % 导入到workspace，变量名为信号名
    assignin('base', sigName, param);
end

disp('所有选中端口的数据类型已作为Simulink.Signal对象导入到workspace。');