# --- front-matter:toml ---
model = "Foc_2024b"
component = "Foc_2024b"

[inputs]
u16VehicleSpeed = "'u16VehicleSpeed'"
bLockRequest = "'bLockRequest'"
eStMotor = "'eStMotor'"
f32Temperature = "'f32Temperature'"
CrashSignal = "'CrashSignal'"

[outputs]
LockCmd = "'LockCmd'"
UnlockCmd = "'UnlockCmd'"
FlashCmd = "'FlashCmd'"
# --- end front-matter ---

Feature: Foc_2024b Nominal Operation Tests
  Basic functional verification of component behavior under normal operating conditions.

Scenario: 正常工况_常值输入
  Description: Verify component operates correctly with constant nominal inputs.

  Given inputs
    * u16VehicleSpeed = const(50)
    * bLockRequest = const(1)
    * eStMotor = const(RUN)
    * f32Temperature = const(25.5)
    * CrashSignal = const(0)
  When simulate for 10s in Normal mode
  Then baseline "Foc_2024b_baseline.mat" with tolerances: absTol=0.01, relTol=0.01, timeTol=50ms
  Then outputs
    * LockCmdInRange: LockCmd == [0 .. 1]
    * UnlockCmdFinite: UnlockCmd == [-inf .. inf]

Scenario: 正常工况_阶跃响应
  Description: Verify component responds correctly to step changes in inputs.

  Given inputs
    * u16VehicleSpeed = step(0 -> 60 @ 2s)
    * bLockRequest = step(0 -> 1 @ 1s)
    * eStMotor = const(RUN)
    * f32Temperature = const(25.5)
    * CrashSignal = const(0)
  When simulate for 10s in Normal mode
  Then baseline "Foc_2024b_baseline.mat" with tolerances: absTol=0.01, relTol=0.01, timeTol=50ms
  Then outputs
    * LockCmdInRange: LockCmd == [0 .. 1]
    * UnlockCmdFinite: UnlockCmd == [-inf .. inf]

Scenario: 正常工况_斜坡输入
  Description: Verify component tracks linear ramp inputs.

  Given inputs
    * u16VehicleSpeed = ramp(0 -> 120 over 8s)
    * bLockRequest = const(1)
    * eStMotor = const(RUN)
    * f32Temperature = const(25.5)
    * CrashSignal = const(0)
  When simulate for 10s in Normal mode
  Then outputs
    * NoSpuriousOutput: UnlockCmd == 0
