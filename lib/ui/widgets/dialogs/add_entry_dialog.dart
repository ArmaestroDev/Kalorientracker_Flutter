import 'package:flutter/material.dart';

/// Dialog for selecting input type: Photo, History, or Manual text
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Wie möchtest du den Eintrag hinzufügen?'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _InputTypeButton(
                    icon: Icons.camera_alt,
                    label: 'Foto',
                    subtitle: 'Barcode / Bild',
                    onTap: () {
                      Navigator.of(context).pop();
                      onPhotoSelected();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InputTypeButton(
                    icon: Icons.history,
                    label: 'Verlauf',
                    subtitle: 'Datenbank',
                    onTap: () {
                      Navigator.of(context).pop();
                      onHistorySelected();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InputTypeButton(
                    icon: Icons.edit,
                    label: 'Manuell',
                    subtitle: 'Texteingabe',
                    onTap: () {
                      Navigator.of(context).pop();
                      onManualSelected();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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

class _InputTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _InputTypeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
