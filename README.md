# MASA — Model-based Automation for Simulink Applications

基于 [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit) 的应用层软件自动化开发框架。  
通过 AI Agent + MCP 工具 + 自动化脚本，覆盖 **模型搭建 → 验证 → 测试 → 文档 → 代码生成** 全流程。

---

## 快速开始

### 前提条件

- MATLAB R2023a+ with Simulink
- Go 1.20+（用于编译 MCP 服务器，仅首次需要）

### 初始化

```matlab
% 1. 克隆仓库（包含 submodule）
git clone --recurse-submodules https://github.com/tianqi-wang-0305/masa.git

% 2. 编译 MCP 服务器（仅首次）
cd work/matlab-mcp-core-server && make build && cd ../..
cp work/matlab-mcp-core-server/.bin/maca64/matlab-mcp-core-server ~/.matlab/agentic-toolkits/bin/
~/.matlab/agentic-toolkits/bin/matlab-mcp-core-server --setup-matlab --matlab-root="/Applications/MATLAB_R2025a.app"

% 3. 在 MATLAB 中初始化 Toolkit
addpath('work/simulink-agentic-toolkit')
satk_initialize
```

---

## 通过 Slash Commands 使用

在 VS Code 聊天中输入 `/` 选择命令，或在 MATLAB 中直接调用脚本。

### 模型搭建

| Command | 功能 | 入口/方法 |
|---------|------|-----------|
| `/buildModel` | **主入口**: 从自然语言需求动态搭建 Simulink 模型骨架（AI 自动用 `model_edit` 构建，无需预写脚本） | AI Agent + SKILL.md |
| `/autoLayout` | 自动布局：对齐端口、层级排列子系统 | `autoLayoutModel.m` |
| `/setPortTypes` | 按信号名前缀自动设置端口数据类型 | `autoSetPortDataTypes.m` |

### 验证与审查

| Command | 功能 | 入口 |
|---------|------|------|
| `/reviewModel` | 综合 Review（7 项检查 + 评分 A-D + 修改建议） | `reviewModel.m` |
| `/reviewLogic` | 逻辑一致性审查：需求功能 vs 模型行为 | AI Agent + model_read |
| `/reviewConsistency` | 接口比对：Excel 需求 vs 模型信号/标定清单 | `reviewReqConsistency.m` |
| `/checkModel` | Model Advisor + 误差门限（CI 用） | `checkModelWithThreshold.m` |

### 数据导出

| Command | 功能 | 入口 |
|---------|------|------|
| `/exportCal` | 导出标定（cal_ 前缀）→ Excel + .m 文件 | `exportCalToExcel.m` |
| `/exportSignals` | 导出 I/O 信号 → Excel（含命名规范校验） | `exportSignalsToExcel.m` |
| `/exportAll` | 导出信号 + 标定 → 一个 Excel（两个 Sheet） | `exportAllToExcel.m` |
| `/validateInterface` | Excel-模型一致性校验 | `validateModelExcel.m` |
| `/generateTraceMatrix` | 需求追溯矩阵生成 | `generateTraceMatrix.m` |

### 测试

| Command | 功能 | 入口 |
|---------|------|------|
| `/generateModelTests` | 自动生成 Gherkin 测试用例 + Test Harness | `generateModelTests.m` |
| `/analyzeCoverage` | MIL/SIL 覆盖率聚合看板 | `analyzeModelCoverage.m` |
| `/analyzeSensitivity` | 标定参数敏感性扫描分析 | `analyzeSensitivity.m` |

### 文档

| Command | 功能 | 入口 |
|---------|------|------|
| `DdGeneration.m`（已有）| 详细设计 PDF | 用户已有的脚本 |

### 通用脚本

| 脚本 | 功能 |
|------|------|
| `buildModelFromSpec.m` | 通用模型构建器：从结构化 Spec 自动生成任意 Simulink 模型（替代为每个新模型手写脚本） |

---

## 模型搭建方式对比

| 方式 | 适用场景 | 方法 |
|------|---------|------|
| **AI 驱动** `/buildModel` | 一次性/临时需求 | AI 读需求 → `model_edit` 动态构建 |
| **通用脚本** `buildModelFromSpec` | 批量/标准化生成 | 定义 JSON Spec → 脚本自动生成 |

---

## 项目结构

```
masa/
├── .github/
│   ├── AGENTS.md              ← Agent 总说明
│   ├── prompts/               ← 13 个 Slash Command 定义
│   └── workflows/
│       └── simulink-ci.yml.disabled  ← CI 流水线（已暂停）
│
├── work/
│   ├── simulink-agentic-toolkit/    ← [submodule] MCP-based 工具包
│   ├── matlab-mcp-core-server/      ← [submodule] MATLAB MCP 服务
│   │
│   ├── scripts/
│   │   ├── review_gen/             ← 综合 Review + 命名/连线/层级检查
│   │   │   ├── reviewModel.m       ← Review 引擎（7 项检查 + 修改建议）
│   │   │   ├── reviewReqConsistency.m ← 需求-模型一致性比对
│   │   │   ├── generateFixSuggestions.m ← 修改建议生成
│   │   │   ├── check_naming_convention.m ← 命名规范
│   │   │   ├── check_connection_rules.m  ← 连线完整性
│   │   │   ├── check_hierarchy_integrity.m ← 层级完整性
│   │   │   └── ref/                ← 连线/层级规范
│   │   ├── test_gen/               ← Gherkin 测试生成
│   │   ├── quality_gen/            ← Model Advisor 门限
│   │   ├── model_gen/              ← 模型搭建 + Skill (/buildModel)
│   │   │   ├── src/buildModelFromSpec.m ← 通用模型构建器
│   │   │   └── .github/skills/     ← build-simulink-from-requirements SKILL
│   │   ├── type_gen/               ← 自动设置端口数据类型（按前缀）
│   │   │   └── src/autoSetPortDataTypes.m
│   │   ├── data_mng/               ← Excel ↔ 模型 数据管理
│   │   │   ├── exportCalToExcel.m  ← 标定导出 + .m 文件
│   │   │   ├── exportSignalsToExcel.m ← 信号导出
│   │   │   ├── exportAllToExcel.m  ← 信号+标定导出
│   │   │   └── ... (原有 Excel2Cal, Cal2Excel 等)
│   │   ├── code_gen/               ← 代码生成流水线
│   │   ├── chk_mng/                ← 端口类型检查
│   │   ├── coverage_gen/           ← 覆盖率分析
│   │   ├── sensitivity_gen/        ← 敏感性分析
│   │   ├── layout_gen/             ← 自动布局
│   │   ├── validation_gen/         ← 一致性校验 + 追溯矩阵
│   │   └── hooks/                  ← Git Hooks
│   │
│   ├── pkg/+NoneSAR/               ← 自定义存储类（NoneSAR.Parameter）
│   └── tst_mdl/                    ← 测试模型
│
├── .gitignore
└── README.md
```

