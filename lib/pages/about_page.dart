import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.about)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppLocalizations.of(context)!.capsule,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Version 0.1.0'),
          const SizedBox(height: 12),
          Text('A minimal Material 3 note app.',
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }
}
