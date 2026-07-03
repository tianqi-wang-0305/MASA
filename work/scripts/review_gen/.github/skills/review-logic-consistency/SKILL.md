---
name: review-logic-consistency
description: "Review whether a Simulink model's logical implementation matches the software requirements. The AI reads requirements, explores the model using MCP tools, and reports behavioral inconsistencies."
license: MIT
metadata:
  author: MASA
  version: "1.0"
---

# Logic Consistency Review

Use this skill when you want to verify that a Simulink model's **behavior** matches the **software requirements**. Unlike interface checks (signal names, data types), this focuses on **functional correctness**.

## When to Use

- User describes requirements and asks "does the model implement this correctly?"
- User provides a requirement spec and wants to validate model behavior
- Before code generation, to catch logic errors early
- After model changes, to verify requirements are still met

## How It Works

```
User Requirements (natural language or spec document)
        │
        ▼
  Step 1: Parse Requirements
    ├── Identify functional blocks (controller, filter, state machine, etc.)
    ├── Identify input conditions and expected outputs
    ├── Identify thresholds, gains, timing parameters
    └── Identify mode/state transition logic
        │
        ▼
  Step 2: Explore Model with MCP Tools
    ├── model_overview(root)     → understand hierarchy
    ├── model_read(subsystem)    → read signal flow and algorithm
    ├── model_query_params       → get block parameters
    └── model_check              → structural validation
        │
        ▼
  Step 3: Compare Each Requirement
    ├── For each requirement:
    │   ├── Find the implementing blocks/subsystems
    │   ├── Verify algorithm matches spec (gain values, thresholds, logic)
    │   ├── Check signal routing is correct
    │   └── Flag any discrepancy
        │
        ▼
  Step 4: Report Findings
    ├── ✅ Implemented correctly
    ├── ⚠ Implemented but with differences (value mismatch, different approach)
    └── ❌ Not implemented / implemented incorrectly
```

## Requirement Pattern Recognition

When parsing requirements, map common phrases to Simulink implementation patterns:

| Requirement Phrase | Expected Model Pattern |
|-------------------|----------------------|
| "if X > threshold then Y" | RelationalOperator + Switch/LogicalOp |
| "smooth the signal" | Filter block (DiscreteFilter, TransferFcn) |
| "PI control with Kp=X, Ki=Y" | PID Controller or Gain+Integrator+Sum |
| "state machine with states A,B,C" | Stateflow Chart |
| "delay by N samples" | UnitDelay block |
| "clamp between min and max" | Saturation block |
| "look up value from table" | LookupTable block |
| "calculate error = target - actual" | Sum block with "+-" inputs |
| "accumulate / integrate" | Integrator or DiscreteIntegrator |
| "edge detection / rising edge" | DetectRisePositive block |
| "counter from 0 to N" | CounterLimited block |
| "pulse every T seconds" | PulseGenerator or SignalBuilder |

## Review Methodology

For EACH requirement, the AI should:

### 1. Locate the Implementation
Use `model_overview` to find relevant subsystems, then `model_read` to examine internal structure.

### 2. Verify Parameters
Use `model_query_params` to read Gain values, thresholds, lookup table data.
Compare against specified values in requirements.

### 3. Check Signal Flow
Trace signals from inputs through processing blocks to outputs.
Verify the data flow matches the requirement's described algorithm.

### 4. Identify Gaps
Document any requirement that has no corresponding implementation.
Document any implementation detail not specified in requirements.

## Output Format

Present findings in a structured format:

```
## Review: [Requirement Name]

### Requirement
[Quoted or paraphrased requirement text]

### Implementation
[Description of what the model does, with block paths]

### Verdict
✅ Match / ⚠ Partial / ❌ Mismatch

### Details
- Parameter check: Gain=2.0 (requirement) vs Gain=2.5 (model) → ⚠ differs
- Signal flow: OK
- Missing: [anything not implemented]

### Suggestion
[How to fix if mismatch]
```

## Example

```
## Review: Speed Auto-Lock

### Requirement
当车速超过 15 km/h 且所有车门关闭时，自动输出锁门指令

### Implementation
SpeedAutoLock 子系统:
  - VehicleSpeed → RelationalOp(>=) → [AND] → DetectRise → LockReq
  - DoorStatus → Sum(++++)(OR) → RelationalOp(==0) → [AND]
  - Threshold Constant = 15

### Verdict
✅ Match

### Details
- Threshold: 15 (requirement) vs 15 (model) → ✅ OK
- Door logic: All closed → AND gate → ✅ OK
- Edge detection: DetectRisePositive → ✅ single pulse
```

## Tools Required

- `model_overview` — model hierarchy
- `model_read` — signal flow and algorithm details
- `model_query_params` — parameter values
- `model_resolve_params` — workspace variables
