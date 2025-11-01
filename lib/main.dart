import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'models/note.dart';
import 'services/storage_service.dart';
import 'pages/note_reader_page.dart';
import 'pages/settings_page.dart';
import 'pages/summary_page.dart';

// 入口：Material 3 + 路由
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化存储（创建默认文件、载入缓存）
  await StorageService.instance.init();
  runApp(const CapsuleApp());
}

class CapsuleApp extends StatelessWidget {
  const CapsuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    return MaterialApp(
      title: 'Capsule',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        textTheme: ThemeData.light().textTheme.apply(
              // 根据设置缩放字号
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
      ),
      home: HomePage(storage: storage),
    );
  }
}

// 首页：列表 + 抽屉筛选 + 搜索 + 新建
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.storage});
  final StorageService storage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'all'; // 当前筛选状态
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final notes = widget.storage.getNotes(status: _status, keyword: _keyword);
    final bgPath = widget.storage.bgPath;
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          // 使用 Builder 取得位于 Scaffold 之下的 context，避免 Scaffold.of 错误
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text('Capsule (${notes.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
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
                builder: (_) => SettingsPage(notes: allNotes),
              ));
              // Refresh state in case settings like background have changed
              setState(() {});
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(children: [
        // 背景层：可选图片
        if (bgPath.isNotEmpty)
          Positioned.fill(
            child: Image.file(File(bgPath), fit: BoxFit.cover),
          ),
        if (bgPath.isNotEmpty)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.white.withOpacity(0.85)),
            ),
          ),
        // 内容层
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索标题/内容/标签',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (_, i) => _NoteCard(
                  note: notes[i],
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NoteReaderPage(note: notes[i]),
                    ));
                    setState(() {});
                  },
                  onAction: (action) async {
                    // 统一在列表层处理，便于刷新与过滤
                    switch (action) {
                      case NoteAction.archive:
                        await widget.storage.changeStatus(notes[i].id, 'archived');
                        break;
                      case NoteAction.unarchive:
                        await widget.storage.changeStatus(notes[i].id, 'active');
                        break;
                      case NoteAction.delete:
                        await widget.storage.changeStatus(notes[i].id, 'deleted');
                        break;
                      case NoteAction.restore:
                        await widget.storage.changeStatus(notes[i].id, 'active');
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
      ]),
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
          await widget.storage.upsert(note);
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EditorPage(note: note),
          ));
          setState(() {});
        },
        label: const Text('新建'),
        icon: const Icon(Icons.add),
      ),
    );
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
              child: Align(alignment: Alignment.bottomLeft, child: Text('Menu', style: TextStyle(fontSize: 24))),
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
  const _NoteCard({required this.note, required this.onTap, required this.onAction});
  final Note note;
  final VoidCallback onTap;
  final void Function(NoteAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desc = note.summary.isNotEmpty
        ? note.summary
        : (note.content.split('\n').isNotEmpty ? note.content.split('\n').first.trim() : '');
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
                scheme.primaryContainer.withOpacity(0.85),
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
                        Text(note.title.isEmpty ? 'Title' : note.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(desc.isEmpty ? 'Description' : desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                PopupMenuButton<NoteAction>(
                  icon: Icon(Icons.more_horiz, color: Colors.black.withOpacity(0.6)),
                  color: const Color(0xFFF2F2F7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  onSelected: onAction,
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<NoteAction>>[];
                    if (note.status == 'deleted') {
                      items.add(_popupStyled(NoteAction.restore, Icons.restore_from_trash_outlined, 'Restore'));
                      items.add(_popupStyled(
                          NoteAction.deletePermanently, Icons.delete_forever_outlined, 'Delete Permanently'));
                    } else if (note.status == 'archived') {
                      items.add(_popupStyled(NoteAction.unarchive, Icons.unarchive_outlined, 'Unarchive'));
                      items.add(_popupStyled(NoteAction.delete, Icons.delete_outline, 'Delete'));
                    } else {
                      items.add(_popupStyled(NoteAction.archive, Icons.archive_outlined, 'Archive'));
                      items.add(_popupStyled(NoteAction.delete, Icons.delete_outline, 'Delete'));
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
}

PopupMenuItem<NoteAction> _popupStyled(NoteAction action, IconData icon, String text) {
  return PopupMenuItem<NoteAction>(
    value: action,
    height: 56,
    child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(text)]),
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
      onPopInvoked: (didPop) {
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
            IconButton(icon: const Icon(Icons.check), onPressed: () => _saveAndExit(storage)),
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
    final finalTitle = trimmedTitle.isEmpty ? 'Untitled' : trimmedTitle;

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: ListView(children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _descController,
          decoration: const InputDecoration(hintText: 'Description', border: InputBorder.none),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        TextField(
            controller: _contentController,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(hintText: 'Content', border: InputBorder.none),
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
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
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
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 22)),
    );
  }

  // 插入 Markdown 语法到正文
  void _insertSyntax(String syntax, int offset) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = '${selection.textBefore(text)}$syntax${selection.textInside(text)}${selection.textAfter(text)}';
    _contentController.text = newText;
    _contentController.selection = TextSelection.fromPosition(TextPosition(offset: selection.start + offset));
  }
}
