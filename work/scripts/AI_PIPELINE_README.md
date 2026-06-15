# AI 驱动的 Simulink 自动化流水线

基于 Simulink Agentic Toolkit 的 AI 增强自动化方案，实现详细设计文档自动生成和单元测试自动生成。

## 目录结构

```
scripts/
├── runAIPipeline.m              # 统一入口脚本
├── ai_sdd/src/
│   ├── analyzeModelDeepForSDD.m  # 深度模型分析（生成知识库 JSON）
│   ├── DdGeneration_AI.m         # AI 增强的 SDD 报告生成器
│   └── config_sdd.json           # SDD 生成配置
├── test_gen/src/
│   ├── generateModelTests.m      # 自动化测试用例生成
│   └── config_test.json          # 测试生成配置
└── AI_PIPELINE_README.md         # 本说明文档
```

---

## 想法1：AI 增强详细设计文档生成

### 流程

```
analyzeModelDeepForSDD.m           DdGeneration_AI.m
┌──────────────────────┐          ┌──────────────────────────┐
│ model_overview(root) │──JSON──►│ 读取知识库 JSON           │
│ model_read(subsys_1) │         │ 生成 AI 增强描述          │
│ model_read(subsys_2) │         │ 生成 PDF 报告             │
│ ...                  │         │ 包含:                     │
│ model_query_params   │         │  • AI 生成的子系统描述     │
│ model_resolve_params │         │  • 接口/标定表            │
│                      │         │  • 子系统截屏             │
│                      │         │  • 超链接导航             │
└──────────────────────┘          └──────────────────────────┘
```

### 相比原始 DdGeneration_ASPICE.m 的改进

| 方面 | 原始版本 | AI 增强版本 |
|------|---------|------------|
| 子系统描述 | 关键词匹配 + 模板填充 | 基于 model_read 信号流 + 模块类型 + 参数上下文的丰富描述 |
| 角色识别 | 仅按名称匹配（command → "控制决策"） | 名称 + 模块类型 + 算法特征 综合推断 |
| 参数量化 | 无 | model_query_params + model_resolve_params 解析实际参数值 |
| Stateflow 识别 | 无 | 自动检测并描述状态机逻辑 |
| 描述粒度 | 一句话 | 多段落：角色、接口、算法、子模块、参数依赖 |

### 使用方法

```matlab
% 方法1：两阶段（先生成知识库，再生成报告）
analyzeModelDeepForSDD('path/to/Model.slx', 'path/to/workbook.xlsx');
DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx');

% 方法2：一键生成（自动调用分析）
DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx');

% 方法3：强制重新分析
DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx', 'ForceAnalyze', true);
```

---

## 想法2：自动化 Simulink Test 单元测试生成

### 流程

```
generateModelTests.m
┌────────────────────────────────┐
│ 分析组件接口                    │
│  ├─ Inport/Outport 识别        │
│  ├─ 数据类型检测                │
│  └─ 采样时间获取                │
│                                │
│ 生成测试策略                    │
│  ├─ basic: 常值 + 阶跃响应      │
│  ├─ boundary: 零值 + 最大 + 跳变 │
│  └─ comprehensive: 全部        │
│                                │
│ 写入 .feature 文件              │
│  (Gherkin + TOML front-matter) │
│                                │
│ 执行 model_test                 │
│  ├─ draft_mode=true (快速验证)  │
│  └─ draft_mode=false (完整编译) │
│                                │
│ 生成 HTML 测试报告               │
└────────────────────────────────┘
```

### 生成的 Gherkin 测试文件示例

```gherkin
# --- front-matter:toml ---
model = "BCM_LockController.slx"
component = "BCM_LockController/CommandArbitration"
[inputs]
DoorStatus = "DoorStatus"
车速信号 = "VehicleSpeed"
[outputs]
LockCmd = "LockCmd"
UnlockCmd = "UnlockCmd"
# --- end front-matter ---

Feature: CommandArbitration Nominal Operation Tests
  Basic functional verification under normal operating conditions

Scenario: Nominal operation - constant inputs
  Verify component operates correctly with constant nominal inputs.
  Given inputs
    * DoorStatus = const(0)
    * 车速信号 = const(0)
  When simulate for 1.000s in Normal mode
  Then outputs
    * LockCmdInRange: LockCmd == [-inf .. inf]

Scenario: Step response - input transitions
  Verify component responds correctly to step changes in inputs.
  Given inputs
    * DoorStatus = const(0)
    * 车速信号 = step(0 -> 100 @ 1s)
  When simulate for 1.000s in Normal mode
  Then baseline "CommandArbitration_baseline.mat" with tolerances: ...
  Then outputs
    * LockCmdInRange: LockCmd == [-inf .. inf]
```

### 使用方法

```matlab
% 基本测试（常值 + 阶跃）
generateModelTests('path/to/Model.slx');

% 指定子系统的边界测试
generateModelTests('path/to/Model.slx', ...
    'Component', 'Model/SubsystemName', ...
    'Strategy', 'boundary');

% 全面测试（不执行，只生成 .feature 文件）
generateModelTests('path/to/Model.slx', ...
    'Strategy', 'comprehensive', ...
    'RunTests', false);
```

---

## 三合一流水线

```matlab
% 一键执行全部
runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx');

% 分步执行
runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx', ...
    'TestStrategy', 'comprehensive');
```

---

## 前提条件

- MATLAB R2023a+ with Simulink
- Simulink Test（用于 model_test）
- Simulink Report Generator（用于 PDF 生成）
- Simulink Agentic Toolkit（已配置 MCP 服务器）
- 在 MATLAB 中执行 `satk_initialize` 初始化工具包
