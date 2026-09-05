# Survival Task 1 报告

## 改动文件

- `tests/survival/survival_domain_regression.gd`

测试直接 preload 并实例化 `DayCycleService`、`TemperatureService`、`FireStateService`，同时使用真实的 `TimeManager`、`GameManager` 常量和 `ResourceManager`。未实现任何服务或修改玩法代码。

## 红测

命令：

```powershell
& "C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/survival/survival_domain_regression.gd --quit-after 10
```

退出码：`1`

关键输出：

```text
SCRIPT ERROR: Parse Error: Preload file "res://scripts/domain/survival/day_cycle_service.gd" does not exist.
SCRIPT ERROR: Parse Error: Preload file "res://scripts/domain/survival/temperature_service.gd" does not exist.
SCRIPT ERROR: Parse Error: Preload file "res://scripts/domain/survival/fire_state_service.gd" does not exist.
```

该失败符合 brief 预期，原因是后续任务尚未创建服务文件。

## 完成后的测试

测试文件已完成并提交，但截至本报告生成时，三个目标 service 文件仍不存在，因此无法执行并声称绿测通过。服务实现完成后应重新运行上面的命令，并确认输出包含：

```text
SURVIVAL_DOMAIN_REGRESSION_OK
```

## Self-review

- 只新增 brief 指定的测试脚本和本报告。
- 断言覆盖日周期推进完成、默认炉火关闭、添加燃料后炉火激活、寒冷环境温度低于 10 度。
- 未使用 mock、空断言或生产代码改动。
- 未修改音频文件、`.import`、`.uid`、`default_bus_layout.tres` 或其他无关文件。

## 未决风险

- 绿测仍依赖后续任务提供的三个 service 文件及其精确方法签名。
- brief 提到的 `NightSettlementService` 尚无具体调用断言；当前测试严格遵循 brief 给出的测试代码，不自行推断接口。

