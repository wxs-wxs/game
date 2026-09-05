# Ember Camp 音频系统重设计规格

> 状态：设计已确认，等待实现计划
> 日期：2026-09-05
> 适用项目：`C:\projects\game`
> 引擎：Godot 4.7.2

## 1. 目标与边界

本设计重构全游戏音频系统，不把当前 `AudioManager` 的边界视为约束。目标是建立一个独立于场景生命周期、由语义事件驱动、支持多层环境和可靠反馈的音频服务，同时保持现有探索、交互、建造、存档、HUD 和输入行为不变。

第一阶段继续使用现有占位 WAV，不引入新的第三方音频素材。系统必须允许后续只替换音频资源和映射，而不修改玩法代码。

硬约束：音频错误、缺失资源、headless 运行或音频关闭都不能阻塞游戏逻辑，不能改变资源结果、随机数、存档和流程状态。

## 2. 全局架构

使用一个独立于场景生命周期的 `AudioService` Autoload 作为全游戏唯一音频入口：

```text
AudioService (Autoload)
├── AudioStateStore       设置、静音状态、运行时音频状态
├── AudioCatalog           cue 与资源定义
├── MusicController        双播放器交叉淡化与音乐状态机
├── AmbienceController     多层环境循环
├── SfxController          世界、UI、关键提示音池
├── SnapshotController     暂停、菜单、危险、室内、终局快照
└── AudioBusGraph          固定 AudioServer 总线与效果器
```

游戏模块不再持有 `game.audio`，不直接创建播放器，也不直接指定音频文件名。它们只发送语义事件或更新持续状态：

```gdscript
AudioService.emit("interaction.complete", {
    "kind": "fishing",
    "position": player.global_position
})

AudioService.set_world_state({
    "phase": "exploration",
    "location": "interior",
    "weather": "rain",
    "threat": "high",
    "fire_lit": true
})
```

固定数据流：

```text
Gameplay / UI
    -> semantic event or state change
    -> AudioService
    -> catalog lookup
    -> policy gate
       (priority / cooldown / concurrency / pause / mute)
    -> controller and player pool
    -> AudioServer bus
    -> output
```

状态和事件必须分离：天气、地点、危险等级、炉火状态是持续状态；交互完成、建造完成、按钮确认和死亡是瞬时事件。

## 3. 总线、控制器和混音快照

### 3.1 固定总线

总线和效果器在项目 bus layout 资源中定义，运行时只修改音量、静音和发送，不动态创建或删除总线：

```text
Master
├── Music
├── Ambience
│   ├── Environment
│   ├── Weather
│   └── Fire
├── SFX
│   ├── World
│   ├── UI
│   └── Critical
└── Voice (预留，不在第一阶段使用)
```

用户只看到 `Master / Music / Ambience / SFX` 四个设置；`World / UI / Critical` 是内部子总线。

### 3.2 音乐

`MusicController` 使用双播放器交叉淡化，至少支持：

- `exploration_day`
- `exploration_rain`
- `interior`
- `night_report`
- `menu`
- `game_over`

相同状态不重播；不同状态在 0.8 到 2 秒内交叉淡化。音乐状态由 `phase/location/weather/threat` 计算，不由地图脚本指定文件名。

### 3.3 环境层

环境拆为独立循环层：

- `Environment`：户外底噪或室内底噪；
- `Weather`：无雨、小雨、暴雨；
- `Fire`：营火或室内炉火；
- 未来可加入 `Water`、`Insects`。

室内暴雨且炉火点燃时，三个层可以同时存在并分别淡入淡出。雨声进入室内时降低音量并使用室内滤波。

### 3.4 SFX 池

- `World`：脚步、采集、门、钓鱼；
- `UI`：按钮、背包、保存和读取；
- `Critical`：死亡、危险、夜袭和严重失败。

`Critical` 永远预留声道。普通世界音效满载时只能抢占同组低优先级声音。带 `position` 的事件使用 `AudioStreamPlayer2D`，UI 事件使用普通 `AudioStreamPlayer`。

