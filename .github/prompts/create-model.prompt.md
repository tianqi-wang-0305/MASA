---
description: "Build any Simulink model from natural language requirements. AI uses model_edit to create ports, subsystems, and logic dynamically."
name: "Build Simulink Model"
argument-hint: "<describe your requirements>"
---

# Build Simulink Model

Transform natural language software requirements into a Simulink model skeleton. The AI parses your requirements, designs the architecture, and builds the model using `model_edit` — **no MATLAB scripting needed**.

## Usage

Describe what you want the model to do:

```
/buildModel A PID speed controller with:
  - Input: target speed, actual speed
  - Output: throttle command
  - Logic: P=2.0, I=0.5, D=0.1, saturate output to [0, 100]
```

```
/buildModel A signal processing chain:
  - Input: raw sensor signal
  - Output: filtered and scaled signal
  - Steps: low-pass filter → gain scaling → saturation clamp
```

```
/buildModel A mode selector with:
  - Inputs: mode(0/1/2), A, B, C
  - Output: selected
  - Logic: mode 0=pass A, mode 1=pass B, mode 2=pass C
```

## How It Works

The AI agent uses MCP tools to build the model dynamically:

```
Your Requirements (natural language)
        │
        ▼
  1. Parse Requirements → Identify inputs, outputs, logic
        │
        ▼
  2. Design Architecture → Choose block types, plan hierarchy
        │
        ▼
  3. Build with model_edit → Create model, add blocks, wire
        │
        ▼
  4. Verify → model_read + model_check
        │
        ▼
  5. Present → Structure + optimization suggestions
```

## Batch Generation

For standardized/parameterized model generation (e.g., creating 5 similar controllers), use:

```matlab
% Define spec as a struct or JSON file
spec = jsondecode(fileread('controller_spec.json'));
buildModelFromSpec(spec);

% Or inline
buildModelFromSpec(struct('modelName','MyCtrl', 'inputs', ..., 'outputs', ...));
```

See `work/scripts/model_gen/src/buildModelFromSpec.m` for details.

## Prerequisites

- MATLAB running with `satk_initialize` executed
- Simulink Agentic Toolkit configured
