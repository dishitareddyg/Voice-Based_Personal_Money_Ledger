import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/features/voice/nlp/voice_command.dart';
import 'package:voice_ledger/features/voice/nlp/voice_entry_controller.dart';
import 'package:voice_ledger/providers/infrastructure_providers.dart';
import 'package:voice_ledger/providers/ledger_providers.dart';
import 'package:voice_ledger/services/speech_service.dart';

class _ControllableSpeech implements SpeechRecognitionService {
  bool _listening = false;
  void Function(String partial)? _onPartial;
  void Function(String finalText)? _onFinal;
  void Function(String status)? _onStatus;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> ensureInitialized({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async =>
      true;

  @override
  Future<bool> start({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(String status) onStatus,
    required void Function(String error) onError,
    void Function(double level)? onSoundLevel,
  }) async {
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onStatus = onStatus;
    _listening = true;
    onStatus('listening');
    return true;
  }

  void emitPartial(String text) => _onPartial?.call(text);

  void emitFinal(String text) {
    _listening = false;
    _onFinal?.call(text);
  }

  @override
  Future<void> stop() async {
    _listening = false;
    _onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }
}

void main() {
  test('partial, final, edit and confirmation follow the voice contract',
      () async {
    final speech = _ControllableSpeech();
    final container = ProviderContainer(
      overrides: [
        speechRecognitionServiceProvider.overrideWithValue(speech),
        personsProvider.overrideWith((ref) => const []),
        categoriesProvider.overrideWith((ref) => const []),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceEntryControllerProvider.notifier);
    await controller.startListening();

    speech.emitPartial('I spent two thousand');
    await Future<void>.delayed(Duration.zero);
    var state = container.read(voiceEntryControllerProvider);
    expect(state.phase, VoicePhase.listening);
    expect(state.partialText, 'I spent two thousand');
    expect(state.parsedCommand, isNull);

    speech.emitFinal('I spent 2000 rupees on groceries');
    await Future<void>.delayed(Duration.zero);
    state = container.read(voiceEntryControllerProvider);
    expect(state.phase, VoicePhase.finalTranscript);
    expect(state.transcript, 'I spent 2000 rupees on groceries');
    expect(state.parsedCommand, isNull);

    controller.editTranscript('I spent 2000 rupees on groceries yesterday');
    await Future<void>.delayed(Duration.zero);
    state = container.read(voiceEntryControllerProvider);
    expect(
      state.transcript,
      'I spent 2000 rupees on groceries yesterday',
    );
    expect(state.parsedCommand, isNull);

    final parsed = await controller.confirmTranscript();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = container.read(voiceEntryControllerProvider);

    expect(parsed, isNotNull);
    expect(parsed!.intent, VoiceIntent.createExpense);
    expect(parsed.amount, 2000);
    expect(parsed.currency, 'INR');
    expect(parsed.canSubmit, isTrue);
    expect(state.parsedCommand, isNotNull);
    expect(state.phase, VoicePhase.finalTranscript);
  });

  test('confirmation is blocked when the transcript is empty', () async {
    final container = ProviderContainer(
      overrides: [
        speechRecognitionServiceProvider.overrideWithValue(
          _ControllableSpeech(),
        ),
        personsProvider.overrideWith((ref) => const []),
        categoriesProvider.overrideWith((ref) => const []),
      ],
    );
    addTearDown(container.dispose);

    final parsed =
        await container.read(voiceEntryControllerProvider.notifier)
            .confirmTranscript();
    final state = container.read(voiceEntryControllerProvider);

    expect(parsed, isNull);
    expect(state.parsedCommand, isNull);
    expect(state.errorMessage, contains('before confirming'));
  });
}
