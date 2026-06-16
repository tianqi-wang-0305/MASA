# Simulink 模型搭建

两种方式，选适合场景的用：

## 方式一：AI 驱动（推荐，日常开发用）

在 VS Code 聊天中输入 `/buildModel` 并描述你的需求，AI 自动用 `model_edit` 动态搭建：

```
/buildModel A PID speed controller with:
  - Input: target speed, actual speed
  - Output: throttle command (0-100)
  - Logic: P=2.0, I=0.5, D=0.1
```

**无需任何 MATLAB 脚本**，AI 根据需求实时构建。

## 方式二：脚本批量生成（标准化场景用）

当需要批量创建多个结构相同的模型时，用 `buildModelFromSpec.m`：

```matlab
% 定义规格（struct 或 JSON 文件）
spec.modelName = 'MyController';
spec.inputs = struct('name', {'SensorA', 'SensorB'});
spec.outputs = struct('name', {'Actuator'});
spec.subsystems = struct('name', {'Logic', 'Output'});
spec.connections = {'SensorA -> Logic', 'Logic -> Actuator'};

buildModelFromSpec(spec);
```

支持的内置逻辑模板：
- `threshold` — 阈值比较器
- `pid` — PID 控制器
- `filter` — 离散滤波器

## 技能文件

通用模型搭建指导：`work/scripts/model_gen/.github/skills/build-simulink-from-requirements/SKILL.md`

## 总结

| 场景 | 用哪个 |
|------|--------|
| 日常开发中从需求搭建模型 | `/buildModel` slash command |
| 批量生成 5 个同类控制器 | `buildModelFromSpec(spec)` |
| 有特殊算法需要精确控制 | 直接写 MATLAB 脚本 + `add_block`/`add_line` |
