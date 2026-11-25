import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
  String? _localeId;

  bool get isListening => _isListening;

  static bool get isPlatformSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<bool> initialize({
    required void Function(bool listening) onListeningChanged,
    required void Function(String message) onError,
  }) async {
    if (!isPlatformSupported) {
      onError('Spracheingabe wird auf dieser Plattform nicht unterstützt.');
      return false;
    }
    if (_initialized) return true;

    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          final active = status == 'listening';
          if (_isListening != active) {
            _isListening = active;
            onListeningChanged(active);
          }
        },
        onError: (error) {
          _isListening = false;
          onListeningChanged(false);
          onError(_friendlyError(error.errorMsg));
        },
      );
      if (!ok) {
        onError(
          'Spracherkennung nicht verfügbar. Bitte Mikrofon-Berechtigung prüfen.',
        );
        return false;
      }

      final locales = await _speech.locales();
      final german = locales
          .where((l) => l.localeId.toLowerCase().startsWith('de'))
          .firstOrNull;
      _localeId = german?.localeId ?? 'de_DE';
      _initialized = true;
      return true;
    } catch (e) {
      onError('Spracherkennung konnte nicht gestartet werden: $e');
      return false;
    }
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(bool listening) onListeningChanged,
    required void Function(String message) onError,
  }) async {
    final ready = await initialize(
      onListeningChanged: onListeningChanged,
      onError: onError,
    );
    if (!ready) return false;

    try {
      _isListening = true;
      onListeningChanged(true);
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
        ),
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult && _isListening) {
            _isListening = false;
            onListeningChanged(false);
          }
        },
      );
      return true;
    } catch (e) {
      _isListening = false;
      onListeningChanged(false);
      onError('Aufnahme fehlgeschlagen: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (!_initialized && !_isListening) return;
    _isListening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    if (!_initialized && !_isListening) return;
    _isListening = false;
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  static String _friendlyError(String code) {
    if (code.contains('permission')) {
      return 'Mikrofon-Berechtigung fehlt. Bitte in den App-Einstellungen erlauben.';
    }
    if (code.contains('network')) {
      return 'Netzwerkfehler bei der Spracherkennung.';
    }
    if (code.contains('no_match') || code.contains('speech_timeout')) {
      return 'Nichts verstanden. Bitte nochmal versuchen.';
    }
    return 'Spracherkennung abgebrochen ($code).';
  }
}
