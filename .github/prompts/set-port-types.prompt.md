---
description: "Auto-set Inport/Outport data types from signal name prefixes. E.g. s16VehicleSpeed → int16, u8DoorStatus → uint8."
name: "Set Port Data Types"
argument-hint: "<model.slx> [options]"
---

# Set Port Data Types from Signal Names

Scan all Inport/Outport blocks (recursively) and auto-set their data type based on signal name prefix convention.

## Naming Convention

### 信号命名: `{type}{Description}`

| Prefix | Data Type | Example |
|--------|-----------|---------|
| `s8` | int8 | `s8Temperature` |
| `s16` | int16 | `s16VehicleSpeed` |
| `s32` | int32 | `s32Position` |
| `u8` | uint8 | `u8DoorStatus` |
| `u16` | uint16 | `u16Counter` |
| `u32` | uint32 | `u32TimeStamp` |
| `f32` | single | `f32Current` |
| `f64` | double | `f64Voltage` |
| `b` / `bool` | boolean | `bLockRequest` |

### 标定命名: `cal_{type}{Description}`

| Prefix | Data Type | Example |
|--------|-----------|---------|
| `cal_u8` | uint8 | `cal_u8Threshold` |
| `cal_s16` | int16 | `cal_s16SpeedLimit` |
| `cal_u16` | uint16 | `cal_u16Timeout` |
| `cal_f32` | single | `cal_f32GainValue` |
| `cal_b` | boolean | `cal_bEnableFlag` |

## Usage

```
/setPortTypes Model.slx
/setPortTypes Model.slx --dry-run        (preview only)
/setPortTypes Model.slx scope=Model/SWC
```

## Steps

1. Run in MATLAB:

   ```matlab
   % Preview changes first
   result = autoSetPortDataTypes('Model.slx', 'DryRun', true);

   % Apply to whole model
   result = autoSetPortDataTypes('Model.slx');

   % Apply to specific subsystem only
   result = autoSetPortDataTypes('Model.slx', 'Scope', 'Model/SWC_Name');
   ```

2. Review the output:
   - Changed ports listed with ✅
   - Skipped ports (no prefix / already correct) with ⏭
   - Errors with ⚠

3. Use a custom mapping file for different conventions:

   ```matlab
   result = autoSetPortDataTypes('Model.slx', 'MappingFile', 'my_mapping.json');
   ```