---

## 自动化脚本速查

### 标定导出

| 脚本 | 说明 |
|------|------|
| `data_mng/src/exportCalToExcel.m` | 扫描模型所有层级 Constant/Gain 块的 Value 属性，查找 `cal_`/`Cal_` 开头的标定引用，去重后导出 Excel + `.m` 文件 |
| `data_mng/src/exportSignalsToExcel.m` | 导出 Inport/Outport 信号含命名规范校验 |
| `data_mng/src/exportAllToExcel.m` | 信号 + 标定 → 一个 Excel（两个 Sheet）+ `.m` 文件 |
| `data_mng/src/export_simulink_top_ports.m` | 原端口导出脚本 |

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
| `data_mng/src/ImportARXML.m` | ARXML → Simulink SWC 导入 |
| `data_mng/src/batch_color_models.m` | 批量模型着色（端口/标定） |

### 检查与审计

| 脚本 | 说明 |
|------|------|
| `review_gen/src/reviewModel.m` | 综合 Review（7 项检查 + 修改建议 + HTML 报告） |
| `review_gen/src/reviewReqConsistency.m` | 需求-模型一致性比对（Excel vs 模型） |
| `review_gen/src/generateFixSuggestions.m` | 根据 Review 结果生成具体修改建议 |
| `review_gen/src/check_naming_convention.m` | 命名规范 + 信号/标定前缀校验 |
| `review_gen/src/check_connection_rules.m` | 连线完整性检查 |
| `review_gen/src/check_hierarchy_integrity.m` | 层级完整性检查 |
| `chk_mng/src/check_io_port_datatype_definition.m` | 端口数据类型显式定义检查 |
| `quality_gen/src/checkModelWithThreshold.m` | Model Advisor 门限检查 |

---

## 模型搭建与命名规范

### 模块使用规则

- ❌ **禁止**使用 Simulink 库中的复合模块（PID Controller、Discrete Filter 等）
- ✅ **必须**用基本模块搭建：`Gain` + `Sum` + `Integrator` + `UnitDelay` 等

### 信号命名

```
{type}{Name}        例如: u16VehicleSpeed → uint16
```

| 前缀 | 类型 | 示例 |
|------|------|------|
| `u8`/`u16`/`u32` | uint8/16/32 | `u16VehicleSpeed` |
| `s16`/`s32` | int16/32 | `s16Position` |
| `f32` | single（浮点唯一选择） | `f32Temperature` |
| `b`/`bool` | boolean | `bLockRequest` |
| ~~`f64`~~ | ~~double~~ | ❌ **禁止使用** |
### 标定命名

```
cal_{type}{Name}    例如: cal_u16Threshold
```

| 前缀 | 类型 | 示例 |
|------|------|------|
| `cal_u16` | uint16 标定 | `cal_u16Threshold` |
| `cal_s16` | int16 标定 | `cal_s16SpeedLimit` |
| `cal_f32` | single 标定 | `cal_f32GainValue` |
| `cal_b` | boolean 标定 | `cal_bEnableFlag` |

> 使用 `/setPortTypes` 自动按规则更新端口数据类型。
> 使用 `/exportCal` 自动扫描模型中所有引用 `cal_` 的标定并导出。

---

## MCP 服务器配置

SDD 生成和模型深度分析依赖 MCP 工具（`model_overview`, `model_read` 等）。首次使用需要：

```bash
# 1. 编译 MCP 服务器（从 submodule）
cd work/matlab-mcp-core-server
make build
cp .bin/maca64/matlab-mcp-core-server ~/.matlab/agentic-toolkits/bin/

# 2. 安装 MATLAB 端组件
~/.matlab/agentic-toolkits/bin/matlab-mcp-core-server --setup-matlab \
    --matlab-root="/Applications/MATLAB_R2025a.app"

# 3. 在 MATLAB 中初始化
addpath('work/simulink-agentic-toolkit')
satk_initialize
```

验证成功输出：
```
Prerequisites  ✓ MATLAB 25.1.0 ...
MATLAB Env     ✓ All 7 tool entry points on path
MCP Server     ✓ matlab-mcp-core-server found
MCP Connect    ✓ shareMATLABSession available
Result: PASS
```

---

## 环境依赖
| 组件 | 版本要求 | 用途 |
|------|---------|------|
| MATLAB | R2023a+ | 核心运行环境 |
| Simulink | — | 模型开发 |
| Simulink Test | 可选 | model_test 执行 |
| Simulink Report Generator | 可选 | PDF 报告生成 |
| Go | 1.20+ | 编译 MCP 服务器（仅首次） |
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
