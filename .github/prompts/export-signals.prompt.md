---
description: "Export top-level I/O signals from Simulink model to Excel workbook with naming convention check"
name: "Export Signals"
argument-hint: "<model.slx> [options]"
---

# Export Signals to Excel

Export all Inport/Outport blocks with signal names, data types, dimensions, descriptions, value semantics, min/max, units, and naming convention compliance info.

## Usage

```
/exportSignals Model.slx
/exportSignals Model.slx IncludeNested=true
/exportSignals Model.slx OutputFile=mySignals.xlsx
```

## Steps

Run in MATLAB:

```matlab
% Export top-level ports only
result = exportSignalsToExcel('Model.slx');

% Include nested subsystem ports
result = exportSignalsToExcel('Model.slx', 'IncludeNested', true);
```

## Output

- Excel file with `Signals` sheet
- Columns: PortName, Direction, DataType, Dimensions, Description, ValueMeaning, Min, Max, Unit
- File: `<Model>_signals.xlsx`

If the model port description is multiline, preserve it in a readable form in Excel instead of truncating it.
