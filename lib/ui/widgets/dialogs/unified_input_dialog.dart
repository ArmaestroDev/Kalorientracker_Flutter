import 'package:flutter/material.dart';

import '../../../logic/voice_input_service.dart';
import '../../theme/tokens.dart';
import '../app_text_field.dart';
import '../kit/kit.dart';

class UnifiedInputDialog extends StatefulWidget {
  final void Function(String name, String description) onSubmit;
  final bool initialVoiceMode;
  final String? missingApiKeyMessage;
  final String initialName;
  final String initialDescription;
  final VoidCallback? onClear;
  final void Function(String name, String description)? onDraftChanged;

  const UnifiedInputDialog({
    super.key,
    required this.onSubmit,
    this.initialVoiceMode = false,
    this.missingApiKeyMessage,
    this.initialName = '',
    this.initialDescription = '',
    this.onClear,
    this.onDraftChanged,
  });

  @override
  State<UnifiedInputDialog> createState() => _UnifiedInputDialogState();
}

class _UnifiedInputDialogState extends State<UnifiedInputDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _voiceService = VoiceInputService();
  bool _isListening = false;
  bool _submitted = false;
  String? _nameError;
  String _voiceBaseText = '';

  bool get _hasInput =>
      _nameController.text.isNotEmpty ||
      _descriptionController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _descriptionController.text = widget.initialDescription;
    _nameController.addListener(_refreshActions);
    _descriptionController.addListener(_refreshActions);
    if (widget.initialVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleVoice();
      });
    }
  }

  void _refreshActions() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (!_submitted) {
      widget.onDraftChanged?.call(
        _nameController.text,
        _descriptionController.text,
      );
    }
    _voiceService.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clear() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() => _nameError = null);
    widget.onClear?.call();
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voiceService.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _voiceBaseText = _nameController.text.trim();
    await _voiceService.startListening(
      onListeningChanged: (active) {
        if (mounted) setState(() => _isListening = active);
      },
      onResult: (words, _) {
        if (!mounted || words.trim().isEmpty) return;
        final combined = _voiceBaseText.isEmpty
            ? words
            : '$_voiceBaseText $words';
        _nameController.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
        if (_nameError != null) setState(() => _nameError = null);
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _isListening = false);
        AppFeedback.error(context, msg);
      },
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Bitte gib etwas ein');
      return;
    }
    if (widget.missingApiKeyMessage != null) {
      AppFeedback.error(context, widget.missingApiKeyMessage!);
      return;
    }
    if (_isListening) _voiceService.stop();
    _submitted = true;
    widget.onSubmit(name, _descriptionController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
              'Beschreibe eine oder mehrere Mahlzeiten oder Aktivitäten per Text '
              'oder Sprache – die KI legt für jede einen eigenen Eintrag an.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _nameController,
              label: 'Mahlzeit oder Aktivität',
              hint: 'z. B. 200 g Reis, 150 g Hähnchen und 30 min Joggen',
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: 6,
              minLines: 1,
              autofocus: !widget.initialVoiceMode,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            if (VoiceInputService.isPlatformSupported) ...[
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Spracheingabe',
                    onPressed: _toggleVoice,
                    icon: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _isListening ? 'Ich höre zu…' : 'Spracheingabe',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isListening) ...[
                const SizedBox(height: Space.xs),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
            const SizedBox(height: Space.md),
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
        if (_hasInput)
          TextButton(onPressed: _clear, child: const Text('Leeren')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Hinzufügen')),
      ],
    );
  }
}
