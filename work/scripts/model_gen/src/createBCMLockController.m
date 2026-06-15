function createBCMLockController(saveDir)
% createBCMLockController  Build BCM door lock controller Simulink model
%   Uses the Simulink Agentic Toolkit (model_edit) to construct a complete
%   BCM (Body Control Module) door lock controller model with:
%     - Auto-lock when speed > 15 km/h
%     - Auto-unlock on crash
%     - Remote lock/unlock request arbitration with speed inhibit
%
%   Inputs:
%       saveDir - Optional output directory (default: current dir)
%
%   Usage:
%       createBCMLockController();
%       createBCMLockController('path/to/save');

    fprintf('=== Building BCM Lock Controller Model ===\n\n');

    if nargin < 1
        saveDir = pwd;
    end
    modelName = 'BCM_LockController';

    %% ===================================================================
    %% Step 1: Create and open the model
    %% ===================================================================
    fprintf('[1/8] Creating model: %s\n', modelName);
    new_system(modelName);
    open_system(modelName);

    % Set model-level parameters
    set_param(modelName, 'Solver', 'FixedStepDiscrete');
    set_param(modelName, 'FixedStep', '0.01');
    set_param(modelName, 'StopTime', '100');

    % Check toolkit availability
    toolkitRoot = getToolkitRoot();
    usingToolkit = ~isempty(toolkitRoot);
    if usingToolkit
        fprintf('      Using Simulink Agentic Toolkit (model_edit for top-level, add_block for subsystems)\n');
    else
        fprintf('      Using direct MATLAB commands\n');
    end

    %% ===================================================================
    %% Step 2: Add top-level Input/Output ports
    %% ===================================================================
    fprintf('[2/8] Adding top-level ports...\n');

    inports = {
        'DoorStatus_FL',   'Inport';  % 左前门状态 (0=关, 1=开)
        'DoorStatus_FR',   'Inport';  % 右前门状态
        'DoorStatus_RL',   'Inport';  % 左后门状态
        'DoorStatus_RR',   'Inport';  % 右后门状态
        'VehicleSpeed',    'Inport';  % 车速信号 (km/h)
        'RemoteLockReq',   'Inport';  % 遥控锁请求 (0→1上升沿)
        'RemoteUnlockReq', 'Inport';  % 遥控解锁请求
        'CrashSignal',     'Inport'   % 碰撞信号 (0=正常, 1=碰撞)
    };

    outports = {
        'LockCmd',    'Outport';  % 锁门指令
        'UnlockCmd',  'Outport';  % 解锁指令
        'FlashCmd',   'Outport'   % 转向灯闪烁指令
    };

    if usingToolkit
        ops = {};
        for i = 1:size(inports, 1)
            ops{end+1} = struct('op', 'add_block', 'type', inports{i,2}, ...
                'name', inports{i,1}, 'ref', sprintf('p_in_%d', i)); %#ok<AGROW>
        end
        for i = 1:size(outports, 1)
            ops{end+1} = struct('op', 'add_block', 'type', outports{i,2}, ...
                'name', outports{i,1}, 'ref', sprintf('p_out_%d', i)); %#ok<AGROW>
        end
        result = model_edit(modelName, 'root', jsonencode(ops), 'incremental');
        created = parseCreated(result);
    else
        for i = 1:size(inports, 1)
            add_block('simulink/Sources/In1', [modelName '/' inports{i,1}]);
        end
        for i = 1:size(outports, 1)
            add_block('simulink/Sinks/Out1', [modelName '/' outports{i,1}]);
        end
        % Arrange ports vertically on left and right
        yPos = 50;
        for i = 1:size(inports, 1)
            set_param([modelName '/' inports{i,1}], 'Position', [50, yPos, 80, yPos+20]);
            yPos = yPos + 50;
        end
        yPos = 50;
        for i = 1:size(outports, 1)
            set_param([modelName '/' outports{i,1}], 'Position', [850, yPos+100, 880, yPos+120]);
            yPos = yPos + 50;
        end
    end

    %% ===================================================================
    %% Step 3: Create subsystems
    %% ===================================================================
    fprintf('[3/8] Creating subsystems...\n');

    subsystems = {
        'DoorStatusMerge',    '门状态汇总 - 判断是否所有车门已关闭';
        'SpeedAutoLock',      '自动落锁 - 车速>15km/h且车门全关时闭锁';
        'CrashUnlock',        '碰撞解锁 - 碰撞信号触发全车解锁';
        'RemoteArbitration',  '遥控仲裁 - 遥控请求处理含车速抑制(>5km/h禁开锁)';
        'OutputMerge'         '输出合并 - 优先级仲裁和最终指令输出'
    };

    if usingToolkit
        ops = {};
        for i = 1:size(subsystems, 1)
            ops{end+1} = struct('op', 'add_block', 'type', 'SubSystem', ...
                'name', subsystems{i,1}, 'ref', sprintf('ss_%d', i)); %#ok<AGROW>
        end
        result = model_edit(modelName, 'root', jsonencode(ops), 'incremental');
    else
        for i = 1:size(subsystems, 1)
            add_block('simulink/Ports & Subsystems/Subsystem', ...
                [modelName '/' subsystems{i,1}]);
            % Position subsystems
            set_param([modelName '/' subsystems{i,1}], 'Position', ...
                [200 + (i-1)*140, 200, 300 + (i-1)*140, 300]);
        end
    end

    %% ===================================================================
    %% Step 4-6: Build all subsystems (always use direct MATLAB for internals)
    %% ===================================================================
    fprintf('[4/8] Building DoorStatusMerge...\n');
    buildDoorStatusMerge_direct([modelName '/DoorStatusMerge']);

    fprintf('[5/8] Building SpeedAutoLock...\n');
    buildSpeedAutoLock_direct([modelName '/SpeedAutoLock']);

    fprintf('[6/8] Building CrashUnlock, RemoteArbitration, OutputMerge...\n');
    buildCrashUnlock_direct([modelName '/CrashUnlock']);
    buildRemoteArbitration_direct([modelName '/RemoteArbitration']);
    buildOutputMerge_direct([modelName '/OutputMerge']);

    %% ===================================================================
    %% Step 7: Wire top-level connections
    %% ===================================================================
    fprintf('[7/8] Wiring top-level connections...\n');
    wireTopLevel_direct(modelName);

    %% ===================================================================
    %% Step 8: Save model and run model_check
    %% ===================================================================
    fprintf('[8/8] Saving and validating...\n');

    saveFile = fullfile(saveDir, [modelName '.slx']);
    save_system(modelName, saveFile);
    fprintf('      Saved: %s\n', saveFile);

    % Run model_check if available
    if usingToolkit
        try
            checkResult = model_check(modelName, 'root', jsonencode(["all"]));
            fprintf('      Model check: %s\n', strtrim(extractBefore(string(checkResult), 200)));
        catch ME
            fprintf('      Model check skipped: %s\n', ME.message);
        end
    end

    %% ===================================================================
    %% Summary
    %% ===================================================================
    fprintf('\n=== BCM Lock Controller Created ===\n');
    fprintf('Model: %s\n', saveFile);
    fprintf('Subsystems: %d\n', size(subsystems, 1));
    fprintf('Inputs: %d, Outputs: %d\n', size(inports, 1), size(outports, 1));

    % Print model structure
    fprintf('\nModel Structure:\n');
    fprintf('  BCM_LockController (top)\n');
    for i = 1:size(subsystems, 1)
        fprintf('    ├── %s  - %s\n', subsystems{i,1}, subsystems{i,2});
    end

    fprintf('\nNext steps:\n');
    fprintf('  1. Open the model: open_system(''%s'')\n', modelName);
    fprintf('  2. Review and optimize layout manually\n');
    fprintf('  3. Add test: generateModelTests(''%s'')\n', saveFile);
    fprintf('  4. Generate SDD: DdGeneration_AI(''%s'', ''path/to/workbook.xlsx'')\n', saveFile);
