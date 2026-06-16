---
name: simulink-static-audit
description: "对 Simulink 模型执行命名规范、连线完整性、层级统计和 Model Advisor 检查，并输出 HTML 审计结果。现在已被 /reviewModel slash command 集成。"
license: MathWorks BSD-3-Clause
metadata:
  author: autoModeling
  version: "2.0"
---

# Simulink 静态审计

> ⚠ **此 SKILL 的检查功能已被 `/reviewModel` 集成，推荐直接使用 slash command。**

## 使用方式

在 VS Code 聊天中直接使用：

```
/reviewModel Model.slx
```

这会自动运行以下 7 项检查并汇总评分（A-D）：

| # | 检查项 | 严重度 |
|---|--------|--------|
| 1 | Model Advisor（50+ 检查） | critical |
| 2 | 命名规范 | minor |
| 3 | 连线完整性 | major |
| 4 | 层级完整性 | major |
| 5 | 端口数据类型 | major |
| 6 | model_check（MCP） | critical |
| 7 | AI 设计审查 | varies |

## 底层脚本位置

这些检查的 MATLAB 脚本已移至：

| 脚本 | 新位置 |
|------|--------|
| `check_naming_convention.m` | `work/scripts/review_gen/src/` |
| `check_connection_rules.m` | `work/scripts/review_gen/src/` |
| `check_hierarchy_integrity.m` | `work/scripts/review_gen/src/` |
| `run_model_advisor.m` | `work/scripts/quality_gen/src/` |
| `naming_convention.md` | `work/scripts/review_gen/src/` |

## 参考文档

- `ref/connection_rules.md` — 连线规范
- `ref/hierarchy_rules.md` — 层级规范

## 输入模板
如果你希望把这个 skill 作为斜杠提示词使用，可以直接套用 `prompt_template.txt` 的格式，填入模型路径后执行。

## 输出字段
脚本会返回以下关键信息：
- `success`
- `model`
- `model_name`
- `issues_count`
- `naming_count`
- `connection_count`
- `hierarchy_count`
- `model_advisor_count`
- `hierarchy.maxDepth`
- `hierarchy.subsystemCount`
- `report_path`
- `summary`

## 扩展检查建议
如果后续要继续增强这个 skill，建议再补以下方向：
- 重复命名和同层同名冲突
- 模型接口端口命名一致性
- 信号跨层级传递是否清晰
- 未使用子系统和死逻辑识别
- 注释、文档块、需求追踪完整性

## 执行入口
优先执行：
```bash
matlab -batch "run('scripts/run_model_advisor.m', '<model_path>')"
```

如果你的工作流支持更强的模型语义分析，也可以先用 Simulink Agentic tools 做结构预读，再把结果和脚本报告一起看。