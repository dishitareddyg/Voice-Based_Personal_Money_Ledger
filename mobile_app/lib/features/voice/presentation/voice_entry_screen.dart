import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../providers/settings_provider.dart';
import '../../../router/routes.dart';
import '../nlp/nlp_vocabulary.dart';
import '../nlp/voice_command.dart';
import '../nlp/voice_entry_controller.dart';
import '../nlp/voice_query_router.dart';
import 'widgets/mic_button.dart';

class VoiceEntryScreen extends ConsumerStatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  ConsumerState<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen> {
  final _transcriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceEntryControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    final parsed =
        await ref.read(voiceEntryControllerProvider.notifier).confirmTranscript();
    if (!mounted || parsed == null) return;

    final query = resolveVoiceQuery(parsed.intent);
    if (query != null) {
      ref.read(voiceEntryControllerProvider.notifier).resetAfterSubmit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(query.message)),
      );
      context.go(query.route);
      return;
    }

    if (parsed.canSubmit) {
      context.push(Routes.review, extra: parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceEntryControllerProvider);
    final notifier = ref.read(voiceEntryControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);

    ref.listen<VoiceEntryState>(voiceEntryControllerProvider, (previous, next) {
      if (next.phase == VoicePhase.finalTranscript &&
          next.transcript != _transcriptController.text) {
        _transcriptController.text = next.transcript;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice entry'),
        actions: [
          IconButton(
            tooltip: 'How it works',
            onPressed: () => _showHowItWorks(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 150),
            children: [
              if (settings.showVoiceExamples) ...[
                Text(
                  'Try saying',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: NlpVocabulary.examplePhrases.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final phrase = NlpVocabulary.examplePhrases[index];
                      return ActionChip(
                        label: Text(phrase),
                        onPressed: state.isListening
                            ? null
                            : () {
                                _transcriptController.text = phrase;
                                notifier.editTranscript(phrase);
                              },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Center(
                child: Column(
                  children: [
                    MicButton(
                      listening: state.isListening,
                      soundLevel: state.soundLevel,
                      enabled: !state.isBusy,
                      onTap: () {
                        if (state.isListening) {
                          notifier.stopListening();
                        } else {
                          notifier.startListening();
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    _StatusLabel(state: state),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _TranscriptCard(
                state: state,
                controller: _transcriptController,
                onChanged: notifier.editTranscript,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                InfoBanner(
                  title: 'Voice issue',
                  message: state.errorMessage!,
                  icon: Icons.mic_off_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
              if (state.parsedCommand != null &&
                  !state.parsedCommand!.canSubmit) ...[
                const SizedBox(height: 14),
                _MissingInformation(command: state.parsedCommand!),
              ],
              if (state.parsedCommand != null &&
                  state.parsedCommand!.canSubmit &&
                  state.parsedCommand!.needsReview) ...[
                const SizedBox(height: 14),
                InfoBanner(
                  title: 'Please review',
                  message: state.parsedCommand!.warnings.join(' '),
                  icon: Icons.fact_check_outlined,
                  color: const Color(0xFFB26A00),
                ),
              ],
              const SizedBox(height: 18),
              _ActionRow(
                state: state,
                controller: _transcriptController,
                onClear: () {
                  _transcriptController.clear();
                  notifier.clear();
                },
                onRetry: notifier.retry,
                onTypeInstead: () {
                  notifier.startTyping();
                  _transcriptController.text = state.transcript;
                },
                onCancel: () {
                  _transcriptController.clear();
                  notifier.cancel();
                },
                onConfirm: _confirm,
              ),
              const SizedBox(height: 18),
              InfoBanner(
                icon: Icons.lock_outline_rounded,
                message:
                    'Audio never leaves this phone. Only the text you confirm is interpreted and sent to your Raspberry Pi.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How voice entry works'),
        content: const Text(
          '1. Tap the microphone and speak naturally.\n'
          '2. Watch your words appear live as they are recognised.\n'
          '3. Edit the transcript if something is wrong.\n'
          '4. Press Confirm only when the sentence is correct.\n'
          '5. Review the structured command, then send it to your Raspberry Pi.\n\n'
          'Nothing is sent to the server until you confirm.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.state});

  final VoiceEntryState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (state.phase) {
      VoicePhase.idle => (
          'Tap the microphone and speak',
          scheme.onSurfaceVariant
        ),
      VoicePhase.initializing => ('Preparing microphone...', scheme.onSurfaceVariant),
      VoicePhase.listening => ('Listening... tap to stop', scheme.primary),
      VoicePhase.finalTranscript => ('Your words - edit if needed', scheme.primary),
      VoicePhase.processing => ('Understanding your sentence...', scheme.tertiary),
      VoicePhase.error => ('Microphone needs attention', scheme.error),
    };

    return Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.state,
    required this.controller,
    required this.onChanged,
  });

  final VoiceEntryState state;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editable = state.phase == VoicePhase.finalTranscript;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subtitles_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Transcription',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              if (state.phase == VoicePhase.processing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.phase == VoicePhase.idle && !state.hasTranscript)
            Text(
              'When you speak, your words will appear here live. '
              'You can also tap "Type instead" to enter text manually.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            )
          else if (editable)
            TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                hintText: 'Edit your sentence here...',
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
            )
          else
            Text(
              state.displayText.isEmpty
                  ? 'Listening...'
                  : state.displayText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: state.displayText.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
            ),
        ],
      ),
    );
  }
}

class _MissingInformation extends StatelessWidget {
  const _MissingInformation({required this.command});

  final ParsedVoiceCommand command;

  @override
  Widget build(BuildContext context) {
    final missing = command.missingFields
        .map((field) => field.label)
        .where((label) => label.isNotEmpty)
        .join(', ');
    return InfoBanner(
      title: 'I need a little more information',
      message: 'Please provide $missing. Edit your sentence above and confirm again.',
      icon: Icons.edit_note_rounded,
      color: const Color(0xFFB26A00),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.controller,
    required this.onClear,
    required this.onRetry,
    required this.onTypeInstead,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoiceEntryState state;
  final TextEditingController controller;
  final VoidCallback onClear;
  final VoidCallback onRetry;
  final VoidCallback onTypeInstead;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final listening = state.isListening;
    final busy = state.isBusy;
    final canConfirm = state.hasTranscript && !busy;

    return Column(
      children: [
        if (canConfirm)
          AppButton(
            label: 'Confirm transcription',
            icon: Icons.check_rounded,
            loading: state.phase == VoicePhase.processing,
            onPressed: onConfirm,
          ),
        if (canConfirm) const SizedBox(height: 10),
        Row(
          children: [
            if (listening)
              Expanded(
                child: AppButton(
                  label: 'Stop',
                  icon: Icons.stop_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: onCancel,
                ),
              )
            else
              Expanded(
                child: AppButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: busy ? null : onRetry,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Type instead',
                icon: Icons.keyboard_rounded,
                variant: AppButtonVariant.outlined,
                onPressed: listening || busy ? null : onTypeInstead,
              ),
            ),
          ],
        ),
        if (state.hasTranscript && !busy) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Clear',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.text,
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.text,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
