---
name: review-with-fix-suggestions
description: "Run comprehensive model review and get specific fix suggestions for each issue found, with prioritized action plan. Use when you want not just problems but also exactly what to change."
license: MIT
metadata:
  author: autoModeling
  version: "1.0"
---

# Review with Fix Suggestions

Use this skill when you want to review a Simulink model AND get actionable fix recommendations for every issue found.

## When to Use

- You ran `/reviewModel` and want to know exactly what to change
- You're preparing a model for code generation and need a fix checklist
- You want a prioritized action plan (critical → major → minor)
- You need concrete rename suggestions for naming violations

## How It Works

The skill combines two tools:

```
reviewModel('Model.slx')
        │
        ▼
  Identifies all issues (naming, connections, hierarchy, types, Model Advisor)
        │
        ▼
  generateFixSuggestions(result)
        │
        ▼
  For each issue → specific fix suggestion + example + command
        │
        ▼
  Prioritized action plan
```

## Fix Suggestion Examples

### 命名规范违规
```
问题: 端口 "VehicleSpeed" 缺少数据类型前缀
建议: 重命名为 u16VehicleSpeed（根据实际类型选择 u8/s16/f32/b）
工具: /setPortTypes 可自动批量设置
```

### 连线完整性
```
问题: 输入端口 "SensorA" 未连接
建议: 从信号源拖线到 SensorA，或添加 Ground 占位模块
```

### 标定命名
```
问题: 标定参数 "Threshold" 缺少 cal_ 前缀
建议: 重命名为 cal_u16Threshold
```

### 层级问题
```
问题: 子系统嵌套深度 7 层 > 5 层限制
建议: 使用 Model Reference 替代深层嵌套
```

## Output

- HTML report with all issues + fix suggestions + examples + commands
- Prioritized action plan (🔴 critical → 🟠 major → 🟡 minor)
- Quick-fix tool shortcuts (/setPortTypes, /autoLayout, /checkModel)

## Usage

In MATLAB:
```matlab
result = reviewModel('Model.slx');
% Fix suggestions are automatically included in result.fixSuggestions
% and displayed in the HTML report
```

In VS Code:
```
/reviewModel Model.slx
# Fix suggestions appear in the HTML report automatically
```
