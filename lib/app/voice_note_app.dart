import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../core/storage/audio_file_store.dart';
import '../core/storage/recording_database.dart';
import '../core/storage/transcript_draft_store.dart';
import '../core/theme/app_theme.dart';
import '../features/playback/data/share_service.dart';
import '../features/playback/presentation/playback_view_model.dart';
import '../features/recording/data/speech_capture_service.dart';
import '../features/recording/data/stt_record_capture_service.dart';
import '../features/recording/presentation/recording_view_model.dart';
import '../features/recordings/data/recording_repository.dart';
import '../features/recordings/presentation/recordings_view_model.dart';
import '../features/settings/presentation/settings_view_model.dart';
import 'app_shell.dart';

class VoiceNoteApp extends StatelessWidget {
  const VoiceNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    return MaterialApp(
      title: 'VoiceNote',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}

List<SingleChildWidget> buildAppProviders() {
  return <SingleChildWidget>[
    ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(),
    ),
    Provider<RecordingDatabase>(
      create: (_) => RecordingDatabase(),
      dispose: (_, database) => database.close(),
    ),
    Provider<RecordingRepository>(
      create: (context) =>
          SqliteRecordingRepository(context.read<RecordingDatabase>()),
    ),
    Provider<AudioFileStore>(create: (_) => AudioFileStore()),
    Provider<TranscriptDraftStore>(create: (_) => TranscriptDraftStore()),
    Provider<SpeechCaptureService>(
      create: (_) => SttRecordCaptureService(),
      dispose: (_, service) {
        if (service is DisposableSpeechCaptureService) {
          unawaited(service.dispose());
        }
      },
    ),
    Provider<ShareService>(create: (_) => ShareService()),
    ChangeNotifierProvider<PlaybackViewModel>(
      create: (_) => PlaybackViewModel(),
    ),
    ChangeNotifierProvider<RecordingsViewModel>(
      create: (context) => RecordingsViewModel(
        repository: context.read<RecordingRepository>(),
        audioFileStore: context.read<AudioFileStore>(),
      ),
    ),
    ChangeNotifierProvider<RecordingViewModel>(
      create: (context) => RecordingViewModel(
        captureService: context.read<SpeechCaptureService>(),
        recordingsRepository: context.read<RecordingRepository>(),
        audioFileStore: context.read<AudioFileStore>(),
        draftStore: context.read<TranscriptDraftStore>(),
        onBeforeRecording: () => context.read<PlaybackViewModel>().stop(),
        onRecordingSaved: (_) => context.read<RecordingsViewModel>().refresh(),
      ),
    ),
  ];
}
