---
description: "Review whether a Simulink model's logical behavior matches software requirements. AI compares algorithm, parameters, and signal flow against the spec."
name: "Review Logic Consistency"
argument-hint: "<model.slx> <describe requirements or provide spec file>"
---

# Review Logic Consistency

Verify that the Simulink model's **functional behavior** matches the **software requirements**. The AI reads the requirements, explores the model using MCP tools (`model_overview`, `model_read`, `model_query_params`), and reports behavioral inconsistencies.

## Usage

Provide the requirements directly, or reference a requirements document:

```
/reviewLogic Model.slx A speed controller:
  - Input: target speed, actual speed
  - Output: throttle command 0-100
  - Logic: P gain 2.0, I gain 0.5, saturate output [0,100]
```

```
/reviewLogic Model.slx requirements.docx
  Compares each requirement against model implementation
```

## What It Checks

- ✅ **Algorithm correctness** — does the model compute what the requirement says?
- ✅ **Parameter values** — do gains, thresholds, limits match the spec?
- ✅ **Signal flow** — are signals routed correctly through the right blocks?
- ✅ **Edge cases** — are boundary conditions handled?
- ❌ **Missing functionality** — requirements with no implementation
- ⚠ **Extra functionality** — implemented behavior not in requirements

## Prerequisites

- MATLAB running with `satk_initialize` executed
- Simulink Agentic Toolkit configured (model_overview, model_read, model_query_params)

## Output

The AI presents a structured review per requirement:

```
## Review: [Requirement]

### Model Implementation
[What the model actually does, with block paths]

### Verdict
✅ Match / ⚠ Partial / ❌ Mismatch

### Details
- Parameter X: Req=15, Model=15 → OK
- Signal flow: OK
- Issues found: ...

### Suggestion
[How to align implementation with requirements]
```
