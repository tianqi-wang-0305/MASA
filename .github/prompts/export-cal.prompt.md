---
description: "Export calibration parameters (cal_ prefix) from Simulink model to Excel workbook"
name: "Export Calibration"
argument-hint: "<model.slx> [options]"
---

# Export Calibration to Excel

Scan the model for all calibration blocks matching the `cal_{type}{Name}` naming convention and export them to Excel.

For each calibration, keep the full semantic context: Description, value meaning or usage notes, Min/Max, Unit, and any documented constraints should be exported alongside the numeric value and data type.

## Naming Convention

Only blocks named `cal_{type}{Name}` are exported, e.g.:
- `cal_u16Threshold` → uint16 calibration
- `cal_f32GainValue` → single calibration
- `cal_s16SpeedLimit` → int16 calibration

## Usage

```
/exportCal Model.slx
/exportCal Model.slx OutputFile=myCals.xlsx
```

## Steps

Run in MATLAB:

```matlab
% Export all calibration parameters
result = exportCalToExcel('Model.slx');

% Custom output path
result = exportCalToExcel('Model.slx', 'OutputFile', 'myCals.xlsx');
```

## Output

- Excel file with `Calibration` sheet
- Columns: Name, BlockType, DataType, Value, Min, Max, Unit, Description
- File: `<Model>_calibration.xlsx`

If the calibration text includes state/value semantics, preserve those semantics in the Description column or an additional note field so downstream review tools can validate them.
