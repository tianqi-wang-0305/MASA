---
description: "Build System Composer architecture models (F/L/P layers) from natural language decomposition. Creates components, ports, interfaces, and allocation sets."
name: "Build Architecture"
argument-hint: "<describe your architecture>"
---

# Build Architecture Model

从自然语言架构描述，自动生成 System Composer 多层架构模型。

如果架构中的输入或输出接口数量很多，优先采用更高的组件/端口布局：拉长组件窗口的纵向空间，保持端口垂直间距一致，并让左右接口在视觉上与组件端口行对齐，避免端口堆叠。

## Usage

```
/buildArchitecture 一个BCM的F/L架构：
功能层：
  DetectLockRequest  ← u16VehicleSpeed, bLockRequest
  ArbitrateLockCmd    → bLockCmd
  GenerateFlash       → bFlashCmd
逻辑层：
  DoorLogic_Unit     ← DoorStatus, VehicleSpeed
  Light_Unit         ← FlashRequest
接口字典: BCM_IF.sldd
```

## What It Does

1. 解析架构描述（层次、组件、端口、接口）
2. 按 F/L/P 最佳实践创建 System Composer 模型
3. 创建并关联接口字典
4. 设置端口接口类型
5. 创建分配集（多层时）
6. `model_check` 验证

## Layout Guidance

- 当接口数量密集时，不要压缩端口到同一高度，优先增加组件纵向高度。
- 保持端口行间距统一，减少连线交叉和视觉拥挤。
- 对多层架构，先按接口数量估算窗口尺寸，再执行自动布局。

## Prerequisites

- System Composer 许可证
- Simulink Agentic Toolkit（`satk_initialize`）
