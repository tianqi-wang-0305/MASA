# --- front-matter:toml ---
model = "Foc_2024b"
component = "Foc_2024b"

[inputs]
u16VehicleSpeed = "'u16VehicleSpeed'"
bLockRequest = "'bLockRequest'"
eStMotor = "'eStMotor'"
f32Temperature = "'f32Temperature'"

[outputs]
LockCmd = "'LockCmd'"
UnlockCmd = "'UnlockCmd'"
# --- end front-matter ---

Feature: Foc_2024b Boundary & Edge Case Tests
  Verification of component behavior at boundary conditions and edge cases.

Scenario: 边界工况_零输入
  Description: Verify component behavior when all inputs are at zero or minimum value.

  Given inputs
    * u16VehicleSpeed = const(0)
    * bLockRequest = const(0)
    * eStMotor = const(STOP)
    * f32Temperature = const(-40)
  When simulate for 10s in Normal mode
  Then outputs
    * NoSpuriousLock: LockCmd == 0
    * NoSpuriousUnlock: UnlockCmd == 0

Scenario: 边界工况_最大值输入
  Description: Verify component behavior when all inputs are at maximum value.

  Given inputs
    * u16VehicleSpeed = const(65535)
    * bLockRequest = const(1)
    * eStMotor = const(RUN)
    * f32Temperature = const(125)
  When simulate for 10s in Normal mode
  Then outputs
    * LockCmdInRange: LockCmd == [0 .. 1]
    * UnlockCmdFinite: UnlockCmd == [-inf .. inf]

Scenario: 边界工况_阶跃0到最大
  Description: Verify component handles abrupt transition from zero to maximum.

  Given inputs
    * u16VehicleSpeed = step(0 -> 65535 @ 1s)
    * bLockRequest = const(0)
    * eStMotor = const(RUN)
    * f32Temperature = const(25.5)
  When simulate for 10s in Normal mode
  Then outputs
    * LockCmdFinite: LockCmd == [-inf .. inf]
    * UnlockCmdFinite: UnlockCmd == [-inf .. inf]

Scenario: 边界工况_高温
  Description: Verify component behavior at extreme high temperature.

  Given inputs
    * u16VehicleSpeed = const(60)
    * bLockRequest = const(1)
    * eStMotor = const(RUN)
    * f32Temperature = const(125)
  When simulate for 10s in Normal mode
  Then outputs
    * LockCmdInRange: LockCmd == [0 .. 1]
