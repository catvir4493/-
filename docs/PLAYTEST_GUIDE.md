# Five-Night Playtest Guide

## 1. 删除旧存档

在 Godot 编辑器中打开项目，选择 **Project → Open User Data Folder**。关闭正在运行的游戏后，删除其中的 `save_data.json`。

Windows 的默认位置通常位于：

```text
%APPDATA%\Godot\app_userdata\深夜愿望便利店\save_data.json
```

只删除本项目目录中的 `save_data.json`，不要删除其他 Godot 项目的用户数据。

## 2. 开始全新五夜试玩

1. 删除旧存档。
2. 运行项目并确认 Continue 为禁用状态。
3. 点击 New Game。
4. 正常完成 Night 1–5；每夜结束后填写 `docs/PLAYTEST_CHECKLIST.md`。
5. 除非专门测试恢复流程，否则不要中途替换存档或使用 Save Debug State。

## 3. 打开 F3 调试面板

Debug 构建运行时按 **F3** 打开或隐藏 Debug Playtest Overlay。面板默认隐藏，不会出现在正式菜单中。

Release 导出中面板和所有调试操作都被禁用。`required_tags` 与 `avoid_tags` 只会显示在这个 Debug 面板里，不会显示在正式玩家 UI。

面板操作：

- **Jump to Night**：重建所选 Night 1–5 的队列与夜晚统计并进入 Shop；默认不保存。
- **Next Customer**：跳到本夜下一位顾客，不结算、不扣库存、不写进度、不写日志。
- **Refill Inventory**：仅把当前已解锁商品补到 `max_stock`；不改金钱、不解锁未来商品、不保存。
- **Add Money +100**：只增加运行时调试金钱；不保存。
- **Clear Runtime Debug Changes**：重新读取有效存档；没有有效存档时重新开始当前夜测试状态。
- **Save Debug State**：确认后覆盖当前单槽存档。这是唯一会主动保存当前调试状态的调试按钮。

## 4. 找到 `user://` 存档

在 Godot 编辑器选择 **Project → Open User Data Folder**，打开的目录就是本项目的 `user://`。存档文件为：

```text
user://save_data.json
```

## 5. 找到试玩日志

正常完成一次顾客服务后，Debug 构建会按会话写入：

```text
user://playtest_logs/session_<timestamp>.jsonl
```

每行是一个 JSON 对象，字段包括：

```text
timestamp, night, request_id, story_id, story_stage,
selected_item_ids, score, grade, matched_tags, missing_tags,
bad_tags, combo_names, income, money_after, inventory_after
```

Continue、读档、Debug Next Customer 和 Release 构建不会生成服务日志。日志写入失败只会报告 warning，不会中断游戏。

## 6. 记录 Bug 复现步骤

在 `docs/PLAYTEST_CHECKLIST.md` 的 Bugs 表中记录：

1. Bug ID 与发生场景。
2. 当前夜晚、顾客序号和顾客可见文本。
3. 操作前库存和资金。
4. 按顺序列出每次点击及所选商品。
5. 预期结果与实际结果。
6. 是否稳定复现、复现次数和严重程度。
7. 是否使用过 F3 调试操作；若使用，写明按钮和顺序。

截图或录像可以作为补充，但不能代替文字复现步骤。

## 7. 提供试玩材料

完成测试后，将以下内容一起提供给开发者：

- 已填写的 `docs/PLAYTEST_CHECKLIST.md` 副本；
- 本次会话对应的 `user://playtest_logs/session_<timestamp>.jsonl`；
- 相关截图或录像；
- 游戏版本或 commit；
- 如需诊断 Continue / 存档问题，经确认后附上 `save_data.json`。

日志和检查表可能包含完整游玩路线，请只发送给预期的开发者。

