---
description: "Run Model Advisor with pass/fail threshold. Block commits/CI if errors exceed limit. Ideal for pre-merge validation."
name: "Check Model Threshold"
argument-hint: "<model.slx> [options]"
---

# Check Model with Threshold

Run Model Advisor checks with configurable error/warning thresholds. Designed for CI/CD and pre-commit hooks — fails if errors exceed limit.

## Usage

```
/checkModel Model.slx
/checkModel Model.slx ErrorThreshold=5
/checkModel Model.slx ErrorThreshold=0 WarningThreshold=10
```

## Steps

1. Locate the script: `work/scripts/quality_gen/src/checkModelWithThreshold.m`
2. Run in MATLAB:

   ```matlab
   % Zero-tolerance (fail on any error)
   result = checkModelWithThreshold('Model.slx');

   % Allow up to 5 errors
   result = checkModelWithThreshold('Model.slx', 'ErrorThreshold', 5);

   % Custom thresholds
   result = checkModelWithThreshold('Model.slx', ...
       'ErrorThreshold', 0, 'WarningThreshold', 10);
   ```

3. Check `result.passed` and the HTML report
