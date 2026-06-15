---
description: "Build a Simulink model from natural language software requirements. Parses inputs/outputs/logic, designs architecture, and constructs the model using model_edit."
name: "Build Simulink Model"
argument-hint: "<describe your requirements>"
---

# Build Simulink Model

Transform natural language software requirements into a Simulink model skeleton using `model_edit`. The AI will parse your requirements, design the architecture, build the model, and validate it.

## Usage

Describe what you want the model to do. Examples:

```
/buildModel A PID speed controller with:
  - Input: target speed, actual speed
  - Output: throttle command
  - Logic: P gain = 2.0, I gain = 0.5, D gain = 0.1, saturate output to [0, 100]
```

```
/buildModel A signal processing chain:
  - Input: raw sensor signal
  - Output: filtered and scaled signal
  - Steps: low-pass filter → gain scaling → saturation clamp
```

```
/buildModel A mode selector with:
  - Inputs: mode_select(0/1/2), signal_A, signal_B, signal_C
  - Output: selected_output
  - Logic: mode 0=pass A, mode 1=pass B, mode 2=pass C
```

## How It Works

The AI agent follows a 5-step process:

```
Your Requirements (natural language)
        │
        ▼
  1. Parse Requirements → Identify inputs, outputs, logic, parameters
        │
        ▼
  2. Design Architecture → Subsystems, data flow, block types
        │
        ▼
  3. Build with model_edit → Ports → Subsystems → Logic → Wiring
        │
        ▼
  4. Verify → model_read + model_check
        │
        ▼
  5. Present → Model structure + manual optimization suggestions
```

## Prerequisites

- MATLAB running with `satk_initialize` executed
- Simulink Agentic Toolkit configured

## What You Get

- A working Simulink model skeleton (.slx)
- Input/output ports as specified
- Subsystem decomposition matching your functional requirements
- Basic logic implemented (gains, comparators, state machines, etc.)
- `model_check` validation results
- Suggestions for manual optimization

> **Note**: The generated model is a skeleton for you to refine. The AI builds the structure and basic logic; you optimize layout, add detail, and tune parameters.
