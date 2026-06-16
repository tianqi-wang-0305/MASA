---
description: "Generate Requirement Traceability Matrix: trace Excel signals and calibrations to Simulink model blocks with coverage metrics"
name: "Generate Trace Matrix"
argument-hint: "<model.slx> <workbook.xlsx>"
---

# Generate Traceability Matrix

Trace Excel interface and calibration definitions to Simulink model blocks. Produces an HTML traceability matrix showing requirement coverage, traced blocks, and orphan requirements.

## Usage

```
/generateTraceMatrix Model.slx workbook.xlsx
```

## Steps

1. Run in MATLAB:

   ```matlab
   result = generateTraceMatrix('Model.slx', 'workbook.xlsx');
   ```

2. Open the HTML traceability matrix report
3. Check orphan requirements (defined in Excel but not traced to model)
4. Coverage > 80% is recommended for ASPICE compliance

## Output

- HTML traceability matrix
- Per-subsystem trace count
- Untraced requirement list
