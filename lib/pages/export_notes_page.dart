import 'dart:io';

import 'package:capsule/models/note.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

/// A page that allows users to select and export notes as a Markdown file.
class ExportNotesPage extends StatefulWidget {
  final List<Note> notes;

  const ExportNotesPage({super.key, required this.notes});

  @override
  State<ExportNotesPage> createState() => _ExportNotesPageState();
}

/// Manages the state for ExportNotesPage, including note selection and the export process.
class _ExportNotesPageState extends State<ExportNotesPage> {
  // A map to keep track of which notes are selected for export.
  final Map<String, bool> _selection = {};
  // A flag to determine whether to include comments in the export.
  bool _exportComments = false;

  // Exports the selected notes as a single Markdown file.
  Future<void> _exportNotes() async {
    final selectedNotes =
        widget.notes.where((note) => _selection[note.id] ?? false).toList();

    if (selectedNotes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.no_notes_selected)),
      );
      return;
    }

    // Prepare the file and content.
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/notes_export.md';
    final file = File(filePath);

    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final note in selectedNotes) {
      buffer.writeln('# ${note.title}');
      buffer.writeln('## ${note.word}');
      buffer.writeln();
      buffer.writeln(note.content);
      buffer.writeln();

      // Conditionally include comments
      if (_exportComments && note.comments.isNotEmpty) {
        buffer.writeln('### Comments');
        buffer.writeln();
        for (final comment in note.comments) {
          buffer.writeln(
              '> [${dateFormat.format(comment.timestamp)}] ${comment.text}');
        }
        buffer.writeln();
      }

      buffer.writeln('---');
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString());

    // Use the share_plus package to share the exported file.
    final xFile = XFile(filePath);
    await Share.shareXFiles([xFile], text: 'Exported notes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.export_notes),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context)!.export_selected_notes,
            onPressed: _exportNotes,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.include_comments),
            subtitle: Text(AppLocalizations.of(context)!.include_comments_sub),
            value: _exportComments,
            onChanged: (bool value) {
              setState(() {
                _exportComments = value;
              });
            },
            secondary: const Icon(Icons.comment_outlined),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.notes.length,
              itemBuilder: (context, index) {
                final note = widget.notes[index];
                return CheckboxListTile(
                  title: Text(note.title.isEmpty
                      ? AppLocalizations.of(context)!.untitled_note
                      : note.title),
                  subtitle: Text(note.word,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  value: _selection[note.id] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      _selection[note.id] = value ?? false;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
