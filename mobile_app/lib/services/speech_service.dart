import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin, testable wrapper around Android's SpeechRecognizer. Audio is handled
/// entirely by the Android recognizer on the phone; no audio is ever sent to
/// the Raspberry Pi by this app.
abstract class SpeechRecognitionService {
  bool get isListening;

  Future<bool> ensureInitialized({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  Future<bool> start({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(String status) onStatus,
    required void Function(String error) onError,
    void Function(double level)? onSoundLevel,
  });

  Future<void> stop();

  Future<void> cancel();
}

class DeviceSpeechRecognitionService implements SpeechRecognitionService {
  DeviceSpeechRecognitionService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _available = false;
  String _localeId = 'en_IN';

  void Function(String status)? _statusHandler;
  void Function(String error)? _errorHandler;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> ensureInitialized({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    _statusHandler = onStatus;
    _errorHandler = onError;

    if (_initialized) return _available;

    try {
      _available = await _speech.initialize(
        onStatus: (status) => _statusHandler?.call(status),
        onError: (SpeechRecognitionError error) =>
            _errorHandler?.call(_friendlySpeechError(error.errorMsg)),
      );
      _initialized = true;

      if (_available) {
        try {
          final locales = await _speech.locales();
          final indianEnglish = locales.where(
            (locale) =>
                locale.localeId.toLowerCase() == 'en_in' ||
                locale.localeId.toLowerCase().startsWith('en-in'),
          );
          if (indianEnglish.isNotEmpty) {
            _localeId = indianEnglish.first.localeId;
          } else {
            final english = locales.where(
              (locale) => locale.localeId.toLowerCase().startsWith('en'),
            );
            if (english.isNotEmpty) _localeId = english.first.localeId;
          }
        } catch (_) {
          _localeId = 'en_IN';
        }
      }
      return _available;
    } catch (error) {
      _initialized = true;
      _available = false;
      if (kDebugMode) {
        debugPrint('Speech initialization failed: $error');
      }
      return false;
    }
  }

  @override
  Future<bool> start({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(String status) onStatus,
    required void Function(String error) onError,
    void Function(double level)? onSoundLevel,
  }) async {
    _statusHandler = onStatus;
    _errorHandler = onError;

    final ready = await ensureInitialized(onStatus: onStatus, onError: onError);
    if (!ready) {
      onError('Speech recognition is not available on this device.');
      return false;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (result.finalResult) {
            onFinal(words);
          } else {
            onPartial(words);
          }
        },
        onSoundLevelChange: onSoundLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 90),
          localeId: _localeId,
        ),
      );
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Speech listen failed: $error');
      }
      onError('Could not start the microphone. Please try again.');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // The recognizer may already be stopped.
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // The recognizer may already be cancelled.
    }
  }

  String _friendlySpeechError(String code) {
    switch (code) {
      case 'error_permission':
        return 'Microphone permission was denied. Enable it in Android settings.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Speech recognition needs a network connection on this phone.';
      case 'error_no_match':
        return 'No speech was recognised. Try speaking a little closer.';
      case 'error_busy':
        return 'The microphone is busy. Please wait a moment.';
      case 'error_speech_timeout':
        return 'I did not hear anything. Tap the microphone to try again.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'English (India) speech is not installed on this device.';
      default:
        return 'Speech recognition stopped unexpectedly. Please try again.';
    }
  }
}
