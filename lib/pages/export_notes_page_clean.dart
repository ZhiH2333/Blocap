import 'dart:io';

import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';

/// 清洁版导出页面（用于替代损坏的文件）
class ExportNotesPage extends StatefulWidget {
  final ExportService exportService;
  ExportNotesPage({super.key, ExportService? exportService})
      : exportService = exportService ?? ExportService();
  @override
  State<ExportNotesPage> createState() => _ExportNotesPageState();
}

class _ExportNotesPageState extends State<ExportNotesPage> {
  bool _isLoading = false;
  bool _includeMetadata = true;
  final TextEditingController _fileNameController =
      TextEditingController(text: 'notes_export.json');

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _onExportPressed() async {
    setState(() {
      _isLoading = true;
    });
    final List<Note> notes = StorageService.instance.getNotes();
    final ExportOptions options = ExportOptions(
        includeMetadata: _includeMetadata,
        fileNameTemplate: _fileNameController.text.trim());
    try {
      final ExportResult result = await widget.exportService
          .exportNotesAsJson(notes: notes, options: options);
      await widget.exportService.shareExportedFile(
          filePath: result.filePath, subject: '笔记导出', text: '请查看导出的笔记文件');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导出并分享成功：${_shortPath(result.filePath)}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _shortPath(String fullPath) {
    try {
      return fullPath
          .split(Platform.pathSeparator)
          .reversed
          .take(3)
          .toList()
          .reversed
          .join(Platform.pathSeparator);
    } catch (_) {
      return fullPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出笔记')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SwitchListTile(
                title: const Text('包含元数据（导出时间、数量）'),
                value: _includeMetadata,
                onChanged: (bool v) {
                  setState(() {
                    _includeMetadata = v;
                  });
                }),
            TextField(
                controller: _fileNameController,
                decoration: const InputDecoration(
                    labelText: '导出文件名', helperText: '例如：notes_export.json')),
            const SizedBox(height: 12),
            Row(children: <Widget>[
              Expanded(
                  child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _onExportPressed,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.share),
                      label: const Text('导出并分享')))
            ]),
          ],
        ),
      ),
    );
  }
}
