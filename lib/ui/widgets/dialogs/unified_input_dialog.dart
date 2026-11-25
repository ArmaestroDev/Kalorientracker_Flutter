import 'package:flutter/material.dart';
import '../../../logic/voice_input_service.dart';
import '../app_text_field.dart';

/// Unified dialog for entering meals or activities via text or voice.
/// AI will classify whether the input is a food or activity.
class UnifiedInputDialog extends StatefulWidget {
  final void Function(String name, String description) onSubmit;
  final bool initialVoiceMode;
  final String? missingApiKeyMessage;

  const UnifiedInputDialog({
    super.key,
    required this.onSubmit,
    this.initialVoiceMode = false,
    this.missingApiKeyMessage,
  });

  @override
  State<UnifiedInputDialog> createState() => _UnifiedInputDialogState();
}

class _UnifiedInputDialogState extends State<UnifiedInputDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _voiceService = VoiceInputService();
  bool _isListening = false;
  String? _voiceError;
  String _voiceBaseText = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleVoice();
      });
    }
  }

  @override
  void dispose() {
    _voiceService.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voiceService.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() => _voiceError = null);
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
      },
      onError: (msg) {
        if (mounted) setState(() => _voiceError = msg);
      },
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (widget.missingApiKeyMessage != null) {
      setState(() => _voiceError = widget.missingApiKeyMessage);
      return;
    }
    if (_isListening) _voiceService.stop();
    widget.onSubmit(name, _descriptionController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              'Beschreibe deine Mahlzeit oder Aktivität per Text oder Sprache – die KI erkennt und berechnet alles automatisch.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (VoiceInputService.isPlatformSupported) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _toggleVoice,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isListening
                              ? 'Ich höre zu … Tippen zum Stoppen'
                              : 'Sprachmodus starten (z. B. „250 g Skyr mit Banane“)',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isListening
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      if (_isListening)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (_voiceError != null) ...[
              const SizedBox(height: 8),
              Text(
                _voiceError!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameController,
              label: 'Mahlzeit oder Aktivität',
              hint: 'z. B. 250 g Skyr oder 60 min BJJ',
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              autofocus: !widget.initialVoiceMode,
              onSubmitted: (_) => _submit(),
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