### 3.5 快照

快照通过优先级和目标值组合计算最终混音，关闭快照后重新计算，不直接恢复固定音量。初始快照目标如下：

| 状态 | Music | Environment | World SFX | UI/Critical |
| --- | ---: | ---: | ---: | ---: |
| 户外探索 | 0 dB | 0 dB | 0 dB | 0 dB |
| 室内 | 按音乐状态 | 按层 | -3 dB | 0 dB |
| 暂停菜单 | -8 dB | -18 dB | -24 dB | 0 dB |
| 背包/日志/报告 | -5 dB | -12 dB | -18 dB | 0 dB |
| 高威胁 | 切换紧张状态 | 保留天气 | 关键音优先 | 0 dB |
| 角色死亡 | 淡出 | 关闭 | 关闭 | 播放一次 |
| 游戏结束 | 播放结束曲 | 关闭 | 关闭 | 0 dB |

## 4. 事件目录

事件 ID 使用小写英文命名空间。第一阶段目录覆盖：

| 领域 | 事件 |
| --- | --- |
| UI | `ui.open`、`ui.close`、`ui.confirm`、`ui.cancel`、`ui.invalid`、`ui.save_complete`、`ui.load_complete` |
| 玩家 | `player.footstep`、`player.hurt`、`player.eat`、`player.use_medicine`、`player.cold_warning` |
| 交互 | `interaction.start`、`interaction.cancel`、`interaction.complete`、`interaction.failed`、`interaction.blocked` |
| 采集/制作 | `gather.hit`、`gather.collect`、`fishing.cast`、`fishing.catch`、`craft.complete`、`craft.failed` |
| 建造 | `build.place`、`build.progress`、`build.complete`、`build.invalid`、`house.upgrade` |
| 世界物件 | `door.open`、`door.close`、`fire.ignite`、`fire.extinguish`、`fire.fuel_low` |
| 生存 | `survival.food_warning`、`survival.temperature_warning`、`survival.threat_changed`、`survival.raid` |
| 日夜 | `day.dawn`、`day.dusk_warning`、`sleep.begin`、`night.report`、`event.reveal`、`event.choice` |
| 进度 | `task.complete`、`milestone.reached`、`blueprint.unlocked` |
| 终局 | `player.death`、`game.over` |

稳定参数限定为 `surface`、`kind`、`result`、`reason` 和 `severity`。第一阶段不为每种资源和天气组合建立独立 ID，而是使用参数选择变体。

每个 `AudioCue` 至少描述：

```text
id
event_kind: oneshot / loop / stinger
output_bus
stream_variants[]
base_volume_db
pitch_range
priority
cooldown_ms
max_instances
spatial_mode
max_distance
steal_policy
parameter_rules
```

## 5. 资源组织和降级

建议资源结构：

```text
assets/audio/
├── music/
├── ambience/
├── sfx/world/
├── sfx/ui/
├── sfx/critical/
├── cues/
└── SOURCES.md
```

第一阶段 cue 可以指向现有类别占位 WAV，但 ID、总线和策略必须真实存在。缺失资源按以下顺序处理：

```text
指定变体 -> 同类别 placeholder -> 静音 AudioStream
```

默认不生成正弦波；开发模式可选开启 debug beep，但不能把调试音当作正式资源。缺失资源只记录一次，不能刷屏。

启动时校验 cue ID、资源路径、总线名称、并发、冷却、优先级和循环标记。校验失败不阻止游戏启动，只将 cue 标记为 unavailable 并使用降级链。

目录在启动时加载，当前音乐和环境资源预加载，SFX 首次触发时懒加载并缓存。音频使用独立 RNG，不得调用游戏世界 RNG。

音量和静音属于用户设置，保存到 `user://audio_settings.cfg`。旧存档中的 `audio` 字段只迁移读取一次，之后不再把全局音频偏好写入游戏存档。未来替换真实资源时，必须在 `assets/audio/SOURCES.md` 记录来源、许可证和重新分发权限。

