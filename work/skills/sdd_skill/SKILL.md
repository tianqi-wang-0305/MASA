---
name: sdd-detail-design-generation
description: "Generates detailed design documents for Simulink models from an Excel interface/calibration workbook and model hierarchy analysis. Use when producing a PDF detailed design report with subsystem screenshots, hyperlink navigation, IO tables, calibration tables, and clear subsystem functional descriptions derived from signal flow."
license: MathWorks BSD-3-Clause
metadata:
  author: Copilot
  version: "1.0"
---

# SDD Detailed Design Generation

Use this skill to generate a new detailed design document for a Simulink model without modifying the existing MATLAB generator script `DdGeneration.m`.
The preferred executable entry point is `DdGeneration_ASPICE.m`, which keeps the legacy script intact and generates the hierarchy-aware report.

## When to Use

- The user wants a detailed design PDF for a Simulink model and an Excel workbook that contains interface and calibration data.
- The document must include input and output interface identification, calibration parameters, one section per subsystem, a screenshot for each subsystem, and hyperlink navigation.
- The model needs to be read with Simulink Agentic tools so the subsystem descriptions are derived from actual signal flow and internal structure.

## When NOT to Use

- The user wants to change the model structure itself -> use `building-simulink-models`.
- The user only wants a simulation result or a test artifact -> use the relevant simulation or testing skill.
- The user wants you to rewrite or replace `DdGeneration.m` -> do not change it; keep the existing script intact.

## Core Objective

Produce a detailed design report that:

- Reads the Excel workbook to identify input interfaces, output interfaces, and calibration items.
- Reads every subsystem in the Simulink model hierarchy.
- Explains each subsystem chapter clearly based on the subsystem's inputs, outputs, signal flow, blocks, parameters, and control logic.
- Inserts a screenshot or diagram for each subsystem.
- Provides hyperlink navigation from the top-level navigation page into each subsystem chapter.
- Preserves the existing PDF output style and file naming behavior used by `DdGeneration.m`.

## Workflow

1. **Identify the source artifacts.** Confirm the model file and the Excel workbook used for interfaces and calibration.
2. **Understand the model hierarchy.** Use `model_overview` on the root model, then use `model_read` on the root and on each subsystem that will have its own chapter.
3. **Resolve values.** Use `model_query_params` for block and signal parameters, then use `model_resolve_params` when a parameter is a workspace variable.
4. **Extract interface and calibration content.** Treat the Excel workbook as the source of truth for I/O and calibration rows, and keep the grouping aligned with the existing script behavior.
5. **Describe each subsystem.** For every subsystem, write a chapter that covers:
   - purpose and role in the model
   - Based on the signal flow direction of this subsystem, generate module function descriptions that meet ASPICE SDD requirements. Automated document compliance
   - signal flow through the subsystem
   - key decision logic, math, lookups, filters, or enable conditions
   - any special notes such as references, wrappers, or conditional behavior
6. **Assemble the report.** Keep the same high-level report structure as the existing PDF flow: cover page, table of contents, interface sections, calibration section, navigation section, model overview, then one section per subsystem.
7. **Validate the result.** Confirm that every subsystem has a chapter, every chapter has a screenshot and a link target, and the text is specific enough that a reviewer can understand the function without opening the model.

## Document Structure

Use this order for the generated document:

1. Title page
2. Table of contents
3. Input interface section
4. Output interface section
5. Calibration section
6. Subsystem navigation index with hyperlinks
7. Model overview chapter
8. One chapter per subsystem

Each subsystem chapter should include:

- a clear chapter title
- a short purpose statement
- a screenshot or diagram of the subsystem
- a functional description written from the signal flow, not just from the block names

## Writing Rules for Subsystem Descriptions

- Explain what the subsystem does, not only what blocks it contains.
- If a subsystem is a reference, wrapper, or nonfunctional container, state that explicitly.
- Do not invent behavior that is not visible in the model or workbook.
- Prefer concrete verbs such as filter, clamp, scale, select, compare, route, enable, or aggregate.

## Output Conventions

- Default output is a PDF detailed design document.
- Use stable naming consistent with `DdGeneration.m`: `<ModelName>_DetailDesign.pdf`.
- If the target PDF already exists, keep the existing fallback behavior with a timestamp suffix.

## Guardrails

- Do not modify `DdGeneration.m`.
- Do not alter the model or workbook unless the user explicitly asks for a separate change.
- Do not skip subsystem-level analysis just because the top-level model is already understood.
- Do not produce generic text that does not reflect actual signal flow.
- Do not omit hyperlinks or chapter targets.

## Tooling Expectations

Use the following Simulink Agentic tools when available:

- `model_overview`
- `model_read`
- `model_query_params`
- `model_resolve_params`
- `model_check`

## Review Checklist

- [ ] Every input interface from Excel is represented
- [ ] Every output interface from Excel is represented
- [ ] Every calibration row from Excel is represented
- [ ] Every subsystem in the model has a chapter
- [ ] Every subsystem chapter has a screenshot and a hyperlink target
- [ ] Subsystem descriptions are derived from actual signal flow and block behavior
- [ ] The existing MATLAB script remains unchanged
