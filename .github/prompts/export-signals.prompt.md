---
description: "Export top-level I/O signals from Simulink model to Excel workbook with naming convention check"
name: "Export Signals"
argument-hint: "<model.slx> [options]"
---

# Export Signals to Excel

Export all Inport/Outport blocks with signal names, data types, dimensions, and naming convention compliance info.

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
- Columns: PortName, Direction, DataType, Dimensions, SampleTime, ConnectedSignal, NamingStatus
- NamingStatus shows ✅ (valid prefix) or ⚠ (prefix/type mismatch) or 无前缀
- File: `<Model>_signals.xlsx`
