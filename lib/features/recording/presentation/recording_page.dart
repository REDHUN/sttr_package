import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../playback/data/share_service.dart';
import '../domain/recording_state.dart';
import 'recording_view_model.dart';
import '../../../shared/widgets/level_meter.dart';
import '../../../shared/widgets/recording_status_chip.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/transcript_panel.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final ScrollController _transcriptController = ScrollController();

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecordingViewModel>();
    final theme = Theme.of(context);

    return PopScope<void>(
      canPop: !viewModel.isActiveSession,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !viewModel.isActiveSession) return;
        confirmDiscardSession(context).then((confirmed) {
          if (confirmed && context.mounted) {
            viewModel.discard();
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Text('VoiceNote'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: RecordingStatusChip(state: viewModel.state),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 720
                  ? 32.0
                  : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  14,
                  horizontalPadding,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capture the thought while it is fresh.',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Record audio and see the platform recognizer’s live transcript in one calm workspace.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (viewModel.recoveredDraft != null &&
                            !viewModel.isActiveSession)
                          _RecoveredDraftCard(viewModel: viewModel),
                        if (viewModel.recoveredDraft != null &&
                            !viewModel.isActiveSession)
                          const SizedBox(height: 14),
                        _RecordingControls(viewModel: viewModel),
                        const SizedBox(height: 14),
                        Selector<RecordingViewModel, _TranscriptViewData>(
                          selector: (_, model) => _TranscriptViewData(
                            text: model.transcript,
                            isFinal: model.transcriptIsFinal,
                          ),
                          builder: (context, data, _) {
                            _scrollTranscriptToBottom();
                            return TranscriptPanel(
                              transcript: data.text,
                              isFinal: data.isFinal,
                              controller: _transcriptController,
                              onCopy: data.text.trim().isEmpty
                                  ? null
                                  : () => _copyTranscript(context, data.text),
                              onShare: data.text.trim().isEmpty
                                  ? null
                                  : () => _shareTranscript(context, data.text),
                            );
                          },
                        ),
                        if (viewModel.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          _ErrorCard(viewModel: viewModel),
                        ],
                        if (viewModel.lifecycleMessage != null) ...[
                          const SizedBox(height: 14),
                          _InfoCard(message: viewModel.lifecycleMessage!),
                        ],
                        if (viewModel.lastSavedRecording != null &&
                            viewModel.state == RecordingState.completed) ...[
                          const SizedBox(height: 14),
                          _SavedCard(
                            title: viewModel.lastSavedRecording!.title,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Recognition note',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'VoiceNote uses the platform speech recognizer. Availability, language support, network use, and session limits depend on the device provider.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _scrollTranscriptToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_transcriptController.hasClients) return;
      final max = _transcriptController.position.maxScrollExtent;
      if (max <= 0) return;
      _transcriptController.animateTo(
        max,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _copyTranscript(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied to clipboard.')),
    );
  }

  Future<void> _shareTranscript(BuildContext context, String text) async {
    try {
      await context.read<ShareService>().shareText(
        title: 'VoiceNote transcript',
        text: text,
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sharing failed: $error')));
    }
  }
}

Future<bool> confirmDiscardSession(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard this session?'),
      content: const Text(
        'The current audio and live transcript will be discarded. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep recording'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _TranscriptViewData {
  const _TranscriptViewData({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;

  @override
  bool operator ==(Object other) {
    return other is _TranscriptViewData &&
        other.text == text &&
        other.isFinal == isFinal;
  }

  @override
  int get hashCode => Object.hash(text, isFinal);
}

class _RecordingControls extends StatelessWidget {
  const _RecordingControls({required this.viewModel});

  final RecordingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final theme = Theme.of(context);
    final isBusy =
        viewModel.isCommandInFlight ||
        state == RecordingState.requestingPermission ||
        state == RecordingState.starting ||
        state == RecordingState.stopping ||
        state == RecordingState.saving;
    final locale = viewModel.locales.where(
      (item) => item.id == viewModel.selectedLocaleId,
    );

    return SectionCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recording setup',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Selector<RecordingViewModel, Duration>(
                selector: (_, model) => model.activeDuration,
                builder: (context, duration, _) => Text(
                  formatDuration(duration),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: viewModel.selectedLocaleId,
            decoration: const InputDecoration(
              labelText: 'Recognition language',
              prefixIcon: Icon(Icons.language_rounded),
            ),
            items: viewModel.locales
                .map(
                  (locale) => DropdownMenuItem<String>(
                    value: locale.id,
                    child: Text('${locale.name} · ${locale.id}'),
                  ),
                )
                .toList(growable: false),
            onChanged: viewModel.canChangeLocale
                ? (value) {
                    if (value != null) viewModel.setLocale(value);
                  }
                : null,
          ),
          if (viewModel.locales.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No locales were reported by the recognizer yet. Open Settings or retry after granting permission.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Level meter',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'best-effort mic level',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Selector<RecordingViewModel, _MeterData>(
            selector: (_, model) => _MeterData(
              amplitude: model.amplitude,
              samples: model.amplitudeSamples,
              active: model.state == RecordingState.recording,
            ),
            builder: (context, data, _) => LevelMeter(
              amplitude: data.amplitude,
              samples: data.samples,
              isActive: data.active,
            ),
          ),
          const SizedBox(height: 6),
          if (locale.isNotEmpty)
            Text(
              'Selected: ${locale.first.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 20),
          if (state == RecordingState.recording ||
              state == RecordingState.paused)
            _ActiveControls(viewModel: viewModel, isBusy: isBusy)
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: viewModel.canStart && !isBusy
                    ? () => viewModel.start()
                    : null,
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  state == RecordingState.error
                      ? 'Try again'
                      : 'Start recording',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
              ),
            ),
          if (isBusy &&
              state != RecordingState.recording &&
              state != RecordingState.paused) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 4),
          ],
        ],
      ),
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({required this.viewModel, required this.isBusy});

  final RecordingViewModel viewModel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final paused = viewModel.state == RecordingState.paused;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : paused
                    ? () => viewModel.resume()
                    : () => viewModel.pause(),
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(paused ? 'Resume' : 'Pause'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isBusy ? null : () => viewModel.stop(),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop & save'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.recording,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: isBusy
              ? null
              : () async {
                  final confirmed = await confirmDiscardSession(context);
                  if (confirmed && context.mounted) {
                    await context.read<RecordingViewModel>().discard();
                  }
                },
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Discard session'),
        ),
      ],
    );
  }
}

class _MeterData {
  const _MeterData({
    required this.amplitude,
    required this.samples,
    required this.active,
  });

  final double amplitude;
  final List<double> samples;
  final bool active;

  @override
  bool operator ==(Object other) {
    return other is _MeterData &&
        other.amplitude == amplitude &&
        other.active == active &&
        listEquals(other.samples, samples);
  }

  @override
  int get hashCode => Object.hash(amplitude, active, Object.hashAll(samples));
}

class _RecoveredDraftCard extends StatelessWidget {
  const _RecoveredDraftCard({required this.viewModel});

  final RecordingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.restore_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'A transcript draft from ${formatDateTime(viewModel.recoveredDraft!.createdAt)} is available. Audio recovery is not promised.',
              ),
            ),
            TextButton(
              onPressed: viewModel.recoverDraft,
              child: const Text('Recover'),
            ),
            IconButton(
              onPressed: viewModel.dismissRecoveredDraft,
              tooltip: 'Dismiss draft',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.viewModel});

  final RecordingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(viewModel.errorMessage!)),
            IconButton(
              onPressed: viewModel.clearError,
              tooltip: 'Dismiss error',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text('$title saved to your library.')),
          ],
        ),
      ),
    );
  }
}
