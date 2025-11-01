import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';

import 'models/note.dart';
import 'services/storage_service.dart';
import 'pages/note_reader_page.dart';
import 'pages/settings_page.dart';
import 'pages/summary_page.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 入口：Material 3 + 路由
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化存储（创建默认文件、载入缓存）
  await StorageService.instance.init();
  runApp(const CapsuleApp());
}

class CapsuleApp extends StatefulWidget {
  const CapsuleApp({super.key});

  @override
  State<CapsuleApp> createState() => _CapsuleAppState();
}

class _CapsuleAppState extends State<CapsuleApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    final code = StorageService.instance.localeCode;
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
  }

  void _setLocale(Locale? locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    return MaterialApp(
      title: 'Capsule',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        textTheme: ThemeData.light().textTheme.apply(
              // 根据设置缩放字号
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
      ),
      home: HomePage(
          storage: storage,
          onLocaleChanged: _setLocale,
          currentLocale: _locale),
    );
  }
}

// 首页：列表 + 抽屉筛选 + 搜索 + 新建
class HomePage extends StatefulWidget {
  const HomePage(
      {super.key,
      required this.storage,
      this.onLocaleChanged,
      this.currentLocale});
  final StorageService storage;
  final void Function(Locale?)? onLocaleChanged;
  final Locale? currentLocale;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'all'; // 当前筛选状态
  String _keyword = '';
  Timer? _searchDebounce;