end

%% ================== Toolkit-based builders ==================

function buildDoorStatusMerge(scope)
% DoorStatusMerge: 4-input sum to detect any open door, then output AllClosed
    try delete_block([scope '/In1']); catch, end
    try delete_block([scope '/Out1']); catch, end

    ops = {};
    % Add 4 inports
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport',  'name', 'DoorStatus_FL', 'ref', 'in1');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport',  'name', 'DoorStatus_FR', 'ref', 'in2');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport',  'name', 'DoorStatus_RL', 'ref', 'in3');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport',  'name', 'DoorStatus_RR', 'ref', 'in4');

    % Sum to detect any open door (OR), then compare ==0 for AllClosed
    ops{end+1} = struct('op', 'add_block', 'type', 'Sum', 'name', 'AnyDoorOpen', 'ref', 'sum1', ...
        'params', struct('Inputs', '++++'));
    ops{end+1} = struct('op', 'add_block', 'type', 'RelationalOperator', ...
        'name', 'AllClosed', 'ref', 'rel1', ...
        'params', struct('Operator', '=='));
    ops{end+1} = struct('op', 'add_block', 'type', 'Constant', 'name', 'ZeroRef', 'ref', 'c0', ...
        'params', struct('Value', '0'));
    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'AllDoorsClosed', 'ref', 'out1');

    model_edit(bdroot(scope), scope, jsonencode(ops), 'incremental');

    % Connect: inports → Sum → Compare(=0) → Outport
    ops2 = {};
    ops2{end+1} = struct('op', 'connect', 'target', '#in1.y1 -> #sum1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#in2.y1 -> #sum1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#in3.y1 -> #sum1.u3');
    ops2{end+1} = struct('op', 'connect', 'target', '#in4.y1 -> #sum1.u4');
    ops2{end+1} = struct('op', 'connect', 'target', '#sum1.y1 -> #rel1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#c0.y1 -> #rel1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#rel1.y1 -> #out1.u1');

    model_edit(bdroot(scope), scope, jsonencode(ops2), 'incremental');
