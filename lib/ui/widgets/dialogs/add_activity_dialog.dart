import 'package:flutter/material.dart';

class AddActivityDialog extends StatefulWidget {
  final Function(String name) onAddActivity;

  const AddActivityDialog({super.key, required this.onAddActivity});

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aktivität hinzufügen'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Aktivität',
          hintText: 'z.B. 30 Minuten Joggen',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              widget.onAddActivity(_nameController.text);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
