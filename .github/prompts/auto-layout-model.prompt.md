---
description: "Auto-layout a Simulink model: hierarchically arrange subsystems, align ports left/right, and optimize signal line routing"
name: "Auto Layout Model"
argument-hint: "<model.slx> [options]"
---

# Auto Layout Model

Recursively layout a Simulink model for clean presentation. Aligns Inport blocks to the left, Outport blocks to the right, arranges subsystems in the middle, and runs Simulink's built-in auto-arrange.

When a subsystem has many inputs or outputs, expand the subsystem vertically instead of squeezing ports together. Keep the root interface blocks and the wrapper subsystem port rows aligned, and let the subsystem height adapt to the number of interface signals so lines remain readable.

## Usage

```
/autoLayout Model.slx
/autoLayout Model.slx Style=compact
/autoLayout Model.slx Scope=Model/Subsystem
```

## Steps

1. Locate the script: `work/scripts/layout_gen/src/autoLayoutModel.m`
2. Run in MATLAB:

   ```matlab
   % Full hierarchical layout
   autoLayoutModel('Model.slx');

   % Layout specific subsystem only
   autoLayoutModel('Model.slx', 'Scope', 'Model/Subsystem');

   % Compact layout (current scope only)
   autoLayoutModel('Model.slx', 'Style', 'compact');
   ```

3. For dense interfaces, increase the target subsystem height before arranging, then rerun auto-layout so the port rows remain evenly spaced.

4. Open the model to see the result
