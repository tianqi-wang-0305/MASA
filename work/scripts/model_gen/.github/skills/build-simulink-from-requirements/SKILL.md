---
name: build-simulink-from-requirements
description: "Build Simulink models from natural language software requirements. Use when user describes a control algorithm, signal processing chain, or state machine they want implemented as a Simulink model. Parses requirements, designs architecture, builds with model_edit, and validates with model_check."
license: MIT
metadata:
  author: autoModeling
  version: "1.0"
---

# Build Simulink Models from Requirements

Use this skill when the user gives you **natural language software requirements** and asks you to build a Simulink model. This skill provides a systematic process to transform requirements into a working Simulink model skeleton that the user can then optimize.

## When to Use

- User describes a controller, algorithm, or function in plain language
- User says "build a model that..." or "create a Simulink model for..."
- User provides a spec with inputs, outputs, and logic descriptions
- User asks for a model skeleton/framework that they will refine later

## When NOT to Use

- User only wants to read or query an existing model → use `model_overview` / `model_read`
- User wants to edit one specific block or parameter → use `model_edit` directly
- User wants tests or documentation → use `testing-simulink-models` or `sdd-detail-design-generation`

## Core Workflow

```
User Requirements (natural language)
        │
        ▼
  Step 1: Parse Requirements
    ├── Identify inputs (sensors, commands, signals)
    ├── Identify outputs (actuators, commands, indicators)
    ├── Identify logic/algorithm (control, arithmetic, state machine)
    └── Identify parameters/calibrations (thresholds, gains, lookup tables)
        │
        ▼
  Step 2: Design Architecture
    ├── Decompose into functional subsystems
    ├── Define data flow between subsystems
    ├── Choose block types (Gain, Sum, Logical, Relational, Stateflow, etc.)
    └── Plan model hierarchy (top-level → subsystems → leaf blocks)
        │
        ▼
  Step 3: Build Model (model_edit)
    ├── Create model: new_system + open_system
    ├── Add top-level Inport/Outport blocks
    ├── Add subsystems for functional decomposition
    ├── Populate each subsystem with internal logic
    └── Wire connections between blocks
        │
        ▼
  Step 4: Verify (model_read + model_check)
    ├── Read back the structure with model_read
    ├── Validate connectivity with model_check
    └── Fix any error-severity issues
        │
        ▼
  Step 5: Present to User
    ├── Show model structure
    ├── List what was built
    └── Suggest manual optimizations
```

## Step 1: Parse Requirements

Extract structured information from the user's natural language description.

### Input Identification

| Clue in Requirements | Simulink Block |
|---------------------|----------------|
| "sensor", "measurement", "speed", "temperature", "position" | Inport |
| "button", "switch", "request", "command" | Inport (boolean) |
| "status", "flag", "state" | Inport (boolean/enum) |

### Output Identification

| Clue in Requirements | Simulink Block |
|---------------------|----------------|
| "actuator", "motor", "valve", "lamp", "LED" | Outport |
| "command", "instruction", "setpoint" | Outport |
| "indicator", "display", "signal" | Outport |

### Logic Pattern Recognition

| Requirement Pattern | Implementation Strategy |
|--------------------|----------------------|
| "if X then Y", "when X, do Y", "X triggers Y" | RelationalOperator → LogicalOperator, or DetectRisePositive |
| "X > threshold", "X exceeds limit" | RelationalOperator (>=, >) + Constant |
| "combine X and Y", "X OR Y", "X AND Y" | LogicalOperator (OR, AND) |
| "sum of X and Y", "difference", "error = target - actual" | Sum |
| "scale by K", "multiply by gain" | Gain |
| "filter", "smooth", "average" | DiscreteFilter or TransferFcn |
| "integrate", "accumulate" | Integrator or DiscreteIntegrator |
| "look up table", "map", "characteristic curve" | LookupTable or 1-D Lookup Table |
| "state machine", "mode", "state transition" | Stateflow Chart |
| "counter", "count up/down" | CounterFree-Running or CounterLimited |
| "delay", "hold", "sample and hold" | Delay or UnitDelay |
| "priority", "arbitration", "override" | Switch or LogicalOperator with priority logic |
| "clamp", "limit", "saturate" | Saturation |
| "pulse", "timer", "timeout" | DiscretePulseGenerator or MATLAB Function with timer |

### Parameter/Calibration Identification

| Clue | Practice |
|------|----------|
| Hardcoded thresholds (15 km/h, 5 km/h) | Extract to workspace variable (Kmh_AutoLock, Kmh_UnlockInhibit) |
| Gain values | Use Gain block with variable name (Kp_SpeedCtrl) |
| Lookup table data | Use Lookup Table with variable name (TorqueMap_Data) |

## Step 2: Design Architecture

### Architecture Patterns

**Pattern A: Feed-forward chain** (signal processing)
```
Inport → [Filter] → [Gain] → [Sum] → Outport
```

**Pattern B: Feedback control** (PID, closed-loop)
```
Inport(ref) → [Sum] → [PID Controller] → Outport(actuator)
                ↑                          │
                └──── Sensor ──────────────┘
```

**Pattern C: Decision/routing** (logic-based)
```
Inport(decision_var) → [RelationalOp] → [Switch] → Outport
Inport(signal_A) ──────────────────────────┘
Inport(signal_B) ──────────────────────────┘
```

**Pattern D: State machine** (mode-based)
```
Inport(events) → [Stateflow Chart] → Outport(commands)
                └── [enable/trigger] ──┘
```

**Pattern E: Multi-function** (combined, most common for real applications)
```
Top Level
├── SubSystem: Signal Conditioning    ── filter, scale, convert
├── SubSystem: Logic/Core Algorithm   ── main decision logic or state machine
├── SubSystem: Output Processing      ── saturate, format, drive
└── SubSystem: Diagnostics            ── fault detection, monitoring (if applicable)
```

