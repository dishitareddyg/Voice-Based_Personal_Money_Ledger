import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/infrastructure_providers.dart';
import '../../../providers/ledger_providers.dart';
import '../../../services/speech_service.dart';
import 'voice_command.dart';

enum VoicePhase {
  idle,
  initializing,
  listening,
  finalTranscript,
  processing,
  error,
}

class VoiceEntryState {
  const VoiceEntryState({
    this.phase = VoicePhase.idle,
    this.partialText = '',
    this.transcript = '',
    this.errorMessage,
    this.isAvailable,
    this.soundLevel = 0,
    this.parsedCommand,
    this.manualMode = false,
  });

  final VoicePhase phase;
  final String partialText;
  final String transcript;
  final String? errorMessage;
  final bool? isAvailable;
  final double soundLevel;
  final ParsedVoiceCommand? parsedCommand;
  final bool manualMode;

  bool get isListening => phase == VoicePhase.listening;
  bool get isBusy =>
      phase == VoicePhase.processing || phase == VoicePhase.initializing;
  bool get hasTranscript => transcript.trim().isNotEmpty;
  String get displayText => transcript.isNotEmpty ? transcript : partialText;

  VoiceEntryState copyWith({
    VoicePhase? phase,
    String? partialText,
    String? transcript,
    String? errorMessage,
    bool clearError = false,
    bool? isAvailable,
    double? soundLevel,
    ParsedVoiceCommand? parsedCommand,
    bool clearParsed = false,
    bool? manualMode,
  }) {
    return VoiceEntryState(
      phase: phase ?? this.phase,
      partialText: partialText ?? this.partialText,
      transcript: transcript ?? this.transcript,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAvailable: isAvailable ?? this.isAvailable,
      soundLevel: soundLevel ?? this.soundLevel,
      parsedCommand:
          clearParsed ? null : (parsedCommand ?? this.parsedCommand),
      manualMode: manualMode ?? this.manualMode,
    );
  }
}

class VoiceEntryController extends Notifier<VoiceEntryState> {
  late final SpeechRecognitionService _speech;
  late final _parser = ref.read(voiceNlpParserProvider);

  String _latestSpoken = '';
  bool _userStopped = false;
  bool _finalized = false;
  Timer? _finalizeTimer;

  @override
  VoiceEntryState build() {
    _speech = ref.watch(speechRecognitionServiceProvider);
    ref.onDispose(() {
      _finalizeTimer?.cancel();
      unawaited(_speech.cancel());
    });
    return const VoiceEntryState();
  }

  Future<void> initialize() async {
    if (state.isAvailable != null) return;
    final available = await _speech.ensureInitialized(
      onStatus: _onStatus,
      onError: _onSpeechError,
    );
    state = state.copyWith(isAvailable: available, clearError: true);
    if (!available) {
      state = state.copyWith(
        errorMessage:
            'Speech recognition is unavailable. Use "Type instead" to enter text.',
      );
    }
  }

  Future<void> startListening() async {
    _finalizeTimer?.cancel();
    _latestSpoken = '';
    _userStopped = false;
    _finalized = false;
    state = state.copyWith(
      phase: VoicePhase.initializing,
      partialText: '',
      transcript: '',
      clearError: true,
      clearParsed: true,
      manualMode: false,
      soundLevel: 0,
    );

    final started = await _speech.start(
      onPartial: _onPartial,
      onFinal: _onFinal,
      onStatus: _onStatus,
      onError: _onSpeechError,
      onSoundLevel: (level) {
        if (!state.isListening) return;
        state = state.copyWith(soundLevel: level.clamp(-2.0, 10.0));
      },
    );

    if (!started) {
      state = state.copyWith(
        phase: VoicePhase.error,
        isAvailable: false,
        errorMessage:
            'The microphone could not start. Check permission or type the entry instead.',
      );
      return;
    }

    if (state.phase == VoicePhase.initializing) {
      state = state.copyWith(phase: VoicePhase.listening);
    }
  }

  Future<void> stopListening() async {
    _userStopped = true;
    await _speech.stop();
    _finalizeTimer?.cancel();
    _finalizeTimer = Timer(const Duration(milliseconds: 900), () {
      if (state.phase != VoicePhase.listening) return;
      if (_latestSpoken.trim().isNotEmpty) {
        _finish(_latestSpoken);
      } else {
        state = state.copyWith(
          phase: VoicePhase.error,
          errorMessage: 'I did not hear anything. Tap retry and speak again.',
        );
      }
    });
  }