  void _onSearchChanged(String v) {
    // 防抖：等待用户停止输入 300ms 再触发实际搜索
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _keyword = v);
    });
  }

  // 从 notes 中提取第一个匹配关键字的片段（用于横幅显示），返回简短上下文
  String _extractFirstMatchSnippet(List<Note> notes, String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return '';
    final tokens = k
        .toLowerCase()
        .split(RegExp(r"\s+"))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';
    final pattern = tokens.map((t) => RegExp.escape(t)).join('|');
    final reg = RegExp(pattern, caseSensitive: false);

    for (final n in notes) {
      // search title, summary, content in order
      final fields = [n.title, n.summary, n.content];
      for (final f in fields) {
        if (f.isEmpty) continue;
        final m = reg.firstMatch(f);
        if (m != null) {
          final start = m.start;
          final end = m.end;
          const contextBefore = 30;
          const contextAfter = 30;
          final s = start - contextBefore < 0 ? 0 : start - contextBefore;
          final e =
              end + contextAfter > f.length ? f.length : end + contextAfter;
          var snippet = f.substring(s, e).trim();
          if (s > 0) snippet = '...$snippet';
          if (e < f.length) snippet = '$snippet...';
          return snippet.replaceAll('\n', ' ');
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.storage.getNotes(status: _status, keyword: _keyword);
    final bgPath = widget.storage.bgPath;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          // 使用 Builder 取得位于 Scaffold 之下的 context，避免 Scaffold.of 错误
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text('${l10n.capsule} (${notes.length})',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: '统计信息',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () async {
              final list = widget.storage.getNotes(status: 'all');
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SummaryPage(notes: list),
              ));
              setState(() {});
            },
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final allNotes = widget.storage.getNotes(status: 'all');
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsPage(
                  notes: allNotes,
                  onLocaleChanged: widget.onLocaleChanged,
                  currentLocale: widget.currentLocale,
                ),
              ));
              // Refresh state in case settings like background have changed
              setState(() {});
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      // Wrap body with GestureDetector so tapping empty areas dismisses the keyboard.
      body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(children: [
            // 背景层：可选图片
            if (bgPath.isNotEmpty)
              Positioned.fill(
                child: Image.file(File(bgPath), fit: BoxFit.cover),
              ),
            if (bgPath.isNotEmpty)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                      color: Colors.white.withAlpha((0.85 * 255).round())),
                ),
              ),
            // 内容层
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.search_hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                // 搜索结果横幅：当有关键字时显示匹配数量（本地化）
                if (_keyword.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha((0.08 * 255).round()),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        const Icon(Icons.search, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Builder(builder: (ctx) {
                            final snippet =
                                _extractFirstMatchSnippet(notes, _keyword);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.search_results(notes.length),
                                    style: Theme.of(ctx).textTheme.bodyMedium),
                                if (snippet.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(l10n.search_match_snippet(snippet),
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Theme.of(ctx).hintColor))
                                ]
                              ],
                            );
                          }),
                        ),
                        // 清除搜索按钮
                        IconButton(
                          icon: Icon(Icons.clear,
                              size: 18,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color),
                          tooltip: l10n.clear,
                          onPressed: () {
                            _searchDebounce?.cancel();
                            setState(() => _keyword = '');
                          },
                        ),
                      ]),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (_, i) => _NoteCard(
                      note: notes[i],
                      keyword: _keyword,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              NoteReaderPage(note: notes[i], keyword: _keyword),
                        ));
                        setState(() {});
                      },
                      onAction: (action) async {
                        // 统一在列表层处理，便于刷新与过滤
                        switch (action) {
                          case NoteAction.archive:
                            await widget.storage
                                .changeStatus(notes[i].id, 'archived');
                            break;
                          case NoteAction.unarchive:
                            await widget.storage
                                .changeStatus(notes[i].id, 'active');
                            break;
                          case NoteAction.delete:
                            await widget.storage
                                .changeStatus(notes[i].id, 'deleted');
                            break;
                          case NoteAction.restore:
                            await widget.storage
                                .changeStatus(notes[i].id, 'active');
                            break;
                          case NoteAction.deletePermanently:
                            await widget.storage.removePermanently(notes[i].id);
                            break;
                        }
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
          ])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final now = DateTime.now();
          final note = Note(
            id: 'n_${now.millisecondsSinceEpoch}',
            title: '',
            content: '',
            summary: '',
            tags: const [],
            status: 'draft',
            createdAt: now,
            updatedAt: now,
            comments: const [],
          );
          final nav = Navigator.of(context);
          await widget.storage.upsert(note);
          if (!mounted) return;
          await nav.push(MaterialPageRoute(
            builder: (_) => EditorPage(note: note),
          ));
          if (!mounted) return;
          setState(() {});
        },
        label: Text(l10n.new_item),
        icon: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // 抽屉：筛选不同状态
  Drawer _buildDrawer() {
    Widget tile(String title, String status, IconData icon) {
      final selected = _status == status;
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        selected: selected,
        onTap: () {
          setState(() => _status = status);
          Navigator.of(context).pop();
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('Menu', style: TextStyle(fontSize: 24))),
            ),
            tile('全部', 'all', Icons.all_inclusive),
            tile('归档', 'archived', Icons.archive_outlined),
            tile('已删除', 'deleted', Icons.delete_outline),
          ],
        ),
      ),
    );
  }
}

// 动作枚举：与参考样式一致
enum NoteAction { archive, unarchive, delete, restore, deletePermanently }