### Decomposition Guidelines

- If requirements have 3-5 distinct functions → use **Pattern E** (subsystems)
- If requirements describe a single formula/math → use **Pattern A** (flat)
- If requirements describe states/modes → use **Pattern D** (Stateflow)
- Combine patterns as needed for complex requirements

## Step 3: Build with model_edit

### Sequence of model_edit Calls

```json
// Call 1: Create model and add ports + subsystems at root
// Use layout_mode="full" for new model
[
  {"op": "add_block", "type": "Inport", "name": "InputName1", "ref": "p1"},
  {"op": "add_block", "type": "Inport", "name": "InputName2", "ref": "p2"},
  {"op": "add_block", "type": "Outport", "name": "OutputName1", "ref": "p3"},
  {"op": "add_block", "type": "SubSystem", "name": "SubName1", "ref": "ss1"},
  {"op": "add_block", "type": "SubSystem", "name": "SubName2", "ref": "ss2"}
]

// Call 2: Populate SubName1's scope with internal blocks
// First read discovered block IDs: model_read("Model", "root", "1")
// Then edit using the blk_X ID for the subsystem scope
```

> **Important**: model_edit's `scope` parameter requires block ID (like `blk_5`), NOT full path strings. Use `model_read` after creating a subsystem to discover its `blk_X` ID.

### Block Type Reference (Common)

| Block Type | JSON type field | Notes |
|-----------|----------------|-------|
| Input port | `Inport` | |
| Output port | `Outport` | |
| Constant | `Constant` | Set `Value` param |
| Gain | `Gain` | Set `Gain` param |
| Sum | `Sum` | Set `Inputs` param (`++`, `+--`, `++++`) |
| Product | `Product` | Set `Inputs` param |
| Relational Op | `RelationalOperator` | Set `Operator`: `==`, `>=`, `>`, `<`, `<=`, `!=` |
| Logical Op | `LogicalOperator` | Set `Operator`: `AND`, `OR`, `NAND`, `NOR`, `XOR`, `NOT` |
| Switch | `Switch` | Routes input based on threshold |
| Saturation | `Saturation` | Set `UpperLimit`, `LowerLimit` |
| Integrator | `Integrator` | |
| Discrete Filter | `DiscreteFilter` | |
| Unit Delay | `UnitDelay` | |
| Detect Rise | `DetectRisePositive` | Outputs true on rising edge |
| Lookup Table | `LookupTable` | Set `Table`, `BP1` params |
| SubSystem | `SubSystem` | Container for grouping |
| Stateflow Chart | `Chart` | Added as SubSystem then populated via SF scope |
| MATLAB Function | `MATLAB Function` | Custom algorithm |
| Bus Creator | `BusCreator` | Group signals |
| Bus Selector | `BusSelector` | Extract signals from bus |
| Data Store Memory | `DataStoreMemory` | Shared data across subsystems |
| From/Goto | `From`, `Goto` | Signal routing without lines |
| Scope | `Scope` | Debug/visualization |

### Wiring (connect operations)

```json
// Standard signal connection
{"op": "connect", "target": "blk_X.y1 -> blk_Y.u1"}

// Named signal
{"op": "connect", "target": "blk_X.y1 -> blk_Y.u1",
 "params": {"SignalName": "MySignal"}}

// Chained refs (within same call)
{"op": "add_block", "type": "Gain", "name": "MyGain", "ref": "g1"},
{"op": "connect", "target": "#p1.y1 -> #g1.u1"}
```

### Configuration After Building

After the structure is built, configure block parameters if the requirements specify values:

```json
// Set block parameters
{"op": "configure", "target": "blk_X",
 "params": {"Gain": "2.5", "SampleTime": "0.01"}}

// Set model solver settings
{"op": "configure", "target": "config:ModelName",
 "params": {"Solver": "FixedStepDiscrete", "FixedStep": "0.01"}}
```

## Step 4: Verify

After ALL model_edit calls are complete:

1. **Read back**: `model_read("Model", "root", "1")` to verify structure
2. **Check**: `model_check("Model", "root", "["all"])` to find issues
3. **Fix**: Any `error`-severity unconnected ports or dangling lines
4. **Open**: `open_system("Model")` so the user can see the result

## Step 5: Present to User

Provide a summary in this format:

```
## Model: ModelName

### Architecture
Top Level
├── SubSystem1     ── {role description}
├── SubSystem2     ── {role description}
└── SubSystem3     ── {role description}

### Interfaces
- Inputs:  {input names}
- Outputs: {output names}

### Key Logic
- {logic point 1}
- {logic point 2}

### Suggested Manual Optimizations
1. {layout adjustment}
2. {parameter extraction}
3. {add Stateflow for complex logic}
```

## Common Pitfalls

1. **Block ID vs Path**: After creating blocks with model_edit, use the returned `blk_X` IDs or `model_read` to discover them. Never guess block IDs.

2. **Scope per call**: Each model_edit call operates in exactly one scope. To edit inside a subsystem, you need a separate call with that subsystem's scope.

3. **Autolayout**: model_edit has built-in autolayout. Use `layout_mode="full"` for new/empty scopes, `"incremental"` when adding to existing layouts.

4. **Stateflow two-step**: Add Chart block in SL scope first, then use `model_read` to discover the chart's scope ID (`sf_X`), then populate internals in SF scope.

5. **Keep it simple**: Build a skeleton that works - the user will optimize layout, add detail, and refine parameters. Don't try to build a production-ready model in one shot.

6. **Model config**: After building, set solver type and step size appropriate for the application (FixedStepDiscrete for discrete controllers, VariableStep for plant models).
