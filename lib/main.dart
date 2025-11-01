import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'models/note.dart';
import 'services/storage_service.dart';
import 'pages/note_reader_page.dart';
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
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsPage(storage: widget.storage),
              ));
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

  // 长按：笔记操作
  Future<void> _showNoteActions(Note note, BuildContext? anchorCtx) async {
    // 计算锚点位置：来自更多按钮的 context；若为空，使用中心位置
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    RelativeRect position;
    if (anchorCtx != null) {
      final box = anchorCtx.findRenderObject() as RenderBox;
      final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
      // 让菜单紧贴按钮下方：左对齐按钮左侧
      final left = offset.dx;
      final top = offset.dy + box.size.height;
      final right = overlay.size.width - left - box.size.width; // 相对右边距
      final bottom = overlay.size.height - top;
      position = RelativeRect.fromLTRB(left, top, right, bottom);
    } else {
      final center = overlay.size.center(Offset.zero);
      position = RelativeRect.fromLTRB(center.dx, center.dy, center.dx, center.dy);
    }

    final items = <PopupMenuEntry<String>>[];
    if (note.status == 'archived') {
      items.add(_popupItem('unarchive', Icons.archive_outlined, 'Unarchive'));
      items.add(_popupItem('delete', Icons.delete_outline, 'Delete'));
    } else if (note.status == 'deleted') {
      items.add(_popupItem('restore', Icons.restore_outlined, 'Restore'));
      items.add(_popupItem('delete_permanently', Icons.delete_forever_outlined, 'Delete Permanently'));
    } else {
      items.add(_popupItem('archive', Icons.archive_outlined, 'Archive'));
      items.add(_popupItem('delete', Icons.delete_outline, 'Delete'));
    }

    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: items,
    );

    switch (selected) {
      case 'archive':
        await widget.storage.changeStatus(note.id, 'archived');
        break;
      case 'unarchive':
        await widget.storage.changeStatus(note.id, 'active');
        break;
      case 'delete':
        await widget.storage.changeStatus(note.id, 'deleted');
        break;
      case 'restore':
        await widget.storage.changeStatus(note.id, 'active');
        break;
      case 'delete_permanently':
        await widget.storage.removePermanently(note.id);
        break;
    }
    setState(() {});
  }

  PopupMenuItem<String> _popupItem(String value, IconData icon, String text) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [Icon(icon), const SizedBox(width: 12), Text(text)]),
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
    final words = note.content.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
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
          onLongPress: () {},
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
                      items.add(_popupStyled(NoteAction.deletePermanently, Icons.delete_forever_outlined, 'Delete Permanently'));
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

