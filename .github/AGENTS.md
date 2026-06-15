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

## Custom Skills

| Skill | Location | Use Case |
|-------|----------|----------|
| **build-simulink-from-requirements** | `work/scripts/model_gen/.github/skills/` | Guides the AI in transforming natural language requirements into Simulink models using model_edit |

## Project Structure

```
work/
├── simulink-agentic-toolkit/     ← MathWorks MCP-based Simulink toolkit
│   ├── tools/                    ← MCP tools (model_read, model_edit, etc.)
│   └── skills-catalog/           ← MBD skills for AI agents
│
├── scripts/
│   ├── runAIPipeline.m           ← Unified entry point
│   ├── ai_sdd/src/               ← AI-Enhanced SDD generation
│   │   ├── analyzeModelDeepForSDD.m
│   │   └── DdGeneration_AI.m
│   ├── test_gen/src/             ← Auto Test Generation
│   │   └── generateModelTests.m
│   └── model_gen/                ← Generic model building
│       ├── .github/skills/       ← build-simulink-from-requirements skill
│       └── src/                  ← Example model builders (BCM, etc.)
│
└── skills/
    ├── sdd_skill/                ← SDD detailed design generation skill
    └── static_skill/             ← Static model checking skill
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