end

function buildSpeedAutoLock(scope)
% SpeedAutoLock: VehicleSpeed > 15 AND AllDoorsClosed → LockReq
    try delete_block([scope '/In1']); catch, end
    try delete_block([scope '/Out1']); catch, end

    ops = {};
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'VehicleSpeed', 'ref', 'in_spd');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'AllDoorsClosed', 'ref', 'in_door');
    ops{end+1} = struct('op', 'add_block', 'type', 'Constant', 'name', 'SpeedThreshold', 'ref', 'c1', ...
        'params', struct('Value', '15', 'OutDataTypeStr', 'double'));
    ops{end+1} = struct('op', 'add_block', 'type', 'RelationalOperator', 'name', 'SpeedCheck', 'ref', 'rel1', ...
        'params', struct('Operator', '>='));
    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'LockAndGate', 'ref', 'and1', ...
        'params', struct('Operator', 'AND', 'Inputs', '2'));
    ops{end+1} = struct('op', 'add_block', 'type', 'DetectRisePositive', 'name', 'RiseDetect', 'ref', 'rise1');
    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'SpeedLockReq', 'ref', 'out1');

    model_edit(bdroot(scope), scope, jsonencode(ops), 'incremental');

    ops2 = {};
    ops2{end+1} = struct('op', 'connect', 'target', '#in_spd.y1 -> #rel1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#c1.y1 -> #rel1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#rel1.y1 -> #and1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#in_door.y1 -> #and1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#and1.y1 -> #rise1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#rise1.y1 -> #out1.u1');

    model_edit(bdroot(scope), scope, jsonencode(ops2), 'incremental');
end

function buildCrashUnlock(scope)
% CrashUnlock: CrashSignal rising edge → UnlockReq
    try delete_block([scope '/In1']); catch, end
    try delete_block([scope '/Out1']); catch, end

    ops = {};
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'CrashSignal', 'ref', 'in1');
    ops{end+1} = struct('op', 'add_block', 'type', 'DetectRisePositive', 'name', 'CrashDetect', 'ref', 'rise1');
    ops{end+1} = struct('op', 'add_block', 'type', 'DiscretePulseGenerator', 'name', 'PulseExtender', 'ref', 'pulse1', ...
        'params', struct('PulseType', 'Sample based', 'SampleTime', '0.01', ...
                         'PulseWidth', '500', 'Period', '5000'));
    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'UnlockTrigger', 'ref', 'and1', ...
        'params', struct('Operator', 'AND'));
    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'CrashUnlockReq', 'ref', 'out1');

    model_edit(bdroot(scope), scope, jsonencode(ops), 'incremental');

    ops2 = {};
    ops2{end+1} = struct('op', 'connect', 'target', '#in1.y1 -> #rise1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#rise1.y1 -> #and1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#pulse1.y1 -> #and1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#and1.y1 -> #out1.u1');

    model_edit(bdroot(scope), scope, jsonencode(ops2), 'incremental');
