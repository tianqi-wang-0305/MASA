---
description: "Scan Simulink calibration parameters and analyze output sensitivity by sweeping each parameter through a range"
name: "Analyze Sensitivity"
argument-hint: "<model.slx> <subsystem_path> [options]"
---

# Analyze Parameter Sensitivity

Identify all calibration parameters (Gain, Constant, Saturation, LookupTable) in a subsystem, sweep each by ±20%, and measure output sensitivity. High-sensitivity parameters are flagged for careful calibration.

## Usage

```
/analyzeSensitivity Model.slx Model/Subsystem
/analyzeSensitivity Model.slx Model/Subsystem Range=-50,50
```

## Steps

1. Run in MATLAB:

   ```matlab
   analyzeSensitivity('Model.slx', 'Model/Subsystem');
   analyzeSensitivity('Model.slx', 'Model/Subsystem', 'Range', [-50, 50]);
   ```

2. Open the HTML sensitivity report
3. High-sensitivity parameters (>50% output change) should be calibrated carefully
