---
description: "Run comprehensive Simulink model review: naming, connections, hierarchy, data types, Model Advisor, and AI-driven design analysis"
name: "Review Model"
argument-hint: "<model.slx> [options]"
---

# Review Simulink Model

Run all available checks and produce a unified review report with severity levels, AI commentary, and a review score (A-D).

## Checks Included

| # | Check | Source | Severity |
|---|-------|--------|----------|
| 1 | Model Advisor | 50+ built-in checks | critical |
| 2 | Naming Convention | Block/signal name patterns | minor |
| 3 | Connection Integrity | Dangling lines, unconnected ports | major |
| 4 | Hierarchy Integrity | Nesting depth, orphan blocks | major |
| 5 | Port Data Type | Explicit vs inherited types | major |
| 6 | model_check | MCP structural validation | critical |
| 7 | AI Design Review | Anti-pattern detection via model_read | varies |

## Usage

```
/reviewModel Model.slx
/reviewModel Model.slx Severity=major
/reviewModel Model.slx AIMode=false    (skip AI review)
```

## Steps

Run in MATLAB:

```matlab
% Full review (recommended)
result = reviewModel('Model.slx');

% Only fail on critical issues
result = reviewModel('Model.slx', 'Severity', 'critical');

% Skip AI-driven analysis (faster)
result = reviewModel('Model.slx', 'AIMode', false);
```

## Output

- **Review score** (0-100) with letter grade A-D
- **Categorized issues** (critical / major / minor)
- **AI design review** with anti-pattern detection
- **HTML report** in `_reviews/` directory
