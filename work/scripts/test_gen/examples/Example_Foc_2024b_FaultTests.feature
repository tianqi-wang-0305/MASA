# --- front-matter:toml ---
model = "Foc_2024b"
component = "Foc_2024b"

[inputs]
u16VehicleSpeed = "'u16VehicleSpeed'"
bLockRequest = "'bLockRequest'"
CrashSignal = "'CrashSignal'"
eStMotor = "'eStMotor'"

[outputs]
LockCmd = "'LockCmd'"
UnlockCmd = "'UnlockCmd'"
FlashCmd = "'FlashCmd'"
# --- end front-matter ---

Feature: Foc_2024b Fault & Abnormal Condition Tests
  Verification of component behavior under fault and abnormal operating conditions.

Scenario: 异常工况_碰撞信号触发
  Description: Verify crash signal triggers unlock and flash output.

  Given inputs
    * u16VehicleSpeed = const(60)
    * bLockRequest = const(1)
    * CrashSignal = pulse(width=1s, period=0s, delay=2s)
    * eStMotor = const(RUN)
  When simulate for 10s in Normal mode
  Then outputs
    * CrashUnlock: UnlockCmd == 1 when t > CrashSignal
    * FlashActive: FlashCmd == 1 when t > CrashSignal

Scenario: 异常工况_碰撞后恢复
  Description: Verify system returns to normal after crash signal ends.

  Given inputs
    * u16VehicleSpeed = const(60)
    * bLockRequest = const(1)
    * CrashSignal = pulse(width=0.5s, period=0s, delay=2s)
    * eStMotor = const(RUN)
  When simulate for 10s in Normal mode
  Then outputs
    * FlashDeactivated: FlashCmd == 0 when t > 3s
    * LockRestored: LockCmd == 1 when t > 3s

Scenario: 异常工况_传感器超范围
  Description: Verify component tolerates out-of-range sensor input.

  Given inputs
    * u16VehicleSpeed = const(65535)
    * bLockRequest = const(1)
    * f32Temperature = const(150)
    * eStMotor = const(RUN)
  When simulate for 10s in Normal mode
  Then outputs
    * OutputsWithinLimits: LockCmd == [0 .. 1]
    * NoNaNOutputs: UnlockCmd ~= NaN

Scenario: 异常工况_通信中断全零
  Description: Verify behavior under all-zero bus condition.

  Given inputs
    * u16VehicleSpeed = const(0)
    * bLockRequest = const(0)
    * CrashSignal = const(0)
    * eStMotor = const(STOP)
    * f32Temperature = const(0)
  When simulate for 10s in Normal mode
  Then outputs
    * SafeState: LockCmd == 0
    * SafeState: UnlockCmd == 0
    * SafeState: FlashCmd == 0
