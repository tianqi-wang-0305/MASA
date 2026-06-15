---
description: "Generate AI-enhanced ASPICE-compliant Detailed Design Document (SDD) PDF for a Simulink model"
name: "Generate AI SDD"
argument-hint: "<model.slx> <excel.xlsx> [options]"
---

# Generate AI SDD

Generate an ASPICE-compliant Detailed Design Document (SDD) PDF for a Simulink model. Uses AI-enhanced deep model analysis for rich subsystem descriptions.

## Usage

```
/generateAISDD Model.slx workbook.xlsx
/generateAISDD Model.slx workbook.xlsx ForceAnalyze=true
```

## Process

```
model_overview + model_read + model_query_params + model_resolve_params
        ↓
   analyzeModelDeepForSDD.m → _model_knowledge.json (deep analysis)
        ↓
   DdGeneration_AI.m → _DetailDesign_AI.pdf (AI-enhanced report)
```

## Steps

1. **Locate scripts**: `work/scripts/ai_sdd/src/`
   - `analyzeModelDeepForSDD.m` — deep analysis
   - `DdGeneration_AI.m` — enhanced report generation
2. **Build the MATLAB command**:

   ```matlab
   % One-step (auto-analyze + generate)
   DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx');

   % Force re-analysis
   DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx', ...
       'ForceAnalyze', true);

   % Two-step (reuse knowledge base)
   analyzeModelDeepForSDD('path/to/Model.slx', 'path/to/workbook.xlsx');
   DdGeneration_AI('path/to/Model.slx', 'path/to/workbook.xlsx');
   ```

3. **Output**: `_DetailDesign_AI.pdf` with:
   - AI-generated subsystem descriptions (signal flow, algorithm, parameters)
   - Interface and calibration tables from Excel
   - Subsystem screenshots with hyperlink navigation
   - ASPICE SWE.3 compliant structure

## Prerequisites

- Simulink Report Generator
- Simulink Agentic Toolkit initialized (`satk_initialize`)