end

function buildRemoteArbitration(scope)
% RemoteArbitration: Remote requests with speed inhibit (>5km/h disable unlock)
    try delete_block([scope '/In1']); catch, end
    try delete_block([scope '/Out1']); catch, end

    ops = {};
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'RemoteLockReq', 'ref', 'in_lock');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'RemoteUnlockReq', 'ref', 'in_unlock');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'VehicleSpeed', 'ref', 'in_spd');

    ops{end+1} = struct('op', 'add_block', 'type', 'Constant', 'name', 'SpeedThreshold', 'ref', 'c1', ...
        'params', struct('Value', '5', 'OutDataTypeStr', 'double'));
    ops{end+1} = struct('op', 'add_block', 'type', 'RelationalOperator', 'name', 'SpeedCheck', 'ref', 'rel1', ...
        'params', struct('Operator', '<'));
    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'UnlockEnable', 'ref', 'and1', ...
        'params', struct('Operator', 'AND'));

    ops{end+1} = struct('op', 'add_block', 'type', 'DetectRisePositive', 'name', 'LockRise', 'ref', 'rise_lock');
    ops{end+1} = struct('op', 'add_block', 'type', 'DetectRisePositive', 'name', 'UnlockRise', 'ref', 'rise_unlock');

    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'LockNot', 'ref', 'not1', ...
        'params', struct('Operator', 'NOT'));
    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'FinalAnd', 'ref', 'and2', ...
        'params', struct('Operator', 'AND'));

    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'RemoteLock', 'ref', 'out_lock');
    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'RemoteUnlock', 'ref', 'out_unlock');

    model_edit(bdroot(scope), scope, jsonencode(ops), 'incremental');

    ops2 = {};
    ops2{end+1} = struct('op', 'connect', 'target', '#in_lock.y1 -> #rise_lock.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#rise_lock.y1 -> #out_lock.u1');

    ops2{end+1} = struct('op', 'connect', 'target', '#in_spd.y1 -> #rel1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#c1.y1 -> #rel1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#rel1.y1 -> #and1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#in_unlock.y1 -> #rise_unlock.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#rise_unlock.y1 -> #and1.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#in_lock.y1 -> #not1.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#and1.y1 -> #and2.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#not1.y1 -> #and2.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#and2.y1 -> #out_unlock.u1');

    model_edit(bdroot(scope), scope, jsonencode(ops2), 'incremental');
end

