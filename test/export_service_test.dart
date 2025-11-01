import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:capsule/models/note.dart';
import 'package:capsule/models/comment.dart';
import 'package:capsule/services/export_service_core.dart';

class _TempDirectoryProvider implements DirectoryProvider {
  final Directory tempDir;
  _TempDirectoryProvider(this.tempDir);
  @override
  Future<Directory> getTemporaryDirectory() async => tempDir;
}

void main() {
  test('exportNotesAsJson should write a valid JSON file', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('capsule_export_test');
    final ExportServiceCore service =
        ExportServiceCore(directoryProvider: _TempDirectoryProvider(tempDir));
    final Note note = Note(
      id: '1',
      title: '测试笔记',
      content: '内容',
      summary: '摘要',
      tags: <String>['test'],
      comments: <Comment>[],
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final ExportResult result = await service
        .exportNotesAsJson(notes: <Note>[note], options: const ExportOptions());
    final File file = File(result.filePath);
    expect(await file.exists(), isTrue);
    final String text = await file.readAsString();
    final dynamic decoded = jsonDecode(text);
    expect(decoded is Map<String, dynamic>, isTrue);
    await tempDir.delete(recursive: true);
  });
}
