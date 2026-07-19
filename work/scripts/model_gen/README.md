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

当需要批量创建多个结构相同的模型时，用 `buildModel.m`：

```matlab
% 定义规格（struct 或 JSON 文件）
spec.modelName = 'MyController';
spec.inputs = struct('name', {'SensorA', 'SensorB'}, 'dataType', {'single','single'});
spec.outputs = struct('name', {'Actuator'}, 'dataType', {'single'});
spec.subsystems = struct('name', {'Logic'}, 'description', {'Core logic'});
spec.connections = {'SensorA -> Logic', 'Logic -> Actuator'};
buildModel(spec);

% 或从 JSON 文件加载
buildModel('specs/controller_A.json');
buildModel('specs/controller_B.json');
```

脚本内部调用 `model_edit`，与 AI 用的 MCP 工具是同一套基础设施。

## 技能文件

通用模型搭建指导：`work/scripts/model_gen/.github/skills/build-simulink-from-requirements/SKILL.md`

## 总结

| 场景 | 用哪个 |
|------|--------|
| 日常开发中从需求搭建模型 | `/buildModel` slash command |
| 批量生成 5 个同类控制器 | `buildModel(spec)` |
| 有特殊算法需要精确控制 | 直接写 MATLAB 脚本 + `add_block`/`add_line` |
