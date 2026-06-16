---
description: "Aggregate MIL/SIL coverage data, run all tests with decision coverage, and generate an HTML coverage dashboard per subsystem"
name: "Analyze Coverage"
argument-hint: "<model.slx> [options]"
---

# Analyze Coverage

Aggregate coverage data from model_test runs. Runs all existing .feature tests with `coverage='decision'`, aggregates results by subsystem, and generates an HTML coverage dashboard with pass/fail threshold.

## Usage

```
/analyzeCoverage Model.slx
/analyzeCoverage Model.slx Threshold=90
```

## Steps

1. **Prerequisites**: Run `/generateModelTests` first to create .feature files
2. Run in MATLAB:

   ```matlab
   analyzeModelCoverage('Model.slx');
   analyzeModelCoverage('Model.slx', 'Threshold', 90);
   ```

3. Open the generated HTML report
