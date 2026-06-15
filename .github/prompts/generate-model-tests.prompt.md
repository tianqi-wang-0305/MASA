---
description: "Automatically generate and run Simulink Test cases (Gherkin .feature files) for a model or subsystem"
name: "Generate Model Tests"
argument-hint: "<model.slx> [options]"
---

# Generate Model Tests

Automatically generate Gherkin-format Simulink Test cases for a model or subsystem, and optionally execute them via `model_test`.

## Usage

```
/generateModelTests Model.slx
/generateModelTests Model.slx Component=Model/SubsystemName
/generateModelTests Model.slx Strategy=comprehensive
/generateModelTests Model.slx Strategy=boundary RunTests=false
```

## Steps

1. **Locate the script**: `work/scripts/test_gen/src/generateModelTests.m`
2. **Read the script** to understand available options
3. **Build the MATLAB command**:

   ```matlab
   % Basic nominal tests
   generateModelTests('path/to/Model.slx');

   % Boundary tests on specific subsystem
   generateModelTests('path/to/Model.slx', ...
       'Component', 'Model/SubsystemName', ...
       'Strategy', 'boundary');

   % Comprehensive (generate only, no execution)
   generateModelTests('path/to/Model.slx', ...
       'Strategy', 'comprehensive', ...
       'RunTests', false);
   ```

4. **Execute** in MATLAB terminal and show results

## Output

- `.feature` files in `<model_dir>/_tests/`
- HTML test report at `<model_dir>/_tests/test_report.html`
- Test harness created automatically by `model_test`

## Prerequisites

- Simulink Test installed
- `satk_initialize` run in MATLAB session