function buildOutputMerge(scope)
% OutputMerge: Final arbitration and output
    try delete_block([scope '/In1']); catch, end
    try delete_block([scope '/Out1']); catch, end

    ops = {};
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'SpeedLockReq', 'ref', 'in_spd');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'CrashUnlockReq', 'ref', 'in_crash');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'RemoteLock', 'ref', 'in_rem_lock');
    ops{end+1} = struct('op', 'add_block', 'type', 'Inport', 'name', 'RemoteUnlock', 'ref', 'in_rem_unlock');

    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'LockOr', 'ref', 'or_lock', ...
        'params', struct('Operator', 'OR', 'Inputs', '2'));
    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'UnlockOr', 'ref', 'or_unlock', ...
        'params', struct('Operator', 'OR', 'Inputs', '2'));
    ops{end+1} = struct('op', 'add_block', 'type', 'LogicalOperator', 'name', 'FlashOr', 'ref', 'or_flash', ...
        'params', struct('Operator', 'OR', 'Inputs', '2'));

    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'LockCmd', 'ref', 'out_lock');
    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'UnlockCmd', 'ref', 'out_unlock');
    ops{end+1} = struct('op', 'add_block', 'type', 'Outport', 'name', 'FlashCmd', 'ref', 'out_flash');

    model_edit(bdroot(scope), scope, jsonencode(ops), 'incremental');

    ops2 = {};
    ops2{end+1} = struct('op', 'connect', 'target', '#in_spd.y1 -> #or_lock.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#in_rem_lock.y1 -> #or_lock.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#or_lock.y1 -> #out_lock.u1');

    ops2{end+1} = struct('op', 'connect', 'target', '#in_crash.y1 -> #or_unlock.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#in_rem_unlock.y1 -> #or_unlock.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#or_unlock.y1 -> #out_unlock.u1');

    ops2{end+1} = struct('op', 'connect', 'target', '#or_lock.y1 -> #or_flash.u1');
    ops2{end+1} = struct('op', 'connect', 'target', '#or_unlock.y1 -> #or_flash.u2');
    ops2{end+1} = struct('op', 'connect', 'target', '#or_flash.y1 -> #out_flash.u1');

    model_edit(bdroot(scope), scope, jsonencode(ops2), 'incremental');
end

function wireTopLevel_toolkit(modelName)
% Wire top-level ports to subsystems
    % First do model_read to get port/sub block IDs
    % Note: In a real run, we'd use the "created" map from earlier calls
    % For this script, we wire using direct path names (fallback)

    % Wire DoorStatus_FL/FR/RL/RR → DoorStatusMerge
    DoorStatusMerge_in = @(n) [modelName '/DoorStatusMerge/' n];
    add_line(modelName, 'DoorStatus_FL/1', 'DoorStatusMerge/1');
    add_line(modelName, 'DoorStatus_FR/1', 'DoorStatusMerge/2');
    add_line(modelName, 'DoorStatus_RL/1', 'DoorStatusMerge/3');
    add_line(modelName, 'DoorStatus_RR/1', 'DoorStatusMerge/4');

    % Wire DoorStatusMerge → SpeedAutoLock
    add_line(modelName, 'DoorStatusMerge/1', 'SpeedAutoLock/2');

    % Wire VehicleSpeed → SpeedAutoLock, RemoteArbitration
    add_line(modelName, 'VehicleSpeed/1', 'SpeedAutoLock/1');
    add_line(modelName, 'VehicleSpeed/1', 'RemoteArbitration/3');

    % Wire RemoteLockReq → RemoteArbitration
    add_line(modelName, 'RemoteLockReq/1', 'RemoteArbitration/1');
    add_line(modelName, 'RemoteUnlockReq/1', 'RemoteArbitration/2');

    % Wire CrashSignal → CrashUnlock
    add_line(modelName, 'CrashSignal/1', 'CrashUnlock/1');

    % Wire subsystems → OutputMerge
    add_line(modelName, 'SpeedAutoLock/1', 'OutputMerge/1');
    add_line(modelName, 'CrashUnlock/1', 'OutputMerge/2');
    add_line(modelName, 'RemoteArbitration/1', 'OutputMerge/3');
    add_line(modelName, 'RemoteArbitration/2', 'OutputMerge/4');

    % Wire OutputMerge → Outports
    add_line(modelName, 'OutputMerge/1', 'LockCmd/1');
    add_line(modelName, 'OutputMerge/2', 'UnlockCmd/1');
    add_line(modelName, 'OutputMerge/3', 'FlashCmd/1');
end

%% ================== Direct MATLAB builders (fallback) ==================

