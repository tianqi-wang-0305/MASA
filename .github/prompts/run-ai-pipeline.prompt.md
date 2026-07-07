---
description: "Run the full AI-powered automation pipeline: SDD document generation + Simulink Test generation for a given model"
name: "Run AI Pipeline"
argument-hint: "<model.slx> [excel.xlsx] [options]"
---

# Run AI Pipeline

Execute the complete AI-powered Simulink automation pipeline for the specified model.

If the target model has many input or output interfaces, keep the generated wrapper/model layout tall enough to preserve readable port spacing. The pipeline should favor vertically expanded subsystem windows over compressed interface rows.

## Usage

```
/runAIPipeline Model.slx workbook.xlsx
/runAIPipeline Model.slx workbook.xlsx SkipTests=true
/runAIPipeline Model.slx workbook.xlsx TestStrategy=comprehensive
/runAIPipeline Model.slx workbook.xlsx TestComponent=Model/Subsystem
```

## Steps

1. **Locate the scripts**: The pipeline entry point is at `work/scripts/runAIPipeline.m`
2. **Verify prerequisites**:
   - MATLAB R2023a+ with Simulink, Simulink Test, Simulink Report Generator
   - Simulink Agentic Toolkit initialized (`satk_initialize`)
   - The model file (.slx) and Excel workbook exist
3. **Build the MATLAB command** based on user parameters:

   ```matlab
   % Basic (SDD + basic tests)
   runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx');

   % SDD only
   runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx', 'SkipTests', true);

   % With comprehensive tests
   runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx', ...
       'TestStrategy', 'comprehensive');

   % Test specific subsystem
   runAIPipeline('path/to/Model.slx', 'path/to/workbook.xlsx', ...
       'TestComponent', 'Model/Subsystem');
   ```

4. **Execute**: Run the MATLAB command in the terminal:

   ```bash
   /Applications/MATLAB_R2025a.app/bin/matlab -batch "..."
   ```

   Or guide the user to paste the command into MATLAB Command Window.

5. **Post-layout rule**: If the model is interface-dense, run the layout step in a mode that preserves vertical spacing and aligns the wrapper port rows with the root interface blocks.
