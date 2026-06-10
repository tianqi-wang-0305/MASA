---
name: simulink-static-audit
description: 对 Simulink 模型执行命名规范、连线完整性、层级统计和 Model Advisor 检查，并输出 HTML 与 JSON 审计结果。
license: MathWorks BSD-3-Clause
metadata:
  author: Copilot
  version: "1.1"
---

# Simulink 静态审计技能

## 适用场景
使用这个技能来快速判断一个 Simulink 模型是否满足团队静态建模规范，重点覆盖命名、连线、层级和 Model Advisor 检查。

## 核心能力
- 命名规范检查：块名、信号线名、子系统名、Stateflow 图名是否符合 `^[A-Za-z][A-Za-z0-9_]*$`
- 通用名称预警：识别 `Subsystem`、`Chart`、`Gain`、`Sum` 这类占位命名
- 连线完整性检查：识别悬空信号线、未连接输入端口、未连接输出端口
- 层级统计：统计子系统数量、顶层模块数量、最大层级深度、游离模块数量
- Model Advisor 检查：运行一组默认检查并写入报告
- 报告输出：生成 HTML 报告，同时打印 JSON 结果，便于外部脚本解析

## 推荐流程
1. 确认模型路径和依赖文件可访问。
2. 运行 `scripts/run_model_advisor.m`。
3. 阅读 JSON 摘要中的问题分类和层级统计。
4. 打开 `reports/` 下生成的 HTML 报告，查看逐条问题和 Model Advisor 输出。

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