function buildDoorStatusMerge_direct(scope)
    delete_block([scope '/In1']);
    delete_block([scope '/Out1']);

    add_block('simulink/Sources/In1', [scope '/DoorStatus_FL'], 'Position', [50, 30, 80, 50]);
    add_block('simulink/Sources/In1', [scope '/DoorStatus_FR'], 'Position', [50, 80, 80, 100]);
    add_block('simulink/Sources/In1', [scope '/DoorStatus_RL'], 'Position', [50, 130, 80, 150]);
    add_block('simulink/Sources/In1', [scope '/DoorStatus_RR'], 'Position', [50, 180, 80, 200]);

    add_block('simulink/Math Operations/Sum', [scope '/AnyDoorOpen'], ...
        'Position', [200, 80, 230, 150], 'Inputs', '++++');
    add_block('simulink/Logic and Bit Operations/RelationalOperator', [scope '/AllClosed'], ...
        'Position', [350, 95, 400, 135], 'Operator', '==');
    add_block('simulink/Constants/Constant', [scope '/ZeroRef'], ...
        'Position', [250, 180, 280, 200], 'Value', '0');

    add_block('simulink/Sinks/Out1', [scope '/AllDoorsClosed'], 'Position', [500, 105, 530, 125]);

    add_line(scope, 'DoorStatus_FL/1', 'AnyDoorOpen/1');
    add_line(scope, 'DoorStatus_FR/1', 'AnyDoorOpen/2');
    add_line(scope, 'DoorStatus_RL/1', 'AnyDoorOpen/3');
    add_line(scope, 'DoorStatus_RR/1', 'AnyDoorOpen/4');
    add_line(scope, 'AnyDoorOpen/1', 'AllClosed/1');
    add_line(scope, 'ZeroRef/1', 'AllClosed/2');
    add_line(scope, 'AllClosed/1', 'AllDoorsClosed/1');
end

function buildSpeedAutoLock_direct(scope)
    delete_block([scope '/In1']);
    delete_block([scope '/Out1']);

    add_block('simulink/Sources/In1', [scope '/VehicleSpeed'], 'Position', [50, 60, 80, 80]);
    add_block('simulink/Sources/In1', [scope '/AllDoorsClosed'], 'Position', [50, 140, 80, 160]);

    add_block('simulink/Constants/Constant', [scope '/SpeedThreshold'], ...
        'Position', [150, 20, 200, 40], 'Value', '15');
    add_block('simulink/Logic and Bit Operations/RelationalOperator', [scope '/SpeedCheck'], ...
        'Position', [250, 45, 300, 85], 'Operator', '>=');
    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/LockAndGate'], ...
        'Position', [400, 60, 440, 110], 'Operator', 'AND', 'Inputs', '2');
    add_block('simulink/Logic and Bit Operations/DetectRisePositive', [scope '/RiseDetect'], ...
        'Position', [500, 70, 550, 110]);

    add_block('simulink/Sinks/Out1', [scope '/SpeedLockReq'], 'Position', [630, 80, 660, 100]);

    add_line(scope, 'VehicleSpeed/1', 'SpeedCheck/1');
    add_line(scope, 'SpeedThreshold/1', 'SpeedCheck/2');
    add_line(scope, 'SpeedCheck/1', 'LockAndGate/1');
    add_line(scope, 'AllDoorsClosed/1', 'LockAndGate/2');
    add_line(scope, 'LockAndGate/1', 'RiseDetect/1');
    add_line(scope, 'RiseDetect/1', 'SpeedLockReq/1');
end

function buildCrashUnlock_direct(scope)
    delete_block([scope '/In1']);
    delete_block([scope '/Out1']);

    add_block('simulink/Sources/In1', [scope '/CrashSignal'], 'Position', [50, 60, 80, 80]);
    add_block('simulink/Logic and Bit Operations/DetectRisePositive', [scope '/CrashDetect'], ...
        'Position', [170, 55, 220, 95]);
    add_block('simulink/Sources/DiscretePulseGenerator', [scope '/PulseExtender'], ...
        'Position', [170, 130, 240, 170], ...
        'PulseType', 'Sample based', 'SampleTime', '0.01', 'PulseWidth', '500', 'Period', '5000');
    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/UnlockTrigger'], ...
        'Position', [330, 65, 370, 115], 'Operator', 'AND');
    add_block('simulink/Sinks/Out1', [scope '/CrashUnlockReq'], 'Position', [450, 80, 480, 100]);

    add_line(scope, 'CrashSignal/1', 'CrashDetect/1');
    add_line(scope, 'CrashDetect/1', 'UnlockTrigger/1');
    add_line(scope, 'PulseExtender/1', 'UnlockTrigger/2');
    add_line(scope, 'UnlockTrigger/1', 'CrashUnlockReq/1');