  void startTyping() {
    _finalizeTimer?.cancel();
    unawaited(_speech.cancel());
    state = state.copyWith(
      phase: VoicePhase.finalTranscript,
      manualMode: true,
      clearError: true,
      clearParsed: true,
    );
  }

  void editTranscript(String text) {
    state = state.copyWith(
      phase: VoicePhase.finalTranscript,
      transcript: text,
      clearError: true,
      clearParsed: true,
      manualMode: true,
    );
  }

  void clear() {
    _finalizeTimer?.cancel();
    unawaited(_speech.cancel());
    _latestSpoken = '';
    _finalized = false;
    state = VoiceEntryState(
      isAvailable: state.isAvailable,
      soundLevel: 0,
    );
  }

  Future<void> retry() async {
    await _speech.cancel();
    await startListening();
  }

  Future<void> cancel() async {
    _finalizeTimer?.cancel();
    await _speech.cancel();
    _latestSpoken = '';
    _finalized = false;
    state = VoiceEntryState(
      isAvailable: state.isAvailable,
      soundLevel: 0,
    );
  }

  void resetAfterSubmit() {
    _finalizeTimer?.cancel();
    _latestSpoken = '';
    _finalized = false;
    state = VoiceEntryState(
      isAvailable: state.isAvailable,
      soundLevel: 0,
    );
  }

  Future<ParsedVoiceCommand?> confirmTranscript() async {
    final text = state.transcript.trim().isEmpty
        ? state.partialText.trim()
        : state.transcript.trim();

    if (text.isEmpty) {
      state = state.copyWith(
        phase: VoicePhase.finalTranscript,
        errorMessage: 'Add or speak a sentence before confirming.',
      );
      return null;
    }

    _finalizeTimer?.cancel();
    await _speech.cancel();
    state = state.copyWith(
      phase: VoicePhase.processing,
      transcript: text,
      clearError: true,
      clearParsed: true,
    );

    final persons = ref.read(personsProvider).valueOrNull ?? const [];
    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];

    final parsed = _parser.parse(
      text,
      knownPersons: persons,
      knownCategories: categories,
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));

    state = state.copyWith(
      phase: VoicePhase.finalTranscript,
      transcript: text,
      parsedCommand: parsed,
      clearError: true,
    );
    return parsed;
  }

  void _onPartial(String text) {
    if (state.phase != VoicePhase.listening &&
        state.phase != VoicePhase.initializing) {
      return;
    }
    _latestSpoken = text;
    state = state.copyWith(
      phase: VoicePhase.listening,
      partialText: text,
      transcript: '',
      clearError: true,
    );
  }

  void _onFinal(String text) {
    _finalizeTimer?.cancel();
    final finalText = text.trim().isEmpty ? _latestSpoken.trim() : text.trim();
    if (_finalized) return;
    if (finalText.isEmpty) {
      state = state.copyWith(
        phase: VoicePhase.error,
        errorMessage: 'No speech was recognised. Please try again.',
      );
      return;
    }
    _latestSpoken = finalText;
    _finish(finalText);
  }

  void _finish(String text) {
    _finalized = true;
    _finalizeTimer?.cancel();
    state = state.copyWith(
      phase: VoicePhase.finalTranscript,
      transcript: text,
      partialText: text,
      clearError: true,
      clearParsed: true,
      manualMode: false,
    );
  }

  void _onStatus(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'listening') {
      if (state.phase == VoicePhase.initializing ||
          state.phase == VoicePhase.listening) {
        state = state.copyWith(phase: VoicePhase.listening);
      }
      return;
    }

    if (normalized == 'done' || normalized == 'notlistening') {
      if (state.phase != VoicePhase.listening) return;
      if (_latestSpoken.trim().isNotEmpty) {
        _finish(_latestSpoken);
      } else if (_userStopped) {
        state = state.copyWith(
          phase: VoicePhase.error,
          errorMessage: 'I did not hear anything. Tap retry and speak again.',
        );
      }
    }
  }

  void _onSpeechError(String message) {
    _finalizeTimer?.cancel();
    if (state.isListening && _latestSpoken.trim().isNotEmpty) {
      _finish(_latestSpoken);
      return;
    }
    state = state.copyWith(
      phase: VoicePhase.error,
      errorMessage: message,
    );
  }
}

final voiceEntryControllerProvider =
    NotifierProvider<VoiceEntryController, VoiceEntryState>(
  VoiceEntryController.new,
);
