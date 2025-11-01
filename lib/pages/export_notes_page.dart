import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/storage_service.dart';

class ExportNotesPage extends StatelessWidget {
  final List<Note> notes;
  const ExportNotesPage({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Notes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('导出为 Markdown 文件至所选目录'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('选择目录并导出'),
            onPressed: () async {
              final dir = await getDirectoryPath();
              if (dir != null) {
                await StorageService.instance.exportToDirectory(dir, notes: notes);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出完成')));
                }
              }
            },
          ),
        ]),
      ),
    );
  }
}





