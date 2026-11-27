import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class AddEntryDialog extends StatelessWidget {
  final VoidCallback onPhotoSelected;
  final VoidCallback onManualSelected;
  final VoidCallback onHistorySelected;

  const AddEntryDialog({
    super.key,
    required this.onPhotoSelected,
    required this.onManualSelected,
    required this.onHistorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eintrag hinzufügen'),
      contentPadding: const EdgeInsets.fromLTRB(Space.sm, Space.lg, Space.sm, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EntryChoiceTile(
            icon: Icons.edit_note_rounded,
            title: 'Beschreiben',
            subtitle: 'Text oder Sprache – KI schätzt die Werte',
            onTap: () {
              Navigator.of(context).pop();
              onManualSelected();
            },
          ),
          _EntryChoiceTile(
            icon: Icons.photo_camera_outlined,
            title: 'Foto',
            subtitle: 'Mahlzeit fotografieren',
            onTap: () {
              Navigator.of(context).pop();
              onPhotoSelected();
            },
          ),
          _EntryChoiceTile(
            icon: Icons.history_rounded,
            title: 'Zuletzt gegessen',
            subtitle: 'Aus deinem Verlauf',
            onTap: () {
              Navigator.of(context).pop();
              onHistorySelected();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

class _EntryChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: scheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
