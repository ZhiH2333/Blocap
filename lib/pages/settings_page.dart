import 'package:flutter/material.dart';
import 'dart:io';

import '../models/note.dart';
import '../services/storage_service.dart';
import 'export_notes_page.dart';
import 'package:file_selector/file_selector.dart';
import '../l10n/app_localizations.dart';

/// Settings hub with localized strings and embedded settings pages.
class SettingsPage extends StatefulWidget {
  final List<Note> notes;
  final void Function(Locale?)? onLocaleChanged;
  final Locale? currentLocale;

  const SettingsPage(
      {super.key,
      required this.notes,
      this.onLocaleChanged,
      this.currentLocale});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final StorageService _storage;

  @override
  void initState() {
    super.initState();
    _storage = StorageService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentCode = widget.currentLocale?.languageCode ??
        _storage.localeCode ??
        Localizations.localeOf(context).languageCode;
    final currentLabel = currentCode == 'zh' ? l10n.chinese : l10n.english;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(currentLabel),
            onTap: () async {
              final choice = await showDialog<String?>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: Text(l10n.language),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'en'),
                      child: Text(l10n.english),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'zh'),
                      child: Text(l10n.chinese),
                    ),
                  ],
                ),
              );
              if (choice != null) {
                await _storage.saveLocale(choice);
                widget.onLocaleChanged?.call(Locale(choice));
                setState(() {});
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: Text(l10n.font_size),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FontSettingsPage())),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(l10n.background_image),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BackgroundSettingsPage())),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: Text(l10n.export_notes),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ExportNotesPage(notes: widget.notes))),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.about),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
        ],
      ),
    );
  }
}

// Embedded settings pages so we don't create new files in this environment.

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.font_size)),
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
                  Text(l10n.font_size,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text(l10n.title),
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
                    Text(l10n.description),
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
                  Text(l10n.preview,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(l10n.title_preview,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: (Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.fontSize ??
                                  22) *
                              _titleScale)),
                  const SizedBox(height: 4),
                  Text(l10n.body_preview,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: (Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontSize ??
                                  14) *
                              _bodyScale)),
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
  String _bgPath = '';

  @override
  void initState() {
    super.initState();
    _storage = StorageService.instance;
    _bgPath = _storage.bgPath;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.background_image)),
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
                  Text(l10n.options,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: Text(l10n.choose_image),
                      onPressed: () async {
                        const typeGroup = XTypeGroup(
                            label: 'images',
                            extensions: ['png', 'jpg', 'jpeg', 'webp']);
                        final file =
                            await openFile(acceptedTypeGroups: [typeGroup]);
                        if (file != null) {
                          await _storage.saveBackgroundPath(file.path);
                          setState(() => _bgPath = file.path);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.clear),
                      label: Text(l10n.clear),
                      onPressed: () async {
                        await _storage.saveBackgroundPath('');
                        setState(() => _bgPath = '');
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(l10n.preview,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        image: _bgPath.isEmpty
                            ? null
                            : DecorationImage(
                                image: FileImage(File(_bgPath)),
                                fit: BoxFit.cover),
                      ),
                      child: _bgPath.isEmpty
                          ? Center(child: Text(l10n.no_background))
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const FlutterLogo(size: 80),
              const SizedBox(height: 24),
              Text(l10n.capsule,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Version 1.0.0',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 24),
              Text(l10n.about_description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
