function batch_color_models()
% 批量处理文件夹及子文件夹内的 Simulink 模型，对所有层级的：
% - Inport  设置 green
% - Outport 设置 lightBlue
% - 标定 Constant 设置 orange（Simulink.Parameter 或 Constant）
%
% 使用：直接运行 batch_color_models()

    %=================== 可配置区 ===================
    folder = uigetdir(pwd, '选择包含模型文件的文件夹（将扫描所有子文件夹）');
    if folder == 0
        disp('已取消选择文件夹。');
        return;
    end

    extensions = {'.slx', '.mdl'};
    colors.inport  = 'green';
    colors.outport = 'lightBlue';
    colors.calib   = 'orange';

    allowFallbackAllConstants = true;  % 找不到 Simulink.Parameter 时，是否把所有 Constant 当作标定常量
    ignoreEvalError = true;            % eval 失败时是否忽略并继续
    %==================================================

    % 递归获取所有模型文件
    files = get_model_files_recursive(folder, extensions);

    fprintf('检测到 %d 个模型文件（包含子文件夹）。\n', numel(files));

    for k = 1:numel(files)
        modelPath = files{k};
        fprintf('\n=============================\n处理模型：%s\n', modelPath);
        try
            process_single_model(modelPath, colors, allowFallbackAllConstants, ignoreEvalError);
        catch ME
            warning('处理模型失败：%s\n错误信息：%s\n', modelPath, ME.message);
        end
    end

    disp('=============================');
    disp('所有模型处理完成！');
end


%% ------------------------------------------------------------
function files = get_model_files_recursive(rootFolder, extensions)
% 递归扫描所有子文件夹中的模型文件（.slx / .mdl）
    files = {};
    for i = 1:numel(extensions)
        ext = extensions{i};
        list = dir(fullfile(rootFolder, '**', ['*' ext]));  % 递归搜索
        for k = 1:numel(list)
            if ~list(k).isdir
                files{end+1} = fullfile(list(k).folder, list(k).name); %#ok<AGROW>
            end
        end
    end
    files = unique(files); % 去重
end


%% ------------------------------------------------------------
function process_single_model(modelPath, colors, allowFallbackAllConstants, ignoreEvalError)

    % 载入模型
    [~, modelName] = fileparts(modelPath);
    load_system(modelPath);

    % 查找所有层级（包括子系统/掩码/库链接）
    searchOpt = {'FollowLinks','on','LookUnderMasks','all'};

    inports   = find_system(modelName, searchOpt{:}, 'BlockType','Inport');
    outports  = find_system(modelName, searchOpt{:}, 'BlockType','Outport');
    constants = find_system(modelName, searchOpt{:}, 'BlockType','Constant');

    % 上色：In/Out
    set_color(inports,   colors.inport);
    set_color(outports,  colors.outport);

    % 识别标定常量
    calibBlocks = detect_calibration_constants(constants, modelName, ignoreEvalError);

    if isempty(calibBlocks) && allowFallbackAllConstants
        calibBlocks = constants;
        disp('[INFO] 未识别到 Simulink.Parameter 引用 → 已将所有 Constant 视为标定常量。');
    end

    % 对标定着色
    set_color(calibBlocks, colors.calib);

    % 保存模型
    save_system(modelName);

    fprintf('[RESULT] 处理完成：Inport=%d, Outport=%d, Calibration=%d\n', ...
        numel(inports), numel(outports), numel(calibBlocks));

    % 关闭模型（如需保留打开状态，可注释掉）
    close_system(modelName);
end


%% ------------------------------------------------------------
function set_color(blocks, color)
    for i = 1:numel(blocks)
        try
            set_param(blocks{i}, 'BackgroundColor', color);
        catch
            warning('设置颜色失败：%s', blocks{i});
        end
    end
end


%% ------------------------------------------------------------
function calibBlocks = detect_calibration_constants(constants, model, ignoreEvalError)
% 识别“标定常量”：Constant 的 Value 指向 Simulink.Parameter
    calibBlocks = {};

    % 模型工作区
    mdlWS = get_param(model, 'ModelWorkspace');

    for i = 1:numel(constants)
        blk = constants{i};
        val = '';
        try
            val = get_param(blk, 'Value');
        catch
            % 无法读取 Value 的情况直接跳过
            continue;
        end

        % 只判断简单变量名（避免表达式）
        if ~isvarname(strtrim(val))
            continue;
        end

        isCalib = false;

        % 先查模型工作区
        try
            if hasVariable(mdlWS, val)
                v = getVariable(mdlWS, val);
                if isa(v, 'Simulink.Parameter')
                    isCalib = true;
                end
            end
        catch
            % 忽略模型工作区异常
        end

        % 再查 base 工作区（可选）
        if ~isCalib
            try
                if evalin('base', sprintf('exist(''%s'',''var'')', val))
                    v = evalin('base', val);
                    if isa(v, 'Simulink.Parameter')
                        isCalib = true;
                    end
                end
            catch
                if ~ignoreEvalError
                    warning('无法解析 Constant 值：%s', val);
                end
            end
        end

        if isCalib
            calibBlocks{end+1} = blk; %#ok<AGROW>
        end
    end
end