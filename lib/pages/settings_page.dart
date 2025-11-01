import 'package:flutter/material.dart';
import 'dart:io';

import '../models/note.dart';
import '../services/storage_service.dart';
import 'export_notes_page.dart';
import 'package:file_selector/file_selector.dart';


/// A page that serves as a hub for navigating to various application settings.
/// It is a [StatelessWidget] as it only provides navigation and does not manage any internal state.
class SettingsPage extends StatelessWidget {
  /// A list of all notes, which is passed to the [ExportNotesPage] when the user
  /// navigates to it, allowing the export page to access the data it needs.
  final List<Note> notes;

  const SettingsPage({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          // A ListTile that navigates to the FontSettingsPage.
          ListTile(
            leading: const Icon(Icons.font_download),
            title: const Text('Font Size'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => FontSettingsPage()));
            },
          ),
          // A ListTile that navigates to the BackgroundSettingsPage.
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Background image'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => BackgroundSettingsPage()));
            },
          ),
          // A ListTile that navigates to the ExportNotesPage, passing the notes list.
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Export Notes'),
            onTap: () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => ExportNotesPage(notes: notes)));
            },
          ),
          // A ListTile that navigates to the AboutPage.
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => AboutPage()));
            },
          ),
        ],
      ),
    );
  }
}

// NOTE: The following pages are placed here because new files cannot be created.
// In a real project, each of these would be in its own file.

class FontSettingsPage extends StatefulWidget {
  const FontSettingsPage({super.key});

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  late double _titleScale;
  late double _bodyScale;
  late final StorageService _storage;

  @override
  void initState() {
    super.initState();
    _storage = StorageService.instance;
    _titleScale = _storage.titleScale;
    _bodyScale = _storage.bodyScale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display Font')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Font Size', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text('Title'),
                    Expanded(
                      child: Slider(
                        value: _titleScale,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: _titleScale.toStringAsFixed(2),
                        onChanged: (v) => setState(() => _titleScale = v),
                        onChangeEnd: (v) => _storage.saveTitleScale(v),
                      ),
                    ),
                  ]),
                  Row(children: [
                    const Text('Body'),
                    Expanded(
                      child: Slider(
                        value: _bodyScale,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: _bodyScale.toStringAsFixed(2),
                        onChanged: (v) => setState(() => _bodyScale = v),
                        onChangeEnd: (v) => _storage.saveBodyScale(v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Preview:', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text('Title Preview 123',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) * _titleScale)),
                  const SizedBox(height: 4),
                  Text('Body text preview for sizing.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * _bodyScale)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundSettingsPage extends StatefulWidget {
  const BackgroundSettingsPage({super.key});

  @override
  State<BackgroundSettingsPage> createState() => _BackgroundSettingsPageState();
}

class _BackgroundSettingsPageState extends State<BackgroundSettingsPage> {
  late final StorageService _storage;
  // Local state to trigger rebuilds
  String _bgPath = '';

  @override
  void initState() {
    super.initState();
    _storage = StorageService.instance;
    _bgPath = _storage.bgPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Background Image')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Options', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Select Image'),
                      onPressed: () async {
                        final typeGroup = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'webp']);
                        final file = await openFile(acceptedTypeGroups: [typeGroup]);
                        if (file != null) {
                          await _storage.saveBackgroundPath(file.path);
                          setState(() => _bgPath = file.path);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      onPressed: () async {
                        await _storage.saveBackgroundPath('');
                        setState(() => _bgPath = '');
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Preview:', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        image: _bgPath.isEmpty
                            ? null
                            : DecorationImage(image: FileImage(File(_bgPath)), fit: BoxFit.cover),
                      ),
                      child: _bgPath.isEmpty
                          ? const Center(child: Text('No background image'))
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const FlutterLogo(size: 80),
              const SizedBox(height: 24),
              Text(
                'Capsule',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 24),
              const Text(
                'A simple and beautiful note-taking app designed with Flutter.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