// 统计信息页面：年度计数 + 可切换月份的日历（写过笔记显示小圆点）
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.storage});
  final StorageService storage;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late DateTime _currentMonth; // 当前月（使用该月的1号）

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final allNotes = widget.storage.getNotes(status: 'all');
    final thisYear = DateTime.now().year;
    final yearCount = allNotes.where((n) => n.createdAt.year == thisYear && n.status != 'deleted').length;
    final monthlyCounts = List<int>.generate(12, (m) => allNotes.where((n) => n.createdAt.year == thisYear && n.createdAt.month == m + 1 && n.status != 'deleted').length);
    final now = DateTime.now();
    final currentMonthCount = monthlyCounts[now.month - 1];
    final maxMonth = (monthlyCounts.fold<int>(0, (p, e) => e > p ? e : p)).clamp(1, 999);

    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceVariant.withOpacity(0.6);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 年度计数卡（左大数字 + 右单根竖条 + 下方月份字母）
          Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$yearCount', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary)),
                    const SizedBox(height: 4),
                    Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                    Text('This year', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                // 单根竖条：按当前月数量与最大值比例
                Container(
                  width: 6,
                  height: 80 * (currentMonthCount / (maxMonth == 0 ? 1 : maxMonth)).clamp(0.1, 1.0),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(width: 8),
              ]),
              const SizedBox(height: 12),
              // 月份首字母
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final m in const ['J','F','M','A','M','J','J','A','S','O','N','D'])
                    Text(m, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _MonthCalendar(month: _currentMonth, onPrev: _prevMonth, onNext: _nextMonth, onPickMonth: _pickMonth, notes: allNotes),
        ],
      ),
    );
  }

  void _prevMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
  void _nextMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1));

  Future<void> _pickMonth() async {
    final months = List.generate(12, (i) => i + 1);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: [
          for (final m in months)
            ListTile(
              title: Text('${_currentMonth.year}-${m.toString().padLeft(2, '0')}'),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (selected != null) setState(() => _currentMonth = DateTime(_currentMonth.year, selected, 1));
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.month, required this.onPrev, required this.onNext, required this.onPickMonth, required this.notes});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    // 生成日历网格
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7; // 0=周日
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7.0).ceil();
    final days = List<({int? day, bool hasNote})>.generate(rows * 7, (i) {
      final d = i - firstWeekday + 1;
      if (d < 1 || d > daysInMonth) return (day: null, hasNote: false);
      final has = notes.any((n) => n.status != 'deleted' && n.createdAt.year == month.year && n.createdAt.month == month.month && n.createdAt.day == d);
      return (day: d, hasNote: has);
    });

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_monthName(month.month)} ${month.year}', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ]),
          TextButton(onPressed: onPickMonth, child: const Text('选择月份')),
          const SizedBox(height: 8),
          _weekHeader(context),
          const SizedBox(height: 8),
          for (int r = 0; r < rows; r++)
            Row(children: [
              for (int c = 0; c < 7; c++)
                Expanded(child: _dayCell(context, days[r * 7 + c])),
            ]),
        ]),
      ),
    );
  }

  Widget _weekHeader(BuildContext context) {
    const names = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Row(
      children: names
          .map((n) => Expanded(
                child: Center(
                  child: Text(n, style: Theme.of(context).textTheme.labelSmall),
                ),
              ))
          .toList(),
    );
  }

  Widget _dayCell(BuildContext context, ({int? day, bool hasNote}) d) {
    if (d.day == null) return const SizedBox(height: 44);
    final today = DateTime.now();
    final isToday = today.year == month.year && today.month == month.month && today.day == d.day;
    return SizedBox(
      height: 44,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: isToday
              ? BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), shape: BoxShape.circle)
              : null,
          child: Text('${d.day}', style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: 4),
        if (d.hasNote)
          Container(width: 6, height: 6, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
      ]),
    );
  }

  String _monthName(int m) => const [
        'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
      ][m - 1];
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
    // 使用独立 summary 字段
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
        body: Column(
          children: [
            Expanded(child: _buildEditingView()),
            _buildMarkdownToolbar(),
          ],
        ),
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
      // 不再自动修改状态，保持原状态
      updatedAt: DateTime.now(),
    );
    await storage.upsert(updated);
    if (mounted) Navigator.pop(context);
  }

  // 编辑区域布局
  Widget _buildEditingView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(children: [
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
        Expanded(
          child: TextField(
            controller: _contentController,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(hintText: 'Content', border: InputBorder.none),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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

// 设置页：字体大小、背景图片、导出 Markdown
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.storage});
  final StorageService storage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _titleScale;
  late double _bodyScale;

  @override
  void initState() {
    super.initState();
    _titleScale = widget.storage.titleScale;
    _bodyScale = widget.storage.bodyScale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 字体大小设置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('显示字体'),
                Row(children: [
                  const Text('标题'),
                  Expanded(
                    child: Slider(
                      value: _titleScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: _titleScale.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _titleScale = v),
                      onChangeEnd: (v) => widget.storage.saveTitleScale(v),
                    ),
                  ),
                ]),
                Row(children: [
                  const Text('正文'),
                  Expanded(
                    child: Slider(
                      value: _bodyScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: _bodyScale.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _bodyScale = v),
                      onChangeEnd: (v) => widget.storage.saveBodyScale(v),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('预览：', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text('Title 1234+', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 20) * _titleScale)),
                Text('content 1234+', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * _bodyScale)),
              ]),
            ),
          ),

          // 背景图片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('背景图片'),
                const SizedBox(height: 8),
                Row(children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('选择图片'),
                    onPressed: () async {
                      // 使用 file_selector 选择图片路径
                      final typeGroup = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'webp']);
                      final file = await openFile(acceptedTypeGroups: [typeGroup]);
                      if (file != null) {
                        await widget.storage.saveBackgroundPath(file.path);
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('清除'),
                    onPressed: () async {
                      await widget.storage.saveBackgroundPath('');
                      if (mounted) setState(() {});
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      image: widget.storage.bgPath.isEmpty
                          ? null
                          : DecorationImage(image: FileImage(File(widget.storage.bgPath)), fit: BoxFit.cover),
                    ),
                    child: widget.storage.bgPath.isEmpty
                        ? const Center(child: Text('当前：无'))
                        : const SizedBox.shrink(),
                  ),
                ),
              ]),
            ),
          ),

          // 导出 Markdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('导出笔记（Markdown）'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('选择目录并导出'),
                  onPressed: () async {
                    final dirPath = await getDirectoryPath();
                    if (dirPath != null) {
                      await widget.storage.exportToDirectory(dirPath);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出完成')));
                      }
                    }
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
