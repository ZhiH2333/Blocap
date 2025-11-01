import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

import '../models/note.dart';

/// 导出选项
class ExportOptions {
  final bool includeMetadata;
  final String fileNameTemplate;
  const ExportOptions(
      {this.includeMetadata = true,
      this.fileNameTemplate = 'notes_export.json'});
}

/// 导出结果
class ExportResult {
  final String filePath;
  final int fileSize;
  const ExportResult({required this.filePath, required this.fileSize});
}

/// 导出异常
class ExportException implements Exception {
  final String message;
  const ExportException(this.message);
  @override
  String toString() => 'ExportException: $message';
}

/// 抽象目录提供者，便于测试
abstract class DirectoryProvider {
  Future<Directory> getTemporaryDirectory();
}

/// 导出服务：负责将笔记序列化为 JSON，写文件并支持分享
class ExportService {
  final DirectoryProvider _directoryProvider;
  ExportService({DirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? _DefaultDirectoryProvider();

  /// 导出笔记为 JSON 文件并返回文件路径与大小
  Future<ExportResult> exportNotesAsJson(
      {required List<Note> notes, required ExportOptions options}) async {
    if (notes.isEmpty) {
      // 选择返回空文件而不是抛异常，保持与 StorageService 导出行为一致
    }
    final Map<String, dynamic> payload = <String, dynamic>{};
    if (options.includeMetadata) {
      payload['metadata'] = <String, dynamic>{
        'exportedAt': DateTime.now().toIso8601String(),
        'count': notes.length
      };
    }
    payload['notes'] = notes.map((Note n) => n.toJson()).toList();
    final String jsonString =
        const JsonEncoder.withIndent('  ').convert(payload);
    final Directory dir = await _directoryProvider.getTemporaryDirectory();
    final String fileName =
        await _resolveUniqueFileName(options.fileNameTemplate, dir);
    final File file = File('${dir.path}/$fileName');
    try {
      await file.writeAsString(jsonString, encoding: utf8);
    } catch (e) {
      throw ExportException('写入文件失败：$e');
    }
    final int size = await file.length();
    return ExportResult(filePath: file.path, fileSize: size);
  }

  /// 分享已导出的文件（会弹出系统分享对话框）
  Future<void> shareExportedFile(
      {required String filePath, String? subject, String? text}) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw ExportException('要分享的文件不存在：$filePath');
    }
    try {
      if (kIsWeb) {
        // Web 平台：无法使用 share_plus 的本地文件分享，退回到读取 bytes 并使用 Share.shareXFiles 不支持 Web，这里抛出并提醒
        throw ExportException('Web 平台不支持直接分享本地文件，请在客户端下载。');
      }
      final XFile xfile = XFile(file.path);
      await Share.shareXFiles(<XFile>[xfile],
          subject: subject, text: text ?? '导出笔记');
    } catch (e) {
      throw ExportException('分享失败：$e');
    }
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

/// 默认目录提供者（为避免与 getTemporaryDirectory 重名，写在文件末尾）
class _DefaultDirectoryProvider implements DirectoryProvider {
  const _DefaultDirectoryProvider();
  @override
  Future<Directory> getTemporaryDirectory() =>
      path_provider.getTemporaryDirectory();
}
