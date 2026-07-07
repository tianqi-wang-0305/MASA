# Simulink Test Generation Launcher

Use [run_generateModelTests.m](run_generateModelTests.m) as the reusable entry point for Simulink Test generation.

## Quick Start

```matlab
run_generateModelTests
```

This opens a file picker, then initializes the Simulink Agentic Toolkit and runs automatic test generation for the selected `.slx` or `.mdl` file.

If an `InitVar.m` exists near the model, it is executed first so the model can load its own enums, constants, and setup files.

## Direct Use

```matlab
run_generateModelTests('D:\path\to\MyModel.slx')
run_generateModelTests('D:\path\to\MyModel.slx', 'Strategy', 'boundary')
run_generateModelTests('D:\path\to\MyModel.slx', 'Component', 'MyModel/Subsystem')
run_generateModelTests('D:\path\to\MyModel.slx', 'Strategy', 'comprehensive')
```

## Output

Generated feature files and the HTML report are written to the model folder's `_tests` directory.
By default, the generator now produces a broader set of scenarios, including MCDC-oriented input toggles.

## Signal Builder Harness

If you want a file you can run as a Signal Builder-based executable model, use:

```matlab
run_generateSignalBuilderHarness('D:\path\to\MyModel.slx', 'Strategy', 'comprehensive')
```

This creates a harness model under the model's `_tests` folder with one Signal Builder group per generated scenario.

## Simulink Test Harness

If you want a proper Simulink Test harness file, use:

```matlab
run_generateTestHarness('D:\path\to\MyModel.slx')
```

This creates an external harness SLX under the model's `_tests` folder.

## Coverage-Oriented Generation

The unified executable-artifact generator also creates:

- Multiple Signal Editor input datasets, one per generated scenario
- A Test Sequence harness with explicit scenarios and steps
- A Test Manager file populated with one test case per scenario
- MCDC-oriented toggle scenarios in comprehensive mode

## Report Contents

The HTML report includes:

- Overall run summary
- Input interface table
- Output interface table
- Per-feature-file status
- Scenario count for each feature file