end

function buildRemoteArbitration_direct(scope)
    delete_block([scope '/In1']);
    delete_block([scope '/Out1']);

    add_block('simulink/Sources/In1', [scope '/RemoteLockReq'], 'Position', [50, 30, 80, 50]);
    add_block('simulink/Sources/In1', [scope '/RemoteUnlockReq'], 'Position', [50, 120, 80, 140]);
    add_block('simulink/Sources/In1', [scope '/VehicleSpeed'], 'Position', [50, 210, 80, 230]);

    add_block('simulink/Logic and Bit Operations/DetectRisePositive', [scope '/LockRise'], ...
        'Position', [160, 25, 210, 65]);
    add_block('simulink/Logic and Bit Operations/DetectRisePositive', [scope '/UnlockRise'], ...
        'Position', [160, 115, 210, 155]);

    add_block('simulink/Constants/Constant', [scope '/SpeedThreshold'], ...
        'Position', [160, 200, 210, 220], 'Value', '5');
    add_block('simulink/Logic and Bit Operations/RelationalOperator', [scope '/SpeedCheck'], ...
        'Position', [290, 195, 340, 235], 'Operator', '<');
    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/UnlockEnable'], ...
        'Position', [420, 125, 460, 175], 'Operator', 'AND');

    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/LockNot'], ...
        'Position', [290, 55, 330, 85], 'Operator', 'NOT');
    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/FinalAnd'], ...
        'Position', [420, 55, 460, 105], 'Operator', 'AND');

    add_block('simulink/Sinks/Out1', [scope '/RemoteLock'], 'Position', [550, 35, 580, 55]);
    add_block('simulink/Sinks/Out1', [scope '/RemoteUnlock'], 'Position', [550, 135, 580, 155]);

    % Lock path
    add_line(scope, 'RemoteLockReq/1', 'LockRise/1');
    add_line(scope, 'LockRise/1', 'RemoteLock/1');

    % Speed check
    add_line(scope, 'VehicleSpeed/1', 'SpeedCheck/1');
    add_line(scope, 'SpeedThreshold/1', 'SpeedCheck/2');

    % Unlock path with inhibit
    add_line(scope, 'RemoteUnlockReq/1', 'UnlockRise/1');
    add_line(scope, 'SpeedCheck/1', 'UnlockEnable/1');
    add_line(scope, 'UnlockRise/1', 'UnlockEnable/2');
    add_line(scope, 'RemoteLockReq/1', 'LockNot/1');
    add_line(scope, 'UnlockEnable/1', 'FinalAnd/1');
    add_line(scope, 'LockNot/1', 'FinalAnd/2');
    add_line(scope, 'FinalAnd/1', 'RemoteUnlock/1');
end

function buildOutputMerge_direct(scope)
    delete_block([scope '/In1']);
    delete_block([scope '/Out1']);

    add_block('simulink/Sources/In1', [scope '/SpeedLockReq'], 'Position', [50, 30, 80, 50]);
    add_block('simulink/Sources/In1', [scope '/CrashUnlockReq'], 'Position', [50, 80, 80, 100]);
    add_block('simulink/Sources/In1', [scope '/RemoteLock'], 'Position', [50, 130, 80, 150]);
    add_block('simulink/Sources/In1', [scope '/RemoteUnlock'], 'Position', [50, 180, 80, 200]);

    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/LockOr'], ...
        'Position', [200, 30, 240, 70], 'Operator', 'OR', 'Inputs', '2');
    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/UnlockOr'], ...
        'Position', [200, 90, 240, 130], 'Operator', 'OR', 'Inputs', '2');
    add_block('simulink/Logic and Bit Operations/LogicalOperator', [scope '/FlashOr'], ...
        'Position', [350, 50, 390, 100], 'Operator', 'OR', 'Inputs', '2');

    add_block('simulink/Sinks/Out1', [scope '/LockCmd'], 'Position', [500, 40, 530, 60]);
    add_block('simulink/Sinks/Out1', [scope '/UnlockCmd'], 'Position', [500, 100, 530, 120]);
    add_block('simulink/Sinks/Out1', [scope '/FlashCmd'], 'Position', [500, 160, 530, 180]);

    add_line(scope, 'SpeedLockReq/1', 'LockOr/1');
    add_line(scope, 'RemoteLock/1', 'LockOr/2');
    add_line(scope, 'LockOr/1', 'LockCmd/1');

    add_line(scope, 'CrashUnlockReq/1', 'UnlockOr/1');
    add_line(scope, 'RemoteUnlock/1', 'UnlockOr/2');
    add_line(scope, 'UnlockOr/1', 'UnlockCmd/1');

    add_line(scope, 'LockOr/1', 'FlashOr/1');
    add_line(scope, 'UnlockOr/1', 'FlashOr/2');
    add_line(scope, 'FlashOr/1', 'FlashCmd/1');
