---
description: "Build System Composer architecture models (F/L/P layers) from natural language decomposition. Creates components, ports, interfaces, and allocation sets."
name: "Build Architecture"
argument-hint: "<describe your architecture>"
---

# Build Architecture Model

从自然语言架构描述，自动生成 System Composer 多层架构模型。

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

## Prerequisites

- System Composer 许可证
- Simulink Agentic Toolkit（`satk_initialize`）
