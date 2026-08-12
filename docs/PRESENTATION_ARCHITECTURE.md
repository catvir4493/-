# 表现层基础架构（Stage 13）

## 目标与边界

Stage 13 只建立全局配置、设置、音频和场景过渡框架，不增加顾客、物品、剧情、结局或经济规则。设置存档与游戏存档完全独立，游戏存档继续使用 `save_version = 1`。

## 组件职责

### GameConfig

`res://scripts/config/GameConfig.gd` 是非 Autoload 的只读常量容器。当前集中保存：

- 游戏标题与显示版本；
- 设置默认值及文本速度合法范围；
- 设置文件路径；
- 已有主要场景路径；
- 默认淡入淡出时长。

需要这些值的脚本应使用 `preload` 引用，避免为了常量再增加全局节点。

### SettingsManager

`SettingsManager` 是设置数据的唯一所有者，读写 `user://settings.json`，当前 `settings_version = 1`。它负责：

- 缺失文件、损坏 JSON、缺失字段和字段类型错误时回退到默认值；
- 将音量与文本速度限制在合法范围；
- 将 Master、BGM、SFX 音量应用到音频总线；
- 在非 headless 环境应用全屏模式；
- 提供导入、导出、重置、读取和逐项更新接口。

设置文件不经过 `SaveManager`，设置改动不会改变当前夜晚、金钱、库存、顾客进度或游戏存档版本。

### SaveManager vs SettingsManager

`SaveManager` 只管理游戏进度，例如检查点场景、夜晚、金钱、库存、顾客与章节进度；`SettingsManager` 只管理玩家偏好。两者使用不同文件、不同版本号和不同导入导出接口。新增设置时不得把字段写入 `save_data.json`，新增进度字段时也不得写入 `settings.json`。

### AudioManager

`AudioManager` 只负责播放控制，不保存音量。节点启动时创建：

- 一个输出到 `BGM` 总线的 BGM 播放器；
- 四个输出到 `SFX` 总线的短音效播放器。

它提供 BGM 播放、停止、暂停、恢复、基础淡入淡出，以及短音效播放和停止接口。空音频资源会被安全忽略；重复请求当前仍在播放的同一 BGM 不会从头播放。

项目音频总线定义在 `res://default_bus_layout.tres`：`Master`、`BGM`、`SFX`，后两者都发送到 `Master`。

### SceneTransitionManager

`SceneTransitionManager` 是场景文件切换的唯一底层入口，负责：

- 切换前校验场景路径；
- 阻止切换过程中的重复请求；
- 在可视运行模式执行黑色遮罩淡出、切换、淡入；
- 在 headless 模式立即切换，便于自动化测试；
- 失败时清理遮罩与忙碌状态，并发出失败信号。

现有场景继续调用 `GameManager` 的语义化方法，例如 `go_to_shop()`、`go_to_archive()`；`GameManager` 再把实际切换统一委托给 `SceneTransitionManager`。旧的 `GameManager.scene_change_*` 信号仍被转发，因此既有 UI 的失败恢复逻辑保持兼容。

## 设置界面与启动流程

主菜单的 Settings 按钮不依赖是否存在游戏存档。设置页位于 `res://scenes/settings/SettingsScene.tscn`，包含：

- Master、BGM、SFX 音量；
- 文本速度；
- 全屏开关；
- 屏幕震动开关；
- 恢复默认与返回主菜单。

音量与显示选项在控件变化时立即应用；返回主菜单时写入设置文件。`SettingsManager` 的 Autoload 顺序早于其他游戏管理器，启动时会先加载并应用现有设置。

## 后续内容接入规则

### 文本速度

`DialoguePanel` 已将文本速度正式接入逐字显示。每段新文本开始时读取 `SettingsManager.get_text_speed()`，以 `36 chars/sec × text_speed` 计算实际速度；0.5x、1.0x、2.0x 分别对应 18、36、72 chars/sec。不要在对话资源或单个场景里另存一份文本速度。

### 音频资源

后续可在 `res://assets/audio/bgm/` 与 `res://assets/audio/sfx/` 放置已确认授权的资源。业务场景只向 `AudioManager` 传入 `AudioStream`：

- 环境音乐与主题音乐调用 `play_bgm()`，由管理器输出到 BGM 总线；
- 按钮、结算和环境短音效调用 `play_sfx()`，由管理器输出到 SFX 总线；
- 不在业务场景直接修改总线音量；
- 场景重复进入时可再次请求同一 BGM，管理器会避免重启。

### 屏幕震动

实现任何震动效果前先检查 `SettingsManager.is_screen_shake_enabled()`。关闭时必须跳过位移或相机噪声，不能只把振幅调低。

### Adding New Settings

新增玩家偏好时按以下顺序处理：

1. 在 `GameConfig` 增加默认值和必要的合法范围；
2. 在 `SettingsManager._default_settings()`、导入、查询、更新和应用流程中加入字段；
3. 对缺失字段与错误类型保持向后兼容，只有格式确实变化时才提升 `settings_version`；
4. 在设置页加入临时控件并通过 `SettingsManager` 更新，业务场景不得自行写设置文件；
5. 在 Stage 13 长期 smoke test 中加入默认值、范围、持久化、损坏文件恢复和游戏存档隔离验证；
6. 更新本文档，但不要修改 `SaveManager.CURRENT_SAVE_VERSION`。

## 验证

`res://tests/stage13_presentation_framework_smoke.gd` 使用独立测试路径验证设置读写、容错、合法范围、音频路由、设置页、场景过渡失败恢复，以及 Stage 11B/Stage 12 的关键不变量。测试不会写入玩家真实的 `user://settings.json`。