end

function wireTopLevel_direct(modelName)
% Wire top-level using direct add_line
    add_line(modelName, 'DoorStatus_FL/1',   'DoorStatusMerge/1');
    add_line(modelName, 'DoorStatus_FR/1',   'DoorStatusMerge/2');
    add_line(modelName, 'DoorStatus_RL/1',   'DoorStatusMerge/3');
    add_line(modelName, 'DoorStatus_RR/1',   'DoorStatusMerge/4');
    add_line(modelName, 'DoorStatusMerge/1', 'SpeedAutoLock/2');

    add_line(modelName, 'VehicleSpeed/1',    'SpeedAutoLock/1');
    add_line(modelName, 'VehicleSpeed/1',    'RemoteArbitration/3');

    add_line(modelName, 'RemoteLockReq/1',   'RemoteArbitration/1');
    add_line(modelName, 'RemoteUnlockReq/1', 'RemoteArbitration/2');

    add_line(modelName, 'CrashSignal/1',     'CrashUnlock/1');

    add_line(modelName, 'SpeedAutoLock/1',   'OutputMerge/1');
    add_line(modelName, 'CrashUnlock/1',     'OutputMerge/2');
    add_line(modelName, 'RemoteArbitration/1', 'OutputMerge/3');
    add_line(modelName, 'RemoteArbitration/2', 'OutputMerge/4');

    add_line(modelName, 'OutputMerge/1',     'LockCmd/1');
    add_line(modelName, 'OutputMerge/2',     'UnlockCmd/1');
    add_line(modelName, 'OutputMerge/3',     'FlashCmd/1');
end

%% ================== Utility ==================

function result = parseCreated(modelEditResult)
% Parse model_edit result to extract created block map
    result = struct();
    try
        resultText = string(modelEditResult);
        % Extract created map from response
        if contains(resultText, '"created"')
            % Basic parsing - in real use, model_edit returns structured data
        end
    catch
    end
end

function rootPath = getToolkitRoot()
% Find simulink-agentic-toolkit root and add all tool subdirectories to path
    envPath = string(getenv('SATK_ROOT'));
    if strlength(envPath) > 0 && exist(envPath, 'dir')
        rootPath = char(envPath);
        addAllToolPaths(rootPath);
        return;
    end
    scriptPath = fileparts(mfilename('fullpath'));
    candidates = {
        fullfile(scriptPath, '..', '..', '..', 'simulink-agentic-toolkit');
        fullfile(scriptPath, '..', '..', '..', '..', 'simulink-agentic-toolkit');
        fullfile(scriptPath, '..', '..', '..', '..', '..', 'simulink-agentic-toolkit');
    };
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'dir') && ...
           exist(fullfile(candidates{i}, 'tools', 'model_overview', 'model_overview.p'), 'file')
            rootPath = candidates{i};
            addAllToolPaths(rootPath);
            return;
        end
    end
    rootPath = '';
end

function addAllToolPaths(toolkitRoot)
% Add all tool subdirectories to MATLAB path
    addpath(toolkitRoot);
    toolDirs = dir(fullfile(toolkitRoot, 'tools'));
    for i = 1:numel(toolDirs)
        if toolDirs(i).isdir && ~strcmp(toolDirs(i).name, '.') && ~strcmp(toolDirs(i).name, '..')
            addpath(fullfile(toolkitRoot, 'tools', toolDirs(i).name));
        end
    end
end
