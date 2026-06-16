# autoModeling — AI-Powered Simulink Automation

This project provides a comprehensive AI-powered automation framework for Simulink-based application layer software development.

## Available Slash Commands

Type `/` in chat to see these commands:

| Command | Description |
|---------|-------------|
| `/runAIPipeline` | Run full pipeline: SDD + Tests for a model |
| `/generateAISDD` | Generate AI-enhanced ASPICE SDD PDF |
| `/generateModelTests` | Auto-generate Simulink Test .feature files |
| `/buildModel` | Build any Simulink model from natural language requirements |
| `/autoLayout` | Auto-layout model: align ports, arrange subsystems |
| `/checkModel` | Run Model Advisor with pass/fail threshold |
| `/analyzeCoverage` | Aggregate MIL/SIL coverage dashboard |
| `/analyzeSensitivity` | Scan calibration params for output sensitivity |
| `/validateInterface` | Check Excel-model consistency |
| `/generateTraceMatrix` | Generate Requirement Traceability Matrix |
| `/setPortTypes` | Auto-set port data types from signal name prefixes |
| `/reviewModel` | Comprehensive model review (7 checks, AI-driven) |

## Custom Skills

| Skill | Location | Use Case |
|-------|----------|----------|
| **build-simulink-from-requirements** | `work/scripts/model_gen/.github/skills/` | Guides the AI in transforming natural language requirements into Simulink models using model_edit |
| **sdd-detail-design-generation** | `.github/skills/sdd_skill/` | SDD detailed design doc generation (legacy, use `/generateAISDD`) |
| **simulink-static-audit** | `.github/skills/static_skill/` | Model static audit checks (legacy, use `/reviewModel`) |

All 3 skills are symlinked to `.github/skills/` and discoverable by the AI agent via `/`.

## Project Structure

```
work/
├── simulink-agentic-toolkit/     ← MathWorks MCP-based Simulink toolkit
├── matlab-mcp-core-server/       ← MATLAB MCP Core Server
│
├── scripts/
│   ├── runAIPipeline.m           ← Unified entry point
│   ├── ai_sdd/src/               ← AI-Enhanced SDD generation
│   │   ├── DdGeneration_AI.m
│   │   ├── DdGeneration_ASPICE.m
│   │   ├── analyzeModelDeepForSDD.m
│   │   └── .headless/
│   ├── review_gen/src/           ← Model review + naming/connection checks
│   │   ├── reviewModel.m
│   │   ├── check_naming_convention.m
│   │   ├── check_connection_rules.m
│   │   ├── check_hierarchy_integrity.m
│   │   └── report_utils.m
│   ├── test_gen/src/             ← Auto Test Generation
│   ├── quality_gen/src/          ← Model Advisor threshold
│   ├── model_gen/                ← Generic model building + skill
│   ├── ...
```

## Key MCP Tools

The Simulink Agentic Toolkit provides 7 MCP tools:

| Tool | Purpose |
|------|---------|
| `model_overview` | Hierarchy and interfaces |
| `model_read` | Block topology and algorithm |
| `model_edit` | Structural changes (add/connect/configure/delete) |
| `model_check` | Structural validation |
| `model_query_params` | Parameter access |
| `model_resolve_params` | Workspace variable resolution |
| `model_test` | Gherkin-based behavioral testing |

## Prerequisites

- MATLAB R2023a+ with Simulink
- Simulink Test (for model_test)
- Simulink Report Generator (for SDD PDF)
- MATLAB MCP Core Server (`satk_initialize` to start)
