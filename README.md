# autoModeling — AI-Powered Simulink Automation Framework

基于 [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit) 的应用层软件自动化开发框架。  
通过 AI Agent + MCP 工具 + 自动化脚本，覆盖 **模型搭建 → 验证 → 测试 → 文档 → 代码生成** 全流程。

---

## 快速开始

### 前提条件

- MATLAB R2023a+ with Simulink
- Simulink Test（可选，用于测试生成）
- Simulink Report Generator（可选，用于 PDF 文档）

### 初始化

```matlab
% 1. 克隆仓库（包含 submodule）
git clone --recurse-submodules https://github.com/tianqi-wang-0305/autoModeling.git

% 2. 在 MATLAB 中初始化 Toolkit
addpath('work/simulink-agentic-toolkit')
satk_initialize
```

---

## 通过 Slash Commands 使用

在 VS Code 聊天中输入 `/` 选择命令，或在 MATLAB 中直接调用脚本。

### 模型搭建

| Command | 功能 | 入口脚本 |
|---------|------|---------|
| `/buildModel` | 从自然语言需求搭建 Simulink 模型骨架 | AI Agent + model_edit |
| `/autoLayout` | 自动布局：对齐端口、层级排列子系统 | `autoLayoutModel.m` |
| `/setPortTypes` | 按信号名前缀自动设置端口数据类型 | `autoSetPortDataTypes.m` |

### 验证与审查

| Command | 功能 | 入口脚本 |
|---------|------|---------|
| `/reviewModel` | 综合 Review（7 项检查 + 评分 A-D） | `reviewModel.m` |
| `/checkModel` | Model Advisor + 误差门限（CI 用） | `checkModelWithThreshold.m` |
| `/validateInterface` | Excel-模型一致性校验 | `validateModelExcel.m` |
| `/generateTraceMatrix` | 需求追溯矩阵生成 | `generateTraceMatrix.m` |

### 测试

| Command | 功能 | 入口脚本 |
|---------|------|---------|
| `/generateModelTests` | 自动生成 Gherkin 测试用例 + Test Harness | `generateModelTests.m` |
| `/analyzeCoverage` | MIL/SIL 覆盖率聚合看板 | `analyzeModelCoverage.m` |
| `/analyzeSensitivity` | 标定参数敏感性扫描分析 | `analyzeSensitivity.m` |

### 文档

| Command | 功能 | 入口脚本 |
|---------|------|---------|
| `/generateAISDD` | AI 增强 ASPICE 详细设计 PDF | `DdGeneration_AI.m` |
| `/runAIPipeline` | 一键流水线：SDD + 测试 | `runAIPipeline.m` |

---

## 项目结构

```
autoModeling/
├── .github/
│   ├── AGENTS.md              ← Agent 总说明
│   ├── prompts/               ← 12 个 Slash Command 定义（唯一入口）
│   └── workflows/
│       └── simulink-ci.yml.disabled  ← CI 流水线（已暂停）
│
├── work/
│   ├── simulink-agentic-toolkit/    ← [submodule] MCP-based 工具包
│   ├── matlab-mcp-core-server/      ← [submodule] MATLAB MCP 服务
│   │
│   ├── scripts/                     ← 自动化脚本
│   │   ├── runAIPipeline.m          ← 统一入口
│   │   ├── ai_sdd/                 ← SDD 文档生成
│   │   │   ├── DdGeneration_AI.m   ← AI 增强 SDD 生成器
│   │   │   ├── DdGeneration_ASPICE.m ← ASPICE 基线版
│   │   │   ├── analyzeModelDeepForSDD.m ← 深度分析引擎
│   │   │   ├── .headless/          ← 无头模式工具
│   │   │   └── ref/                ← ASPICE 模板
│   │   ├── review_gen/             ← 综合 Review
│   │   │   ├── reviewModel.m       ← Review 引擎（7 项检查）
│   │   │   ├── check_naming_convention.m ← 命名规范
│   │   │   ├── check_connection_rules.m  ← 连线完整性
│   │   │   ├── check_hierarchy_integrity.m ← 层级完整性
│   │   │   ├── report_utils.m      ← 报告工具
│   │   │   └── ref/                ← 连线/层级规范
│   │   ├── test_gen/               ← Gherkin 测试生成
│   │   ├── quality_gen/            ← Model Advisor 门限
│   │   ├── model_gen/              ← 模型搭建 + Skill
│   │   ├── code_gen/               ← 代码生成流水线
│   │   ├── data_mng/               ← Excel ↔ 模型 数据管理
│   │   ├── chk_mng/                ← 端口类型检查
│   │   ├── coverage_gen/           ← 覆盖率分析
│   │   ├── sensitivity_gen/        ← 敏感性分析
│   │   ├── layout_gen/             ← 自动布局
│   │   ├── validation_gen/         ← 一致性校验 + 追溯
│   │   ├── design_gen/             ← 设计文档
│   │   └── hooks/                  ← Git Hooks
│   │
│   ├── pkg/+NoneSAR/               ← 自定义存储类
│   └── tst_mdl/                    ← 测试模型
│
├── .gitignore
└── README.md
```

