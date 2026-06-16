---
name: sdd-detail-design-generation
description: "生成 Simulink 模型的 ASPICE SWE.3 详细设计文档。现在已被 /generateAISDD slash command 集成。"
license: MathWorks BSD-3-Clause
metadata:
  author: autoModeling
  version: "2.0"
---

# SDD 详细设计生成

> ⚠ **此 SKILL 的功能已被 `/generateAISDD` 集成，推荐直接使用 slash command。**

## 使用方式

在 VS Code 聊天中直接使用：

```
/generateAISDD Model.slx workbook.xlsx
```

这会自动执行：
1. `model_overview` + `model_read` 深度分析每个子系统
2. 基于信号流生成高质量子系统描述
3. 生成 ASPICE 合规的 PDF 详细设计文档

## 底层脚本位置

| 脚本 | 新位置 |
|------|--------|
| `DdGeneration_ASPICE.m` | `work/scripts/ai_sdd/src/` |
| `DdGeneration.m` | `work/scripts/design_gen/src/` |
| `.headless/` | `work/scripts/ai_sdd/src/.headless/` |

## 参考文件

- `prompts/aspice_swe3.json` — ASPICE 需求模板
- `templates/sdd_template.txt` — 文档结构模板
