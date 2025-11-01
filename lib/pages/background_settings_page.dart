import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class BackgroundSettingsPage extends StatefulWidget {
  const BackgroundSettingsPage({super.key});

  @override
  State<BackgroundSettingsPage> createState() => _BackgroundSettingsPageState();
}

class _BackgroundSettingsPageState extends State<BackgroundSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Background image')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: const Text('Choose image'),
              onPressed: () async {
                final typeGroup = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'webp']);
                final file = await openFile(acceptedTypeGroups: [typeGroup]);
                if (file != null) {
                  await storage.saveBackgroundPath(file.path);
                  if (mounted) setState(() {});
                }
              },
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
              onPressed: () async {
                await storage.saveBackgroundPath('');
                if (mounted) setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                image: storage.bgPath.isEmpty
                    ? null
                    : DecorationImage(image: FileImage(File(storage.bgPath)), fit: BoxFit.cover),
              ),
              child: storage.bgPath.isEmpty ? const Center(child: Text('当前：无')) : const SizedBox.shrink(),
            ),
          ),
        ]),
      ),
    );
  }
}





