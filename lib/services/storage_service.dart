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
      // 支持简单的模糊匹配：按空格切分多个 token，要求所有 token 都能在标题或正文中模糊匹配
      final tokens =
          k.split(RegExp('\\s+')).where((t) => t.isNotEmpty).toList();
      bool matchNote(Note n) {
        final title = n.title.toLowerCase();
        final content = n.content.toLowerCase();
        // 若任一 token 在 title 或 content 中完全包含，则匹配；否则尝试子序列模糊匹配
        for (final t in tokens) {
          if (title.contains(t) || content.contains(t)) continue;
          if (_isSubsequence(title, t) || _isSubsequence(content, t)) continue;
          return false;
        }
        return true;
      }

      it = it.where((n) => matchNote(n));

      // 为匹配结果计算一个简单的得分用于排序（越小越好）。得分基于 Levenshtein 距离与更新时间。
      final notesWithScore = it.map((n) {
        final score = _matchScore(n, k);
        return MapEntry(n, score);
      }).toList();

      notesWithScore.sort((a, b) {
        final s = a.value.compareTo(b.value);
        if (s != 0) return s;
        // 得分相同则按更新时间降序
        return b.key.updatedAt.compareTo(a.key.updatedAt);
      });

      final sorted = notesWithScore.map((e) => e.key).toList();
      return sorted;
    }
    // 按更新时间倒序
    final list = it.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  // 简单子序列模糊匹配：判断 pattern 的字符是否按顺序出现在 text 中
  bool _isSubsequence(String text, String pattern) {
    if (pattern.isEmpty) return true;
    var ti = 0;
    var pi = 0;
    while (ti < text.length && pi < pattern.length) {
      if (text.codeUnitAt(ti) == pattern.codeUnitAt(pi)) {
        pi++;
      }
      ti++;
    }
    return pi == pattern.length;
  }

  // 简单的匹配评分函数：基于 Levenshtein 距离对 title/summary/content 做近似评分
  // 返回越小表示匹配越好。为了效率，对 content 只取前 200 字符进行比较。
  int _matchScore(Note n, String query) {
    final q = query.toLowerCase();
    int best = 1 << 30;

    final title = n.title.toLowerCase();
    if (title.isNotEmpty) {
      final d = _levenshteinDistance(q, title);
      if (d < best) best = d;
      if (best == 0) return 0;
    }

    final summary = n.summary.toLowerCase();
    if (summary.isNotEmpty) {
      final d = _levenshteinDistance(q, summary);
      if (d < best) best = d;
      if (best == 0) return 0;
    }

    final content = n.content.toLowerCase();
    if (content.isNotEmpty) {
      // 使用滑动窗口在内容中查找与 query 的最小距离，窗口大小基于 query 长度（带一定上下文）
      final d = _minWindowDistance(content, q);
      if (d < best) best = d;
      if (best == 0) return 0;
    }

    if (best == (1 << 30)) return 1000000;
    return best;
  }

  // 在较长文本中使用滑动窗口找到与 query 的最小 Levenshtein 距离
  int _minWindowDistance(String text, String query) {
    if (query.isEmpty) return 0;
    final tq = query;
    final tlen = text.length;
    final qlen = tq.length;
    // 窗口大小：至少 qlen + 10，上限 200
    final windowSize = qlen + 10 > 200 ? 200 : qlen + 10;
    final step = qlen ~/ 2 > 0 ? qlen ~/ 2 : 1; // 跳步以提高性能

    var best = 1 << 30;
    if (tlen <= windowSize) {
      return _levenshteinDistance(tq, text);
    }

    for (var start = 0; start <= tlen - windowSize; start += step) {
      final end = start + windowSize;
      final window = text.substring(start, end);
      final d = _levenshteinDistance(tq, window);
      if (d < best) best = d;
      if (best == 0) return 0;
    }

    // 最后再比较结尾的一段，避免错过尾端匹配
    final tail = text.substring(tlen - windowSize);
    final dTail = _levenshteinDistance(tq, tail);
    if (dTail < best) best = dTail;
    return best;
  }

  // Levenshtein 编辑距离（简单实现）
  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    final List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s.codeUnitAt(i) == t.codeUnitAt(j) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1, // insertion
          v0[j + 1] + 1, // deletion
          v0[j] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
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
