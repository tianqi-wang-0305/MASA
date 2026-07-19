---
agent: agent
description: "Auto-layout a Simulink model: hierarchically arrange subsystems, align ports left/right, and optimize signal line routing"
name: "auto-layout-model"
argument-hint: "<model.slx> [options]"
---

# Auto Layout Model

Recursively layout a Simulink model for clean presentation. Aligns Inport blocks to the left, Outport blocks to the right, arranges subsystems in the middle, and runs Simulink's built-in auto-arrange.

When a subsystem has many inputs or outputs, expand the subsystem vertically instead of squeezing ports together. Keep the root interface blocks and the wrapper subsystem port rows aligned, and let the subsystem height adapt to the number of interface signals so lines remain readable.

## 布局对齐标准 (必须遵守)

布局完成后，必须验证以下对齐条件：

```
✅ Inport 左对齐：所有 Inport 块的 Position(1) 必须相等
✅ Outport 右对齐：所有 Outport 块的 Position(3) 必须相等
✅ 端口间距均匀：相邻端口间距 = total_gap / (N+1)
✅ 信号流左→右：Inport(左) → 子系统(中) → Outport(右)
✅ 同层子系统等高：同层级子系统的 Position(4)-Position(2) 一致
✅ 同层子系统等宽：同层级子系统的 Position(3)-Position(1) 一致
```

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
