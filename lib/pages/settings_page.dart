import 'package:flutter/material.dart';

import '../models/note.dart';
import 'background_settings_page.dart';
import 'export_notes_page.dart';
import 'about_page.dart';

class SettingsPage extends StatelessWidget {
  final List<Note> notes;
  const SettingsPage({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('Background image'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const BackgroundSettingsPage())),
        ),
        ListTile(
          leading: const Icon(Icons.import_export),
          title: const Text('Export Notes'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ExportNotesPage(notes: notes))),
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AboutPage())),
        ),
      ]),
    );
  }
}





