import 'package:flutter/material.dart';
import '../app_text_field.dart';

/// Unified dialog for entering meals or activities via text
/// AI will classify whether the input is a food or activity
class UnifiedInputDialog extends StatefulWidget {
  final void Function(String name, String description) onSubmit;

  const UnifiedInputDialog({super.key, required this.onSubmit});

  @override
  State<UnifiedInputDialog> createState() => _UnifiedInputDialogState();
}

class _UnifiedInputDialogState extends State<UnifiedInputDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onSubmit(name, _descriptionController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eintrag hinzufügen'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gib eine Mahlzeit oder Aktivität ein – die KI erkennt automatisch, was es ist. Mit Menge wird es genauer.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameController,
              label: 'Mahlzeit oder Aktivität',
              hint: 'z. B. 250 g Skyr oder 60 min BJJ',
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descriptionController,
              label: 'Beschreibung (optional)',
              hint: 'z. B. aus der Mensa, mit Soße',
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ListenableBuilder(
          listenable: _nameController,
          builder: (context, _) => FilledButton(
            onPressed: _nameController.text.trim().isEmpty ? null : _submit,
            child: const Text('Hinzufügen'),
          ),
        ),
      ],
    );
  }
}
