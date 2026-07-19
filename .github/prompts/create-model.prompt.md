---
agent: agent
description: "Build any Simulink model from natural language requirements. AI uses model_edit to create ports, subsystems, and logic dynamically."
name: "create-model"
argument-hint: "<describe your requirements>"
---

# Build Simulink Model

> **🚨 关键**：执行此命令前，AI 必须**先读取 skill 文件** `work/scripts/model_gen/.github/skills/build-simulink-from-requirements/SKILL.md`，该文件包含：
> - 详细的端口/标定命名规范（`{type}{Name}` / `cal_{type}{Name}`）
> - 禁止使用 double，所有浮点用 single
> - 禁止使用库模块（PID Controller 等），必须用基本模块组合
> - 完整的模型架构和要求

Transform natural language software requirements into a Simulink model skeleton. **First read the SKILL.md** for naming/data type rules, then build with `model_edit`.

## 模型架构要求

生成的模型必须遵循以下架构：

```
ModelName
├── Inports:  u16VehicleSpeed, f32Temperature, bEnable  ({type}{Name} 规范)
├── Outports: u8MotorCmd, s16Position                   ({type}{Name} 规范)
│
└── SubSystem: MainSubsystem (wrapper, 包含所有逻辑)
    ├── Inports  (与顶层一一对应)
    ├── Outports (与顶层一一对应)
    │
    ├── SubSystem: SignalAcquisition    ← 信号调理/类型转换
    ├── SubSystem: {功能模块1}          ← 根据需求创建
    ├── SubSystem: {功能模块2}          ← 根据需求创建
    ├── SubSystem: OutputArbitration    ← 输出仲裁/合并
    │
    └── 内部连线: In → Acquisition → 功能模块 → Arbitration → Out
```

## Usage

Describe what you want the model to do.

```
/buildModel A PID speed controller with:
  - Input: target speed (uint16), actual speed (single)
  - Output: throttle command (single, 0-100)
  - Logic: P=2.0, I=0.5, D=0.1, saturate output
```

```
/buildModel A signal processing chain:
  - Input: raw sensor signal
  - Output: filtered and scaled signal
  - Steps: low-pass filter → gain scaling → saturation clamp
```

## Build Steps (must follow exactly)

### Phase 1: Read SKILL.md
Read `work/scripts/model_gen/.github/skills/build-simulink-from-requirements/SKILL.md` for all naming and data type rules.

### Phase 2: Create root model
```
model_edit(create, modelName)
Configure: Solver=FixedStepDiscrete, FixedStep=0.01, StopTime=100
```

### Phase 3: Add root Inport/Outport blocks
```
model_edit(add_block, Inport)   × N   // ref: p1, p2, ...
model_edit(add_block, Outport)  × M   // ref: q1, q2, ...
Names must follow: {type}{Name}       // e.g. u16VehicleSpeed
Data types: single for float, never double
```

### Phase 4: Create MainSubsystem wrapper + internal subsystems
```
model_edit(create_subsystem, "MainSubsystem")   // wrapper
model_edit(create_subsystem, "SignalAcquisition")  // inside wrapper
model_edit(create_subsystem, "...")              // functional subsystems
model_edit(create_subsystem, "OutputArbitration")  // output merge
```

### Phase 5: Add Inport/Outport inside each subsystem
Each subsystem must have its own Inport/Outport blocks (R2025a creates empty subsystems).
Use `add_block('built-in/Inport', ...)` and `add_block('built-in/Outport', ...)` inside each.

### Phase 6: Wire top level
```
Root Inports  → MainSubsystem (port-to-port)
MainSubsystem → Root Outports (port-to-port)
In R2025a, use add_line(modelName, 'InportName/1', 'MainSubsystem/1', 'autorouting','on')
```

### Phase 7: Wire inside MainSubsystem
```
MainSubsystem Inports → SignalAcquisition → functional subsystems → OutputArbitration
OutputArbitration → MainSubsystem Outports
```

### Phase 8: Populate functional logic
Each functional subsystem gets basic blocks (Gain, Sum, Logic, RelationalOperator, etc.)
based on requirements analysis. Follow "禁止库模块" rule from SKILL.md.

### Phase 9: Verify and present
```
model_check → validate structure
model_read  → present summary
```

## Prerequisites

- MATLAB running with `satk_initialize` executed
- Simulink Agentic Toolkit configured
- **重要**：R2025a 中 SubSystem 无默认 In1/Out1，必须手动添加
