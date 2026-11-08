import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../playback/data/share_service.dart';
import '../../playback/presentation/playback_view_model.dart';
import '../../recording/presentation/recording_view_model.dart';
import '../domain/recording.dart';
import 'recordings_view_model.dart';
import '../../../shared/widgets/section_card.dart';

class RecordingDetailPage extends StatefulWidget {
  const RecordingDetailPage({super.key, required this.recording});

  final Recording recording;

  @override
  State<RecordingDetailPage> createState() => _RecordingDetailPageState();
}

class _RecordingDetailPageState extends State<RecordingDetailPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _transcriptController;
  bool _isSaving = false;
  bool _didLoadPlayer = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recording.title);
    _transcriptController = TextEditingController(
      text: widget.recording.transcript,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadPlayer) return;
    _didLoadPlayer = true;
    final playback = context.read<PlaybackViewModel>();
    playback.setCanPlay(
      () => !context.read<RecordingViewModel>().isActiveSession,
    );
    playback.load(widget.recording);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording details'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : () => _save(context),
            tooltip: 'Save changes',
            icon: const Icon(Icons.check_rounded),
          ),
          IconButton(
            onPressed: () => _shareAudio(context),
            tooltip: 'Share audio',
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            onPressed: _isSaving ? null : () => _delete(context),
            tooltip: 'Delete recording',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Edit and replay your note.',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDateTime(widget.recording.createdAt)} · ${formatDuration(widget.recording.duration)} · ${formatFileSize(widget.recording.fileSizeBytes)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    maxLength: 80,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.recording.localeName} · ${widget.recording.localeId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Audio playback',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (playback.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Slider(
                    value: playback.duration.inMilliseconds == 0
                        ? 0
                        : playback.position.inMilliseconds
                              .clamp(0, playback.duration.inMilliseconds)
                              .toDouble(),
                    max: playback.duration.inMilliseconds == 0
                        ? 1
                        : playback.duration.inMilliseconds.toDouble(),
                    onChanged: playback.duration.inMilliseconds == 0
                        ? null
                        : (value) => playback.seek(
                            Duration(milliseconds: value.round()),
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(playback.position)),
                      Text(formatDuration(playback.duration)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: playback.isLoading
                            ? null
                            : playback.isPlaying
                            ? playback.pause
                            : playback.play,
                        tooltip: playback.isPlaying
                            ? 'Pause audio'
                            : 'Play audio',
                        icon: Icon(
                          playback.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: playback.isLoading ? null : playback.stop,
                        tooltip: 'Stop audio',
                        icon: const Icon(Icons.stop_rounded),
                      ),
                    ],
                  ),
                  if (playback.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      playback.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transcript',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _copyTranscript,
                        tooltip: 'Copy transcript',
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      IconButton(
                        onPressed: () => _shareTranscript(context),
                        tooltip: 'Share transcript',
                        icon: const Icon(Icons.ios_share_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _transcriptController,
                    minLines: 8,
                    maxLines: 18,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Transcript text',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _save(context),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save changes'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this recording a title first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = widget.recording.copyWith(
        title: title,
        transcript: _transcriptController.text.trim(),
      );
      await context.read<RecordingsViewModel>().update(updated);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recording updated.')));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save changes: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text(
          'The saved audio file and transcript will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final playback = context.read<PlaybackViewModel>();
      final recordings = context.read<RecordingsViewModel>();
      await playback.stop();
      if (!context.mounted) return;
      await recordings.delete(widget.recording);
      if (context.mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete recording: $error')),
      );
    }
  }

  Future<void> _copyTranscript() async {
    await Clipboard.setData(
      ClipboardData(text: _transcriptController.text.trim()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied to clipboard.')),
    );
  }

  Future<void> _shareTranscript(BuildContext context) async {
    try {
      await context.read<ShareService>().shareText(
        title: _titleController.text.trim().isEmpty
            ? 'VoiceNote transcript'
            : _titleController.text.trim(),
        text: _transcriptController.text.trim(),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share transcript: $error')),
      );
    }
  }

  Future<void> _shareAudio(BuildContext context) async {
    try {
      await context.read<ShareService>().shareAudio(
        title: _titleController.text.trim().isEmpty
            ? 'VoiceNote audio'
            : _titleController.text.trim(),
        path: widget.recording.audioPath,
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not share audio: $error')));
    }
  }
}