## 6. 游戏状态响应

关键状态转换如下：

```text
进入小屋
-> 发送 door.open
-> location = interior
-> 户外层淡出、室内层淡入
-> 音乐重新选择 interior
```

```text
完成钓鱼
-> interaction.complete(kind=fishing)
-> 成功入包后播放 fishing.catch
-> 空间不足则只播放 interaction.blocked(reason=inventory_full)
```

```text
体温跨过 warning/critical 阈值
-> 发送一次对应 warning
-> 同一严重级别进入冷却和锁存
-> 回到安全区后解除锁存
```

暂停、背包、储物、鱼处理、制作、建造、快捷键、日志、事件和报告窗口都使用 `modal` 快照，不由各 UI 自己修改播放器音量。

## 7. 迁移顺序

### 阶段 1：运行时骨架

1. 创建固定 bus layout 和效果器资源。
2. 创建 `AudioService`、`AudioCatalog`、`AudioCue`、音乐/环境/SFX/快照控制器。
3. 建立占位 cue 表和缺失资源降级。
4. 将音频设置迁移到独立配置文件。
5. 增加 headless 录制后端，允许断言事件、总线和策略。

### 阶段 2：玩法迁移

按风险顺序迁移 UI、交互、世界物件、玩家、生存状态、日夜流程和终局状态。旧 `play_sfx()`、`play_music()`、`play_ambience()` 只能作为临时适配转发，不能与新系统同时播放；所有调用迁移后删除旧 API、动态总线创建和旧播放器池。

### 阶段 3：资源和运行时验收

在系统行为稳定后，再按 cue 表替换真实素材。第一阶段不以真实素材质量作为完成条件。

## 8. 测试方案

新增 `tests/audio_service_regression.gd`，覆盖：

- bus layout 和层级；
- cue 重复、缺失资源、缺失总线校验；
- placeholder 和静音 fallback；
- SFX 并发、冷却、优先级、抢占和 Critical 声道保护；
- 相同音乐状态不重播；
- 室内、雨天、炉火三层环境共存；
- pause/modal/danger/game-over 快照叠加和恢复；
- 设置读写和旧存档迁移；
- 音频 RNG 与游戏 RNG 隔离；
- headless 环境不创建无效播放器、不抛脚本错误。

新增 gameplay integration 测试依次覆盖：

```text
户外探索 -> 下雨 -> 进入小屋 -> 点燃炉火 -> 暂停
-> 背包 -> 鱼处理 -> 储物 -> 建造完成 -> 夜间报告
-> 角色死亡/游戏结束
```

每个状态同时验证音频记录和原有玩法结果。完整现有回归集必须继续通过，目标保持 `ALL_TESTS_OK count=30`。

## 9. 验收标准

### 自动化

- 所有音频单元和集成测试通过；
- 编辑器解析检查通过；
- 完整现有回归集通过；
- headless、缺失资源和静音模式都不改变玩法结果。

### 运行时

- 脚步和连续交互不会刷屏或产生无界叠音；
- UI 音效不会被世界音效抢占；
- 暂停和窗口打开后世界声降低但 UI/Critical 清楚；
- 室内、雨天、炉火的层切换连续；
- 报告、死亡和游戏结束没有残留循环音；
- 保存/读取、重启和切换场景后音频状态一致；
- 缺失资源只静音降级，不影响画面、输入、存档和流程。

### 显示和流程回归

在 `960x540` 原生逻辑视口和 `1920x1080` 整数缩放输出下检查正常探索、暂停、背包、鱼处理、储物、建造、报告和结束状态，确认没有文字、图标、进度条、窗口或 HUD 重叠。音频系统不得改变任何 gameplay 结果。

## 10. 明确不在本阶段

- 新增第三方真实音频素材；
- 水资源饮水、烹饪、治疗和维护闭环；
- 多施工点和施工队列；
- 语音系统；
- 复杂中间件式互动音乐或大型战斗音频系统。

