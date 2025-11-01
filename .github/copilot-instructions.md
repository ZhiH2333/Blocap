## Capsule — AI 助手使用说明

目标：帮助 AI 代理快速在此代码库中完成常见任务（修 bug、实现小功能、更新导出逻辑等）。优先读取下列文件以获得上下文：

- `lib/main.dart` — 应用入口与首页、编辑器、路由示例。
- `lib/services/storage_service.dart` — 本地持久化实现（notes.json / settings.json）、缓存策略与状态变更接口。
- `lib/services/export_service.dart` / `lib/services/export_service_core.dart` — 导出与分享逻辑；`ExportServiceCore` 提供可注入的 `DirectoryProvider` 以便测试。
- `lib/models/note.dart`, `lib/models/comment.dart` — 数据模型与 JSON 序列化。
- `lib/pages/*.dart` — UI 页面示例（导出、阅读、设置、编辑等）。

重要架构与约定（要点）：

- 轻量单例服务：StorageService 使用 `StorageService.instance` 单例并在 `main()` 中调用 `init()`。直接在页面中通过 `StorageService.instance` 访问（例：`HomePage(storage: storage)`）。
- 存储位置与文件名：笔记保存在应用文档目录下 `notes.json`，设置保存在 `settings.json`。注意代码期望 JSON 字段：`notes`、`titleScale`、`bodyScale`、`bgPath`。
- 状态字符串约定：`'active'`, `'draft'`, `'archived'`, `'deleted'`。列表过滤使用这些字符串（例：`getNotes(status: 'all')` 会过滤掉 archived/deleted）。
- ID 生成：代码习惯用 `n_${DateTime.now().millisecondsSinceEpoch}` 和 `c_${...}` 生成笔记与评论 id。保持该格式或兼容它以避免冲突。
- 导出/分享：导出逻辑分为两层：核心写文件（`ExportServiceCore.exportNotesAsJson`）与平台分享（`ExportService.shareExportedFile` 使用 `share_plus`）。测试时优先使用 Core 并注入模拟 `DirectoryProvider`。
- UI/内容格式：笔记内容为 Markdown（使用 `flutter_markdown` 渲染），ExportNotesPage 会把 `summary`（字段名为 `word` 的映射）与 `content` 写入 Markdown 导出。

测试与开发工作流（可执行的、可验证的步骤）：

- 安装依赖：在仓库根目录运行 `flutter pub get`。
- 运行应用：`flutter run`（会在可用设备/模拟器上启动）。
- 运行测试：`flutter test test/export_service_test.dart`（项目中已有导出服务的单元测试）。
- 文件系统注意：StorageService 使用 `path_provider.getApplicationDocumentsDirectory()`；在单元测试或 CI 中需要用依赖注入/模拟或使用 `ExportServiceCore` 的 `DirectoryProvider` 测试缝隙。

代码风格与常见模式（举例）：

- 直接在 Widget 中调用同步 Service API（例如 `StorageService.instance.getNotes()`），并在变更后调用 `setState()` 刷新。
- 保存/更新笔记使用 `upsert(Note)`，并在 UI 层统一处理状态变更（`changeStatus`, `removePermanently`）。
- 导出文件命名策略：`<safeTitle>_YYYY-MM-DD.md` 或 JSON 导出模板 `notes_export.json`，`ExportServiceCore` 会自动避免文件名冲突（通过加 `_1`, `_2` 等）。

变更/贡献注意事项：

- 若需修改持久化格式（notes.json 字段等），请同时更新 `Note.fromJson` / `toJson` 与 `StorageService._loadNotes/_saveNotes`。保持向后兼容或提供迁移逻辑。
- 若添加导出/分享平台（例如 Web），优先在 `ExportServiceCore` 中实现文件生成逻辑，然后在 `ExportService` 中处理平台差异（目前 `share_plus` 在 Web 有限支持）。

搜索示例（快速定位相关实现）：

- 查找存储相关：`StorageService`（文件：`lib/services/storage_service.dart`）
- 查找导出相关：`ExportService` / `ExportServiceCore`（文件：`lib/services/export_service*.dart`）
- 查找模型：`Note` / `Comment`（文件：`lib/models/note.dart`, `lib/models/comment.dart`）

如果你需要补充或把规则放宽为 PR 提交规范，我可以把这些要点转为 CONTRIBUTING 段落或把测试/CI 运行命令加入 README。请告诉我有没有遗漏的工作流或约定（例如特定 CI、分支策略或代码扫描工具）。

— 自动生成（由 AI 代理合并）