// 单个卡片：标题 + 词数 + 时间
class _NoteCard extends StatelessWidget {
  const _NoteCard(
      {required this.note,
      required this.onTap,
      required this.onAction,
      this.keyword = ''});
  final Note note;
  final VoidCallback onTap;
  final void Function(NoteAction action) onAction;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desc = note.summary.isNotEmpty
        ? note.summary
        : (note.content.split('\n').isNotEmpty
            ? note.content.split('\n').first.trim()
            : '');
    // 提取当前 note 的匹配片段（用于每条卡片下方显示）
    String extractSnippetForNote(Note n, String keyword) {
      final k = keyword.trim();
      if (k.isEmpty) return '';
      final tokens = k
          .toLowerCase()
          .split(RegExp(r"\\s+"))
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.isEmpty) return '';
      final pattern = tokens.map((t) => RegExp.escape(t)).join('|');
      final reg = RegExp(pattern, caseSensitive: false);
      final fields = [n.title, n.summary, n.content];
      for (final f in fields) {
        if (f.isEmpty) continue;
        final m = reg.firstMatch(f);
        if (m != null) {
          const contextBefore = 20;
          const contextAfter = 40;
          final start = m.start;
          final end = m.end;
          final s = start - contextBefore < 0 ? 0 : start - contextBefore;
          final e =
              end + contextAfter > f.length ? f.length : end + contextAfter;
          var snippet = f.substring(s, e).trim();
          if (s > 0) snippet = '...$snippet';
          if (e < f.length) snippet = '$snippet...';
          return snippet.replaceAll('\n', ' ');
        }
      }
      return '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(), // 药丸形
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              gradient: LinearGradient(colors: [
                scheme.primaryContainer,
                scheme.primaryContainer.withAlpha((0.85 * 255).round()),
              ]),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 标题，高亮搜索关键字（若存在）
                        if (note.title.isEmpty)
                          Text(AppLocalizations.of(context)!.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600))
                        else
                          Text.rich(
                            _buildHighlightedSpan(
                                note.title,
                                keyword,
                                Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600) ??
                                    const TextStyle(),
                                Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.yellow[800]) ??
                                    const TextStyle()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        if (desc.isEmpty)
                          Text(AppLocalizations.of(context)!.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall)
                        else
                          Text.rich(
                            _buildHighlightedSpan(
                                desc,
                                keyword,
                                Theme.of(context).textTheme.bodySmall ??
                                    const TextStyle(),
                                Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.yellow[800]) ??
                                    const TextStyle()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // 如果有搜索关键词，显示匹配的片段（高亮）
                        if (keyword.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Builder(builder: (ctx) {
                            final snippet =
                                extractSnippetForNote(note, keyword);
                            if (snippet.isEmpty) return const SizedBox.shrink();
                            return Text.rich(
                              _buildHighlightedSpan(
                                  snippet,
                                  keyword,
                                  Theme.of(ctx).textTheme.bodySmall ??
                                      const TextStyle(),
                                  Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                          backgroundColor:
                                              Colors.yellow[200]) ??
                                      const TextStyle()),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          })
                        ]
                      ]),
                ),
                PopupMenuButton<NoteAction>(
                  icon: Icon(Icons.more_horiz,
                      color: Colors.black.withAlpha((0.6 * 255).round())),
                  color: const Color(0xFFF2F2F7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  onSelected: onAction,
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<NoteAction>>[];
                    if (note.status == 'deleted') {
                      items.add(_popupStyled(NoteAction.restore,
                          Icons.restore_from_trash_outlined, 'Restore'));
                      items.add(_popupStyled(NoteAction.deletePermanently,
                          Icons.delete_forever_outlined, 'Delete Permanently'));
                    } else if (note.status == 'archived') {
                      items.add(_popupStyled(NoteAction.unarchive,
                          Icons.unarchive_outlined, 'Unarchive'));
                      items.add(_popupStyled(
                          NoteAction.delete, Icons.delete_outline, 'Delete'));
                    } else {
                      items.add(_popupStyled(NoteAction.archive,
                          Icons.archive_outlined, 'Archive'));
                      items.add(_popupStyled(
                          NoteAction.delete, Icons.delete_outline, 'Delete'));
                    }
                    return items;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建高亮 TextSpan（根据 keyword 中的 token 高亮匹配部分）
  TextSpan _buildHighlightedSpan(String source, String keyword,
      TextStyle baseStyle, TextStyle highlightStyle) {
    if (keyword.trim().isEmpty) return TextSpan(text: source, style: baseStyle);
    final tokens = keyword
        .trim()
        .toLowerCase()
        .split(RegExp(r"\s+"))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return TextSpan(text: source, style: baseStyle);

    // 构造一个不区分大小写的正则（将 tokens 转义后以 | 连接）
    final pattern = tokens.map((t) => RegExp.escape(t)).join('|');
    final reg = RegExp(pattern, caseSensitive: false);

    final children = <TextSpan>[];
    var lastEnd = 0;
    for (final m in reg.allMatches(source)) {
      if (m.start > lastEnd) {
        children.add(TextSpan(
            text: source.substring(lastEnd, m.start), style: baseStyle));
      }
      children.add(TextSpan(
          text: source.substring(m.start, m.end), style: highlightStyle));
      lastEnd = m.end;
    }
    if (lastEnd < source.length) {
      children.add(TextSpan(text: source.substring(lastEnd), style: baseStyle));
    }
    return TextSpan(children: children, style: baseStyle);
  }
}

PopupMenuItem<NoteAction> _popupStyled(
    NoteAction action, IconData icon, String text) {
  return PopupMenuItem<NoteAction>(
    value: action,
    height: 56,
    child: Row(children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Text(text)
    ]),
  );
}

