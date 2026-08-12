# 内容扩展指南

本项目的内容优先通过 JSON 扩展。不要把商品、顾客请求、组合、章节、事件或结局清单硬编码进场景脚本；UI 只消费 `DataManager` 和各系统提供的数据。

## 新商品

在 `data/items.json` 增加唯一 `id`，并完整填写名称、描述、价格、标签、稀有度、`unlock_day` 和 `max_stock`。标签应来自现有标签池；确需新标签时，要同步检查顾客需求与平衡脚本。商品解锁统一由 `ContentUnlockSystem.is_item_unlocked()` 判断，不要在新场景中再次手写 `unlock_day <= current_night`。

## 新顾客请求与档案

请求写入 `data/customers.json`，档案写入 `data/customer_profiles.json`。同一故事线复用稳定的 `story_id`；每个 `story_id + story_stage` 必须唯一，阶段从 1 开始顺序推进，不设置固定最大阶段。`customer_profiles.json` 必须为该故事线每个已存在的请求阶段提供对应 `archive_stages` 文本。`min_visit_count` 应与前置到访次数一致，`min_night` 不得晚于排期夜晚；一次性请求使用 `one_time: true`。真实档案是否可见由 `ContentUnlockSystem.is_profile_visible()` 判断。

不要在 `CustomerSystem` 之外硬编码故事阶段推进、一次性完成记录或跳阶段规则。新增故事线时同时添加唯一档案，并运行内容校验确认请求与档案互相引用。

## 新组合

在 `data/combos.json` 增加唯一 `id`、所需商品、额外标签、分数与反馈。所需商品必须存在。组合可发现性由 `ContentUnlockSystem.is_combo_discoverable()` 根据全部所需商品的解锁状态判断；实际触发仍由 `ComboSystem` 处理。

## 新夜晚

在 `data/nights.json` 增加夜晚配置和固定 `customer_slots`。槽位只引用 `story_id` 与 `story_stage`，不要复制顾客文本。排期必须满足请求的 `min_night`、`min_visit_count`、一次性约束和阶段顺序。若夜晚属于现有或新章节，还要更新 `data/chapters.json` 的起止夜晚与 `required_nights`。

## 新章节

在 `data/chapters.json` 增加唯一 `id`，配置 `start_night`、`end_night`、真实存在的 `required_nights`，以及章节终点故事的 `final_story_id` / `final_story_stage`。章节完成状态由 `ChapterSystem` 记录；场景可以在明确的章节终点调用 `mark_chapter_completed()`，不要依据 UI 文本推断完成。

如果后续章节存在前置条件，应扩展 `ContentUnlockSystem.is_chapter_available()`，不要把前置章节判断散落在菜单或场景中。

## 新故事事件

在 `data/story_events.json` 增加唯一 `id`、`type`、`trigger`、文本与 `one_time`。触发器引用的 `night`、`chapter_id`、`story_id + story_stage` 必须真实存在。当前 `StoryEventSystem` 只检测、打印并记录事件，不弹窗、不切场景，也不修改金钱或库存；正式演出应在后续独立表现层中订阅 `story_event_triggered` 信号。

## 新结局

在 `data/endings.json` 增加唯一 `id` 与 `conditions`。目前支持 `completed_chapter` 和 `min_night`；判断集中在 `EndingSystem`。需要新条件时先扩展该系统及测试，不要在结算场景复制条件。当前 `ending_mvp_placeholder` 只是占位状态，不对应正式结局场景。

## 验证流程

每次内容扩展至少运行：

```text
Godot --headless --path <项目目录> --script res://tests/content_validation.gd
Godot --headless --path <项目目录> --script res://tests/customer_queue_validation.gd
Godot --headless --path <项目目录> --script res://tests/stage10b_night_schedule_smoke.gd
Godot --headless --path <项目目录> --script res://tests/stage11_balance_audit.gd
Godot --headless --path <项目目录> --script res://tests/stage12_framework_smoke.gd
Godot --headless --path <项目目录> --quit
```

修改价格、标签、解锁夜晚、顾客需求、组合或排期后必须重跑平衡审计。提交前还应运行 `git diff --check`；若项目副本没有 Git 元数据，则改用编辑器/文件比较工具检查空白字符与修改范围，并在交付说明中明确这一限制。
