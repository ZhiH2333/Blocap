import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note.dart';

// 简单文件存储：将所有笔记保存在 app 文档目录下的 notes.json
// 设置保存在 settings.json
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  // 文件名常量
  final String _notesFileName = 'notes.json';
  final String _settingsFileName = 'settings.json';

  // 内存缓存：减少磁盘读写，提升流畅度
  List<Note> _notesCache = [];
  Map<String, dynamic> _settingsCache = {};

  // 初始化：确保文件存在
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesFile = File('${dir.path}/$_notesFileName');
    // 正确的设置文件路径：settings.json
    final settingsFile = File('${dir.path}/$_settingsFileName');

    if (!await notesFile.exists()) {
      await notesFile.writeAsString(jsonEncode({'notes': []}));
    }
    if (!await settingsFile.exists()) {
      await settingsFile.writeAsString(
          jsonEncode({'titleScale': 1.0, 'bodyScale': 1.0, 'bgPath': ''}));
    }

    // 读入缓存
    await _loadNotes();
    await _loadSettings();
  }

  // 读取笔记到缓存
  Future<void> _loadNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_notesFileName');
    final text = await file.readAsString();
    final map = jsonDecode(text) as Map<String, dynamic>;
    final list = (map['notes'] as List<dynamic>).cast<Map<String, dynamic>>();
    _notesCache = list.map((e) => Note.fromJson(e)).toList();
  }

  // 写入缓存到文件
  Future<void> _saveNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_notesFileName');
    final text =
        jsonEncode({'notes': _notesCache.map((e) => e.toJson()).toList()});
    await file.writeAsString(text);
  }

  // 设置读写
  Future<void> _loadSettings() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_settingsFileName');
    final text = await file.readAsString();
    _settingsCache = jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> _saveSettings() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_settingsFileName');
    await file.writeAsString(jsonEncode(_settingsCache));
  }

  // 对外：获取所有笔记（可选过滤）
  List<Note> getNotes({String status = 'all', String keyword = ''}) {
    Iterable<Note> it = _notesCache;
    // “all” 仅显示非归档、非删除（包含草稿与正常）
    if (status == 'all') {
      it = it.where((n) => n.status != 'archived' && n.status != 'deleted');
    } else {
      it = it.where((n) => n.status == status);
    }
    if (keyword.trim().isNotEmpty) {
      final k = keyword.trim().toLowerCase();
      it = it.where((n) =>
          n.title.toLowerCase().contains(k) ||
          n.content.toLowerCase().contains(k));
    }
    // 按更新时间倒序
    final list = it.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  // 新建或更新笔记
  Future<void> upsert(Note note) async {
    final index = _notesCache.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notesCache[index] = note;
    } else {
      _notesCache.add(note);
    }
    await _saveNotes();
  }

  // 修改状态（草稿/归档/删除/恢复）
  Future<void> changeStatus(String id, String status) async {
    final index = _notesCache.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notesCache[index] = _notesCache[index]
          .copyWith(status: status, updatedAt: DateTime.now());
      await _saveNotes();
    }
  }

  // 永久删除（仅 deleted 列表中使用）
  Future<void> removePermanently(String id) async {
    _notesCache.removeWhere((n) => n.id == id);
    await _saveNotes();
  }

  // 设置：标题与正文字体缩放，以及背景图路径
  double get titleScale =>
      (_settingsCache['titleScale'] as num?)?.toDouble() ?? 1.0;
  double get bodyScale =>
      (_settingsCache['bodyScale'] as num?)?.toDouble() ?? 1.0;
  String get bgPath => (_settingsCache['bgPath'] as String?) ?? '';

  /// 用户选择的语言代码（例如 'en' 或 'zh'），为空表示使用系统默认
  String? get localeCode => (_settingsCache['locale'] as String?);

  Future<void> saveTitleScale(double v) async {
    _settingsCache['titleScale'] = v;
    await _saveSettings();
  }

  Future<void> saveBodyScale(double v) async {
    _settingsCache['bodyScale'] = v;
    await _saveSettings();
  }

  Future<void> saveBackgroundPath(String path) async {
    _settingsCache['bgPath'] = path;
    await _saveSettings();
  }

  Future<void> saveLocale(String localeCode) async {
    _settingsCache['locale'] = localeCode;
    await _saveSettings();
  }

  // 导出：将指定目录下生成 .md 文件（文件名=标题_创建日期.md）
  Future<void> exportToDirectory(String dirPath, {List<Note>? notes}) async {
    final list =
        (notes ?? _notesCache).where((n) => n.status != 'deleted').toList();
    for (final n in list) {
      final safeTitle =
          n.title.isEmpty ? 'untitled' : n.title.replaceAll('/', '-');
      final date = n.createdAt.toIso8601String().split('T').first;
      final file = File('$dirPath/${safeTitle}_$date.md');
      final content = '# ${n.title}\n\n' // 标题
          '创建: ${n.createdAt}\n更新: ${n.updatedAt}\n状态: ${n.status}\n标签: ${n.tags.join(', ')}\n描述: ${n.summary}\n\n'
          '${n.content}\n';
      await file.writeAsString(content);
    }
  }
}
