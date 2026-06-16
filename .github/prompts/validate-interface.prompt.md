---
description: "Validate consistency between Simulink model and Excel workbook. Detect missing, extra, or mismatched ports and calibrations."
name: "Validate Interface"
argument-hint: "<model.slx> <workbook.xlsx>"
---

# Validate Model-Excel Consistency

Compare Excel port/calibration definitions against the actual model, reporting missing, extra, or mismatched items. Prevents synchronization drift between specification and implementation.

## Usage

```
/validateInterface Model.slx workbook.xlsx
```

## Steps

1. Run in MATLAB:

   ```matlab
   result = validateModelExcel('Model.slx', 'workbook.xlsx');
   ```

2. Check the HTML report for issues:
   - **Port missing**: Excel says it exists, model doesn't have it
   - **Port extra**: Model has it, Excel doesn't define it
   - **Calibration missing**: Excel calibration not found in model
