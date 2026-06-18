---
description: "Export both signals and calibration parameters to a single Excel workbook with separate sheets"
name: "Export All"
argument-hint: "<model.slx> [options]"
---

# Export Signals + Calibration to Excel

Export both I/O signals and calibration parameters to one combined Excel workbook.

## Usage

```
/exportAll Model.slx
/exportAll Model.slx OutputFile=full_export.xlsx
```

## Steps

Run in MATLAB:

```matlab
% Export signals + calibration to one file
result = exportAllToExcel('Model.slx');
```

## Output

- Single Excel file with 2 sheets:

  **Sheet 1: Signals**
  - PortName, Direction, DataType, Dimensions, SampleTime, ConnectedSignal, NamingStatus

  **Sheet 2: Calibration** (only blocks with `cal_` prefix)
  - Name, BlockType, DataType, Value, Min, Max, Unit

- File: `<Model>_signals_cal.xlsx`
