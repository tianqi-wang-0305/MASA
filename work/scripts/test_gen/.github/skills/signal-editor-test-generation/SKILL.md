---
name: signal-editor-test-generation
description: "从软件需求或模型接口自动生成 Simulink Test 单元测试用例，使用 Signal Editor 作为测试输入源，满足 MIL 级别覆盖度和需求验证。"
license: MIT
metadata:
  author: MASA
  version: "1.0"
---

# Signal Editor 单元测试用例生成规则

从软件需求或模型接口出发，自动生成可在 Simulink Test 中执行的 MIL 单元测试用例，使用 **Signal Editor** 作为测试激励源。

---

## 一、测试输入生成规则

### 1.1 信号类型 → Signal Editor 映射

| 需求描述 | Signal Editor 信号类型 | 示例 |
|---------|----------------------|------|
| 常值输入 | `constant` | 车速 = 0 km/h |
| 阶跃变化 | `step` | 车速从 0 → 30 km/h @ 2s |
| 脉冲 | `pulse` | 碰撞信号 1s 高电平 |
| 斜坡 | `ramp` | 油门从 0% → 100% 线性增加 |
| 正弦 | `sine` | 位置传感器正弦信号 |
| 自定义时序 | `timeseries` | 从 Excel 或 .mat 导入 |

### 1.2 端口命名 → 数据类型推导

按照 `{type}{Name}` 命名规范：

| 端口名 | 推导类型 | Signal Editor 配置 |
|--------|---------|-------------------|
| `u16VehicleSpeed` | uint16 | 数值范围 0–65535 |
| `f32Temperature` | single | 浮点数 |
| `bLockRequest` | boolean | 0 / 1 |
| `eStMotor` | enum | 枚举值（需查 Enum 定义）|

### 1.3 标定参数处理

标定参数（`cal_` 前缀）在 MIL 测试中作为工作区变量加载：

```matlab
% 测试前加载
run('Model_LoadCalParameter.m')
```

---

## 二、测试场景生成规则

### 2.1 场景模板

#### 正常工况 (Nominal)

```
Scenario: {功能名}_正常工况
  验证在正常输入范围内，输出符合预期

  Given inputs
    * u16VehicleSpeed = const(50)
    * bLockRequest   = step(0 -> 1 @ 1s)
    * eStMotor       = const(RUN)
  When simulate for 10s in Normal mode
  Then baseline "ref.mat" with tolerances: absTol=0.01
    * LockCmd: absTol=0.001
  Then outputs
    * LockActivated: LockCmd == 1 when t > 1s
```

#### 边界工况 (Boundary)

```
Scenario: {功能名}_边界工况_0输入
  验证零输入条件下模块输出不出现异常值

  Given inputs
    * u16VehicleSpeed = const(0)
    * bLockRequest   = const(0)
    * eStMotor       = const(STOP)
  When simulate for 5s
  Then outputs
    * NoSpuriousLock: LockCmd == 0
```

#### 异常工况 (Fault)

```
Scenario: {功能名}_异常_碰撞信号
  验证碰撞信号触发时解锁及闪烁输出

  Given inputs
    * u16VehicleSpeed = const(60)
    * CrashSignal     = pulse(width=1s, period=0s)
  When simulate for 10s
  Then outputs
    * CrashUnlock: UnlockCmd == 1 when t > CrashSignal
    * FlashActive: FlashCmd == 1 when t > CrashSignal
```

### 2.2 输入组合规则

| 变量数 | 最少测试场景 | 说明 |
|--------|------------|------|
| 1–2 | 3 | 正常 + 边界 + 异常 |
| 3–5 | 5 | 正交组合覆盖 |
| >5 | 7+ | 重点覆盖逻辑分支 |

### 2.3 时序规则

- 仿真时长 = 信号周期 × 3（至少覆盖 3 个完整周期）
- 阶跃时间 = 总时长 × 20%（留足稳态时间）
- 采样步长 = 模型固定步长（通常 0.01s 或 0.001s）

---

## 三、Signal Editor 数据文件生成

### 3.1 `.mat` 文件格式

```matlab
% 生成 Signal Editor 可加载的 .mat 数据
function createSignalEditorData(featureFile, outputMat)
    % 解析 .feature 文件中的 Given inputs
    % 转换为 Simulink.SimulationData.Dataset 格式
    % 保存为 .mat 文件
    
    % Example output structure:
    % myData.mat contains:
    %   > root (Simulink.SimulationData.Dataset)
    %     > u16VehicleSpeed (timeseries)
    %     > bLockRequest (timeseries)
    %     > eStMotor (timeseries)
end
```

### 3.2 数据类型转换规则

| .feature 语法 | Signal Editor 数据 |
|--------------|-------------------|
| `const(50)` | `timeseries([50 50], [0 10])` |
| `step(0->100 @ 2s)` | `timeseries([0 0 100 100], [0 2 2.001 10])` |
| `pulse(width=1s)` | `timeseries([0 1 1 0], [0 1 2 2.001])` |

---

## 四、覆盖率规则

### 4.1 覆盖率目标

| 覆盖率类型 | MIL 目标 | 说明 |
|-----------|---------|------|
| Execution | ≥ 90% | 每行代码至少执行一次 |
| Decision | ≥ 80% | 每个分支 True/False 均覆盖 |
| Condition | ≥ 70% | 每个条件项独立影响 |

### 4.2 覆盖缺口分析

测试执行后，对未覆盖部分自动补充场景：

```matlab
% 分析未覆盖分支
result = model_test('Model', 'TestFile', 'test.feature', ...
    'Coverage', 'decision');
% 未覆盖分支自动生成补充场景
generateMissingScenarios(result);
```

---

## 五、需求追溯规则

### 5.1 追溯矩阵

每个测试场景必须追溯至需求：

```gherkin
# --- front-matter:toml ---
[requirements]
REQ-001 = "车速 > 15km/h 自动落锁"
REQ-002 = "碰撞时自动解锁"
REQ-003 = "遥控锁优先级高于解锁"
# --- end front-matter ---

Scenario: REQ-001_正常工况_车速超阈值落锁
  Description: Verify REQ-001: auto-lock when speed exceeds 15 km/h
  ...
```

### 5.2 通过标准

| 标准 | 要求 |
|------|------|
| 每个需求至少 1 个测试 | ✅ 强制 |
| 每个端口至少被激励 1 次 | ✅ 强制 |
| 关键安全需求 3 场景覆盖 | 正常 + 边界 + 异常 |
| 覆盖率达目标值 | Execution ≥ 90%, Decision ≥ 80% |

---

## 六、自动化流程

```matlab
% 1. 从模型读取接口
exportSignalsToExcel('Model.slx');

% 2. 从需求生成测试用例（遵循上述规则）
generateModelTests('Model.slx', 'Strategy', 'comprehensive');

% 3. 生成 Signal Editor .mat 数据
createSignalEditorData('Model_NominalTests.feature', 'test_data.mat');

% 4. 执行测试
model_test('Model', 'TestFile', 'Model_NominalTests.feature', ...
    'Coverage', 'decision');

% 5. 分析覆盖率缺口
analyzeModelCoverage('Model.slx', 'Threshold', 80);

% 6. 补充缺失场景
generateMissingScenarios(coverageResult);
```
