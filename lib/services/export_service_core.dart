import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart' as path_provider;

import '../models/note.dart';

/// 导出选项（核心）
class ExportOptions {
  final bool includeMetadata;
  final String fileNameTemplate;
  const ExportOptions({this.includeMetadata = true, this.fileNameTemplate = 'notes_export.json'});
}

/// 导出结果（核心）
class ExportResult {
  final String filePath;
  final int fileSize;
  const ExportResult({required this.filePath, required this.fileSize});
}

/// 导出异常（核心）
class ExportException implements Exception {
  final String message;
  const ExportException(this.message);
  @override
  String toString() => 'ExportException: $message';
}

/// 抽象目录提供者，便于测试（核心）
abstract class DirectoryProvider {
  Future<Directory> getTemporaryDirectory();
}

/// 默认目录提供者（核心）
class DefaultDirectoryProvider implements DirectoryProvider {
  const DefaultDirectoryProvider();
  @override
  Future<Directory> getTemporaryDirectory() => path_provider.getTemporaryDirectory();
}

/// 导出服务核心：负责将笔记序列化为 JSON 并写入文件（不包含分享逻辑）
class ExportServiceCore {
  final DirectoryProvider _directoryProvider;
  ExportServiceCore({DirectoryProvider? directoryProvider}) : _directoryProvider = directoryProvider ?? const DefaultDirectoryProvider();

  /// 导出笔记为 JSON 文件并返回文件路径与大小
  Future<ExportResult> exportNotesAsJson({required List<Note> notes, required ExportOptions options}) async {
    final Map<String, dynamic> payload = <String, dynamic>{};
    if (options.includeMetadata) {
      payload['metadata'] = <String, dynamic>{'exportedAt': DateTime.now().toIso8601String(), 'count': notes.length};
    }
    payload['notes'] = notes.map((Note n) => n.toJson()).toList();
    final String jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final Directory dir = await _directoryProvider.getTemporaryDirectory();
    final String fileName = await _resolveUniqueFileName(options.fileNameTemplate, dir);
    final File file = File('${dir.path}/$fileName');
    try {
      await file.writeAsString(jsonString, encoding: utf8);
    } catch (e) {
      throw ExportException('写入文件失败：$e');
    }
    final int size = await file.length();
    return ExportResult(filePath: file.path, fileSize: size);
  }

  Future<String> _resolveUniqueFileName(String template, Directory dir) async {
    String base = template;
    if (base.isEmpty) {
      base = 'notes_export.json';
    }
    final String name = base;
    String candidate = name;
    int index = 1;
    while (await File('${dir.path}/$candidate').exists()) {
      final int dot = name.lastIndexOf('.');
      if (dot > 0) {
        final String prefix = name.substring(0, dot);
        final String suffix = name.substring(dot);
        candidate = '${prefix}_$index$suffix';
      } else {
        candidate = '${name}_$index';
      }
      index += 1;
    }
    return candidate;
  }
}
