---
description: "Compare software requirements (Excel) against Simulink model implementation. Detect missing signals, extra ports, data type mismatches, and calibration gaps."
name: "Review Requirements Consistency"
argument-hint: "<model.slx> <requirements.xlsx>"
---

# Requirements-Model Consistency Review

Compare Excel-defined software requirements against the actual Simulink model implementation.

## What It Checks

| Check | Severity | Description |
|-------|----------|-------------|
| Signal missing | ❌ Error | 需求中定义但模型中不存在的信号 |
| Data type mismatch | 🟠 Major | 信号数据类型在需求和模型中不一致 |
| Calibration missing | 🟠 Major | 需求中定义但模型中未使用的标定 |
| Signal extra | 🟡 Warning | 模型中存在但需求未定义的信号 |
| Calibration extra | 🟡 Warning | 模型中使用但需求未定义的标定 |

## Usage

```
/reviewConsistency Model.slx requirements.xlsx
```

## Steps

Run in MATLAB:

```matlab
result = reviewReqConsistency('Model.slx', 'requirements.xlsx');
```

## Output

- **Consistency score** (0-100)
- **Categorized findings** (error / major / warning)
- **HTML report** with detailed comparisons
