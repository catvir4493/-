# Narrative Presentation

Stage 17 使用组件式 Narrative UI，让顾客请求、服务反馈、章节节点和少量 Story Event 拥有一致的轻量文字表现。叙事组件只负责显示与输入，不拥有金钱、库存、顾客进度、章节进度或事件状态。

## DialoguePanel

`res://scenes/ui/components/DialoguePanel.tscn` 使用一个完整的 `RichTextLabel` 显示当前文本，并通过 `visible_characters` 安全揭示中文、英文、数字、标点与换行。

主要接口：

- `show_dialogue(speaker_name, text, instant)`
- `reveal_all()`
- `is_revealing()` / `is_finished()`
- `get_full_text()`
- `clear_dialogue()`

组件发出 `dialogue_started`、`dialogue_revealed` 和 `continue_requested` 信号，不切场景、不提交服务，也不改变业务数据。

## Text Speed

每段新文本调用 `show_dialogue()` 时读取 `SettingsManager.get_text_speed()`。默认基准为 `36 chars/sec`：

- 0.5x：18 chars/sec
- 1.0x：36 chars/sec
- 2.0x：72 chars/sec

设置修改后，下一段对话立即使用新倍率，无需重启。当前正在揭示的一段不动态变速。

## Input Behavior

鼠标左键、Enter 和 Space 使用同一输入状态：

1. 文本仍在揭示时，第一次输入只执行 Reveal All。
2. 文本已完整显示后，下一次输入才发出 Continue。

同一帧的重复输入会被拦截，避免一次 Space 同时 reveal 与 continue。DialoguePanel 使用 `MOUSE_FILTER_STOP`，点击不会穿透到下方 ItemCard。

## CustomerHeader vs DialoguePanel

`CustomerHeader` 负责头像、顾客名称和公开类型/描述。`DialoguePanel` 单独负责当前讲话内容与逐字逻辑。required/avoid tags 仍不会显示给玩家。

ShopScene 在对话逐字显示期间禁用商品卡片、清空和确认操作；玩家完整显示文本并 Continue 后，商品选择区恢复交互。该锁定只影响 Shop UI，不使用全局暂停。

ResultScene 使用 DialoguePanel 显示顾客反馈，同时始终保留评分、等级、收入、组合、命中、缺失与反效果信息。

## ChapterCard

`res://scenes/ui/components/ChapterCard.tscn` 显示 Chapter Start 与 Chapter Complete。

- Night 1、Night 6 的开始卡由对应一次性 `chapter_start` Story Event 是否刚刚触发决定。
- Night 5、Night 10 首次完成章节时显示完成卡。
- Chapter 标题读取 `chapters.json`，不会覆盖正式章节名称。
- Chapter 2 完成不是正式游戏结局，不显示 The End 或 Thanks for Playing。

## Story Events

`StoryEventSystem` 继续负责事件匹配、一次性记录与 `story_event_triggered` 信号。表现层只读取系统刚刚触发的事件，不改变触发条件。

Stage 17 映射：

- `event_ch2_begin`：由 ChapterCard 覆盖。
- `event_nurse_resignation`：ResultScene 反馈之后显示 NarrativeOverlay。
- `event_breakfast_apology`：ResultScene 反馈之后显示 NarrativeOverlay。
- `event_ch2_complete`：由 Chapter Complete 卡覆盖。

这样不会为同一节点连续显示重复窗口。

## NarrativeOverlay

`res://scenes/ui/components/NarrativeOverlay.tscn` 只显示标题和正文。它不调用 `mark_event_triggered()`、不写 Save，也不修改任何 story state。

ShopScene 复用它显示约一秒的“第 X 夜”标签；玩家可以点击跳过。ResultScene 用它显示少量已由 StoryEventSystem 触发的事件文本。

## Adding New Dialogue

未来新增 Customer Request 时，只需继续填写现有 `customers.json` 的 `dialogue` 字段。ShopScene 会把当前请求数据交给 DialoguePanel，不需要修改组件或新增 Dialogue JSON。

服务结果反馈继续由现有评分结果中的 `customer_feedback` 提供，也不需要为新顾客修改 DialoguePanel。

## Accessibility Extension

`get_full_text()` 始终返回当前完整字符串，文字没有拆成逐字 Label，也没有渲染成 Texture。未来可以直接复用该接口接入：

- TTS；
- screen reader；
- 字幕大小、对比度或背景选项；
- 可选的自动继续模式。

Stage 17 没有实现 Auto Mode、整段剧情 Skip、正式字体、逐字音效或配音。