---

## 自动化脚本速查

### 代码生成

| 脚本 | 说明 |
|------|------|
| `code_gen/src/run_all.m` | 批量代码生成：Model Advisor → slbuild → A2L |
| `code_gen/src/ModelConfigCommon_v08.m` | 统一模型配置集（AUTOSAR/ERT） |
| `code_gen/src/runModelAdvisorChecks.m` | 50+ Model Advisor 检查项 |
| `code_gen/src/mapSimulink2AUTOSAR.m` | AUTOSAR 存储类映射 |

### 数据管理

| 脚本 | 说明 |
|------|------|
| `data_mng/src/Excel2Cal.m` | Excel 标定表 → MATLAB Parameter 对象 |
| `data_mng/src/Cal2Excel.m` | MATLAB 参数 → Excel（逆向） |
| `data_mng/src/Excel2Port.m` | Excel 接口定义 → Simulink 端口 |
| `data_mng/src/export_simulink_top_ports.m` | 模型端口 → Excel 导出 |
| `data_mng/src/ImportARXML.m` | ARXML → Simulink SWC 导入 |
| `data_mng/src/batch_color_models.m` | 批量模型着色（端口/标定） |
| `data_mng/src/autoSetPortDataTypes.m` | 信号名前缀 → 端口数据类型 |

### 检查与审计

| 脚本 | 说明 |
|------|------|
| `review_gen/src/check_naming_convention.m` | 命名规范 + 信号/标定前缀校验 |
| `review_gen/src/check_connection_rules.m` | 连线完整性检查 |
| `review_gen/src/check_hierarchy_integrity.m` | 层级完整性检查 |
| `chk_mng/src/check_io_port_datatype_definition.m` | 端口数据类型显式定义检查 |
| `quality_gen/src/checkModelWithThreshold.m` | Model Advisor 门限检查 |
| `review_gen/src/reviewModel.m` | 综合 Review（7 项合一） |

---

## 命名规范

### 信号命名

```
{type}{Name}        例如: u16VehicleSpeed → uint16
```

| 前缀 | 类型 | 示例 |
|------|------|------|
| `s8`/`s16`/`s32` | int8/16/32 | `s16VehicleSpeed` |
| `u8`/`u16`/`u32` | uint8/16/32 | `u8DoorStatus` |
| `f32`/`f64` | single/double | `f32Temperature` |
| `b`/`bool` | boolean | `bLockRequest` |

### 标定命名

```
cal_{type}{Name}    例如: cal_u16Threshold
```

| 前缀 | 类型 | 示例 |
|------|------|------|
| `cal_u8`/`cal_u16`/`cal_u32` | uint 标定 | `cal_u16Threshold` |
| `cal_s16`/`cal_s32` | int 标定 | `cal_s16SpeedLimit` |
| `cal_f32`/`cal_f64` | float 标定 | `cal_f32GainValue` |
| `cal_b` | boolean 标定 | `cal_bEnableFlag` |

> 使用 `/setPortTypes` 自动按此规则批量更新端口数据类型。

---

## 环境依赖

| 组件 | 版本要求 | 用途 |
|------|---------|------|
| MATLAB | R2023a+ | 核心运行环境 |
| Simulink | — | 模型开发 |
| Simulink Test | 可选 | model_test 执行 |
| Simulink Report Generator | 可选 | PDF 报告生成 |
| Simulink Check | 可选 | Model Advisor 检查 |
| Embedded Coder | 可选 | 代码生成 |

## Submodules

| 仓库 | 路径 | 用途 |
|------|------|------|
| [matlab/simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit) | `work/simulink-agentic-toolkit/` | MCP 工具 + MBD 技能 |
| [matlab/matlab-mcp-core-server](https://github.com/matlab/matlab-mcp-core-server) | `work/matlab-mcp-core-server/` | MATLAB MCP 服务器 |

---

## 许可

本项目中的自定义脚本和技能遵循 MIT 协议。  
Submodule 组件 `simulink-agentic-toolkit` 和 `matlab-mcp-core-server` 遵循各自的开源许可。
