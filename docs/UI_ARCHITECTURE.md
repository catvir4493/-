# UI Architecture

## Design Resolution

界面设计基准为 `1152 × 648`。主要页面使用 Full Rect 根节点、Anchor、Container、Size Flags 和 Minimum Size，不针对单个分辨率编写布局分支。

## Responsive Rules

- 页面根节点使用 Full Rect Anchor。
- 页面间距、标题字号和常用尺寸优先取自 `res://scripts/ui/UIDesignTokens.gd`。
- 横向和纵向结构使用 Container；Content 区域设置 Expand Fill。
- 长列表和档案正文使用 `ScrollContainer`。
- 控件只设置必要的 Minimum Size，不用固定坐标锁死布局。
- 长文本开启自动换行；`TextureRect` 明确使用保持比例的 stretch mode。
- 基础目标尺寸为 `1152×648`，同时兼容 `1280×720`、`1600×900`、`1920×1080`。

## Theme

全局临时主题位于 `res://assets/ui/themes/MidnightTheme.tres`，提供深夜蓝黑、暖色点缀和高对比文本。`UIThemeManager` 是唯一 Theme Manager，负责加载主题并连接 Stage 15 字体资源入口。

当前继续使用 Godot 默认字体。未来 `presentation_assets.json` 中 `font_ui_default` 提供有效资源后，`UIThemeManager.apply_font_assets()` 会把它应用到主主题。

## Design Tokens

`res://scripts/ui/UIDesignTokens.gd` 集中定义设计分辨率、间距、字号、按钮高度、面板内边距和少量公共尺寸。它不是 Autoload。

## Components

- `PrimaryButton`：统一关键操作按钮，保留文字和可用状态接口。
- `InfoPanel`：带可选标题与可滚动正文的信息面板。
- `ToastMessage`：复用单一节点显示短时提示；新提示可覆盖旧提示。
- `ConfirmDialog`：提供确认/取消信号的通用对话框，不强制所有操作使用。
- `ItemCard`：只负责商品展示和选择状态；图标通过 AssetRegistry 获取。
- `CustomerHeader`：只显示头像、名称和公开描述；不显示对话或 required/avoid tags。
- `DialoguePanel`：显示完整文本节点、逐字揭示和 reveal/continue 两段式输入；不拥有顾客或评分状态。
- `ChapterCard`：显示章节开始与章节完成的轻量文字卡。
- `NarrativeOverlay`：显示夜晚标签和少量 Story Event 文本，不检测或记录事件。
- `RestockItemCard`：进货页展示卡；购买行为仍由 RestockScene/InventorySystem 管理。
- `StatRow`：统一 Label/Value 统计行。
- `SectionTitle`：统一分区标题。
- `ScreenBackground`：通过 AssetRegistry 加载页面背景。

`ScreenLayout.tscn` 提供 Header、可扩展 Content 和 Footer 三个插槽。既有页面可以组合使用，无需为继承关系重写业务逻辑。`BaseScreen.gd` 只负责主题、公共页面根布局、UI 操作防重入和 Toast 接口。

## Asset Integration

所有 UI presentation assets 必须通过 `AssetRegistry` 解析。业务 Scene 与组件不得直接硬编码 `.png`、`.svg`、`.ogg` 或 `.wav` 资源路径。

背景、头像、商品图标、Logo、UI Icon 的映射由 `res://data/presentation_assets.json` 管理。缺失或错误的纹理资源由 Stage 15 fallback 机制安全替代；音频和字体缺失时安全返回空值。

## Adding New Screens

1. 使用 Full Rect `Control`，可继承 `BaseScreen.gd`，或组合 `ScreenLayout.tscn`。
2. 在 `_ready()` 中应用主 Theme；继承 BaseScreen 时调用 `super._ready()`。
3. 使用 Header/Content/Footer、Container 和 Size Flags 组织页面。
4. 长内容放入 ScrollContainer，按钮保留可读文字和键盘焦点。
5. 背景、Logo、图标等只使用 AssetRegistry ID。
6. 页面脚本保留自己的业务职责；不要把 money、inventory、评分或进度放进公共 UI 层。
7. 将新页面加入 Stage 14 smoke test 的加载与基础响应式检查。

## Adding Final Art

正式资源替换继续遵循 Stage 15 Asset Pipeline，不修改业务代码：

- Background：把文件放入背景目录，并更新 manifest 中对应 background ID。
- Portrait：按顾客档案的 `portrait_id` 更新 portrait manifest 条目。
- Item Icon：按商品 `id` 更新 item icon manifest 条目。
- Logo：更新 `logos` 分类中的 `main` 或其他 Logo ID。
- UI Icon：使用语义化 UI icon ID，在 manifest 中替换路径。

资源尺寸、命名、导入和验收规则见 `ASSET_PIPELINE.md` 与 `ASSET_REQUIREMENTS.md`。
