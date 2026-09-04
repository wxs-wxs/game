# 余烬荒野（Ember Camp）

Godot 4.7.2 2D 像素风探索与生存原型。玩家直接操控唯一主角阿禾，在大于视口的荒野中寻找资源、回到营地准备过夜。

## 启动

```powershell
& "C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64.exe" --path "C:\projects\game"
```

也可以双击项目根目录的 `start_game.cmd`。如果直接运行 PowerShell 脚本被执行策略拦截，在当前 PowerShell 进程中执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start_game.ps1
```

这只对本次启动生效，不会修改系统或用户级执行策略。基础视口和 HUD authoring space 均为 960×540，默认全屏以 1920×1080（2 倍整数缩放）运行，纹理过滤使用最近邻并保持像素对齐；窗口拉伸采用整数缩放，避免放大时产生模糊边缘。

## 操作

- `WASD` 或方向键：四方向移动（使用 `CharacterBody2D`、碰撞检测和 `move_and_slide()`）
- `E`：靠近交互点后执行动作
- `Space`：暂停/继续
- `Esc`：暂停菜单
- 暂停菜单中的“退出游戏”：关闭当前游戏
- `F5` / `F9`：快速保存 / 读取
- `B`：进入/退出建造模式
- `U`：升级小屋
- `P`：切换当天营地政策（均衡、紧缩配给、加固防线、主动出击）

HUD 采用 960×540 原生网格的边缘信息布局：左上显示天数、时间和天气，顶部中央显示威胁状态，右上以 Ninja Adventure 16px 图标横向展示资源；右侧纵向操作栏集中背包、建造、升级、政策、存档和暂停，左下显示主角生存状态，右下显示当前目标与最近日志。所有标准面板和按钮使用 Kenney Pixel UI 九宫格，文本使用 Fusion Pixel，图标保持最近邻和整数尺寸。按 `K` 打开背包，按左上角 `?` 查看快捷键浮层，交互点有唯一 ID、范围、耗时、资源消耗、奖励、失败概率和冷却时间。

探索资源链：草地上的小石子提供石料，草地树枝和浆果丛提供木材；钓鱼只提供食物，废墟只提供废料、药品和金属。石斧需要石料 2、木材 3，可在底部工具栏制作；制作后才能靠近并砍伐森林树木获得木材。户外移动速度始终一致，玩家可以在开放地形中自由选择路线。

每个探索日会生成一个每日目标。完成目标会获得资源奖励并积累连胜，未完成会提高营地威胁；威胁过高时可能触发夜袭。游戏不会在第 7 天自动结束，只有主角阿禾的生命值降为 0 时才会结束。里程碑、政策效果和策略状态会随存档保存。

## 地图

地图尺寸为 1920×1080，户外按“营地清场、西侧密林、中央草甸、旧砖场、东岸浅滩、东侧高地、南部湿地”规划。区域之间是连续的开放草地，没有道路带、路线纹理或人为隔断；玩家可以从任意方向绕行。东侧水域是贯穿上下边界的弯曲河口/海岸带，用于隔绝地图边缘；水岸使用单一曲线碰撞体，不再用封闭池塘的四面空气墙。房屋、围栏、建筑、树木和岩石有对应的 `StaticBody2D` 碰撞体；地图四周不再放置空气墙，角色只在绘制区域边缘做软限制。摄像机跟随主角探索；进入小屋时会自动放大镜头以保持室内可读性。

营地房屋内只有一张床，白天可先休息，再次交互即可睡觉并进入夜间结算。室内炉火需要消耗 1 份木材才能点燃；点燃后会显示火焰，房屋外的烟囱同步冒烟，状态会随存档保存。

## 项目结构

```text
project.godot                 项目设置与移动输入映射
scenes/Main.tscn              主场景
scripts/main.gd               入口、暂停和存档快捷键
scripts/exploration_world.gd  程序绘制地图、障碍、摄像机和交互调度
scripts/explorer_player.gd    CharacterBody2D 主角
scripts/interaction_point.gd  通用交互点基类
scripts/fishing_spot.gd       钓鱼点
scripts/forage_spot.gd        森林采集点
scripts/pebble_spot.gd        路边小石子
scripts/branch_spot.gd        路边树枝
scripts/tree_spot.gd          石斧前置的树木交互点
scripts/ruin_spot.gd          废墟搜寻点与受伤风险
scripts/campfire_point.gd     室外营火点
scripts/bed_point.gd          单床休息/睡觉点
scripts/fireplace_point.gd    室内木材炉火
scripts/chimney_art.gd        房屋烟囱与动态烟雾
scripts/game_manager.gd       资源、天数、昼夜结算和存档状态
scripts/survival_director.gd  每日目标、政策、威胁、连胜与里程碑
scripts/resource_manager.gd   资源数量、容量和消费
scripts/time_manager.gd       探索日计时与暂停
scripts/save_system.gd        JSON 存档
tests/smoke.gd                探索流程烟测
tests/strategy_smoke.gd       策略目标、政策与结算烟测
tests/resource_chain_smoke.gd 石料、木材、石斧和树木资源链烟测
tests/interior_regression.gd  进屋移动与出屋回归测试
tests/house_fire_map_smoke.gd 单床、炉火、烟囱和地图边界烟测
tests/player_motion_regression.gd 角色行走帧与斜向朝向回归测试
assets/art/ninja_adventure/  Ninja Adventure CC0 世界、物件与地形素材
assets/player_character_reference.png  用户提供的四视图人物参考图
assets/player_character_sheet.png      去白底后的四向主角精灵图集
assets/player_character_walk_sheet.png 由四视图派生的四帧行走图集（左右脚交替）
tools/build_player_sprite.gd           人物参考图裁切、去底和图集生成脚本
```

## 美术资源

地图地标、交互点和 HUD 资源图标统一使用 `assets/art/ninja_adventure` 中
Ninja Adventure 的 CC0 16×16 素材（树、石堆、营火、营地小屋、废墟墙体、资源点）。
荒野地面采用 Ninja Adventure 示例地图的分层方式：开放草地保持干净的纯色底，
营地院落、采集地、废墟入口和河岸码头等有语义的局部区域使用官方
`TilesetFloor.png` 的中心、边缘和角落 Tile 拼接。地图没有道路带或路线纹理，
场景之间通过低对比度的自然地形色差、树群、草簇、碎石和水岸来区分；物体接触
阴影单独绘制。河岸和地标按独立绘制层排序，营火附近额外提供很弱的暖色环境光，
不会把整张地图压暗。
主角改用 `assets/player_character_reference.png` 提供的四视图人物，
由 `tools/build_player_sprite.gd` 裁切并去除白色背景，输出为 48×72 帧的最近邻过滤
`assets/player_character_sheet.png`，并派生出 `player_character_walk_sheet.png` 的四帧
行走循环；移动时会按朝向切换正面、侧面、背面和斜侧帧。上斜方向使用背面视图，
下斜方向使用镜像后的三分之四正面，避免右上移动时人物朝向反转。
HUD 和地图标签关闭字体抗锯齿与亚像素定位，保持中文像素字的清晰边缘。
原有碰撞、交互点 ID、奖励和存档数据保持不变。
树枝、钓鱼动作和少量天气 FX 仍保留程序绘制作为风格一致的缺口占位；
详细来源、许可证和导入方式见 `assets/art/ninja_adventure/ASSET_SOURCE.md` 与
`assets/art/open_ui/SOURCES.md`。

## 检查

```powershell
.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke.gd --quit-after 8
```

烟测会验证单主角、地图节点、交互奖励、暂停和存档读取。
