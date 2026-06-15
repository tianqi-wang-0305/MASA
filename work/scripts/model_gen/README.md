# Simulink 模型自动搭建

根据自然语言软件需求，AI Agent 自动搭建 Simulink 基础模型框架，然后由人工优化。

## 使用方法

在 VS Code 聊天中输入 `/buildModel` 并描述你的需求：

```
/buildModel A PID speed controller with:
  - Input: target speed, actual speed
  - Output: throttle command (0-100)
  - Logic: P=2.0, I=0.5, D=0.1, output saturation [0, 100]
```

或直接对 AI 说：

> "帮我搭建一个信号处理模型：输入原始传感器信号，经过低通滤波、增益缩放、限幅后输出"

## 工作流程

```
你的需求（自然语言）
        │
        ▼
  AI Agent 解析需求
  ├── 识别输入/输出/逻辑/参数
        │
        ▼
  设计架构
  ├── 功能分解为子系统
  ├── 选择模块类型
  └── 定义数据流
        │
        ▼
  model_edit 搭建模型
  ├── 添加 Inport/Outport
  ├── 创建子系统
  ├── 添加内部逻辑模块
  └── 连线
        │
        ▼
  model_read + model_check 验证
        │
        ▼
  呈现结果 + 人工优化建议
```

## 技能文件

通用模型搭建技能位于：

```
work/scripts/model_gen/.github/skills/build-simulink-from-requirements/SKILL.md
```

这个 skill 包含了：
- 需求解析规则（输入/输出/逻辑模式识别）
- 架构设计模式（前馈链、反馈控制、决策路由、状态机）
- 模块类型参考（40+ 常用模块）
- model_edit 调用序列最佳实践
- 验证和呈现模板

## BCM 门锁控制器示例（参考）

`createBCMLockController.m` 是一个完整的参考示例，展示了如何用脚本方式构建一个实际模型：

| 功能 | 描述 |
|------|------|
| **输入** | 4×车门状态、车速、遥控锁/解锁请求、碰撞信号 |
| **输出** | 锁门指令、解锁指令、转向灯闪烁指令 |
| **自动落锁** | 车速>15km/h且车门全关→自动落锁 |
| **碰撞解锁** | 碰撞信号→自动解锁（5s脉冲保持）|
| **遥控仲裁** | 锁优先级>解锁；车速>5km/h抑制解锁 |

```matlab
% 运行 BCM 示例
createBCMLockController();
```

## 人工优化建议

搭建完成后，建议人工优化：

1. **布局调整** - 移动模块使信号流向更清晰
2. **参数提取** - 替换硬编码值为工作区变量
3. **Stateflow 替换** - 复杂状态机用 Chart 替代逻辑门
4. **信号属性** - 设置数据类型、SampleTime、StorageClass
5. **AUTOSAR 适配** - 配置 SWC 接口和 Runable