// 编辑/预览页
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.note});
  final Note note;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  // 标题/描述/内容控制器
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _descController = TextEditingController(text: widget.note.summary);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, __) {
        if (didPop) return;
        _saveAndExit(storage);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => _saveAndExit(storage),
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => _saveAndExit(storage)),
          ],
        ),
        body: _buildEditingView(),
        bottomSheet: _buildMarkdownToolbar(),
      ),
    );
  }

  // 保存并退出
  Future<void> _saveAndExit(StorageService storage) async {
    final desc = _descController.text.trim();
    final body = _contentController.text;
    final trimmedTitle = _titleController.text.trim();
    final finalTitle = trimmedTitle.isEmpty
        ? AppLocalizations.of(context)!.untitled
        : trimmedTitle;

    final updated = widget.note.copyWith(
      title: finalTitle,
      content: body,
      summary: desc,
      updatedAt: DateTime.now(),
    );
    await storage.upsert(updated);
    if (mounted) Navigator.pop(context);
  }

  // 编辑区域布局
  Widget _buildEditingView() {
    final l10n = AppLocalizations.of(context)!;
    // 显示 "正在编辑已存在笔记" 的横幅：仅当笔记已有内容或状态不是 draft 时显示
    final showEditingBanner = widget.note.title.isNotEmpty ||
        widget.note.summary.isNotEmpty ||
        widget.note.content.isNotEmpty ||
        widget.note.status != 'draft';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: ListView(children: [
        if (showEditingBanner)
          Container(
            margin: const EdgeInsets.only(bottom: 12.0, top: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha((0.12 * 255).round()),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              const Icon(Icons.edit, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.editing_existing_note,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black87),
                ),
              ),
            ]),
          ),
        TextField(
          controller: _titleController,
          decoration:
              InputDecoration(hintText: l10n.title, border: InputBorder.none),
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _descController,
          decoration: InputDecoration(
              hintText: l10n.description, border: InputBorder.none),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contentController,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          decoration:
              InputDecoration(hintText: l10n.content, border: InputBorder.none),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ]),
    );
  }

  // Markdown 快捷工具栏
  Widget _buildMarkdownToolbar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _tb(Icons.format_bold, () => _insertSyntax('****', 2)),
            _tb(Icons.format_italic, () => _insertSyntax('**', 1)),
            _tb(Icons.format_strikethrough, () => _insertSyntax('~~~~', 2)),
            _tb(Icons.format_quote, () => _insertSyntax('> ', 2)),
            _tb(Icons.code, () => _insertSyntax('``', 1)),
            _tb(Icons.list, () => _insertSyntax('- ', 2)),
            _tb(Icons.looks_one, () => _insertSyntax('1. ', 3)),
          ],
        ),
      ),
    );
  }

  Widget _tb(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
          padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 22)),
    );
  }

  // 插入 Markdown 语法到正文
  void _insertSyntax(String syntax, int offset) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText =
        '${selection.textBefore(text)}$syntax${selection.textInside(text)}${selection.textAfter(text)}';
    _contentController.text = newText;
    _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: selection.start + offset));
  }
}
