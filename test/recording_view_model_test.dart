import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:voicenote/core/storage/audio_file_store.dart';
import 'package:voicenote/core/storage/transcript_draft_store.dart';
import 'package:voicenote/features/recording/data/speech_capture_service.dart';
import 'package:voicenote/features/recording/domain/recording_state.dart';
import 'package:voicenote/features/recording/presentation/recording_view_model.dart';
import 'package:voicenote/features/recordings/data/recording_repository.dart';
import 'package:voicenote/features/recordings/domain/recording.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late FakeSpeechCaptureService capture;
  late InMemoryRecordingRepository repository;
  late DateTime clock;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('voicenote_vm_');
    capture = FakeSpeechCaptureService(
      audioPath: await _createWav(temporaryDirectory, dataBytes: 4),
    );
    repository = InMemoryRecordingRepository();
    clock = DateTime(2026, 10, 25, 12);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await temporaryDirectory.exists()) {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await temporaryDirectory.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  });

  RecordingViewModel buildViewModel({AudioFileStore? audioFileStore}) {
    return RecordingViewModel(
      captureService: capture,
      recordingsRepository: repository,
      audioFileStore:
          audioFileStore ??
          AudioFileStore(
            documentsDirectoryProvider: () async =>
                Directory('${temporaryDirectory.path}/documents'),
          ),
      draftStore: TranscriptDraftStore(
        directoryProvider: () async =>
            Directory('${temporaryDirectory.path}/support'),
      ),
      now: () => clock,
    );
  }

  test(
    'replaces accumulated transcript snapshots without duplication',
    () async {
      final viewModel = buildViewModel();
      await viewModel.initialize();
      await viewModel.start();

      capture.emitTranscript('hello', isFinal: false);
      capture.emitTranscript('hello world', isFinal: false);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.transcript, 'hello world');
      expect(viewModel.transcript.contains('hello hello'), isFalse);
      viewModel.dispose();
    },
  );

  test('serializes rapid repeated starts', () async {
    final viewModel = buildViewModel();
    await viewModel.initialize();

    await Future.wait<void>(<Future<void>>[
      viewModel.start(),
      viewModel.start(),
      viewModel.start(),
    ]);

    expect(capture.startCalls, 1);
    expect(viewModel.state, RecordingState.recording);
    viewModel.dispose();
  });

  test('ignores late events from an old session', () async {
    final viewModel = buildViewModel();
    await viewModel.initialize();
    await viewModel.start();
    capture.emitTranscript('old session', isFinal: false);
    await Future<void>.delayed(Duration.zero);
    await viewModel.discard();

    await viewModel.start();
    capture.emitTranscript('new session', isFinal: false);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.transcript, 'new session');
    await viewModel.discard();
    viewModel.dispose();
  });

  test('excludes paused time from the saved duration', () async {
    final viewModel = buildViewModel();
    await viewModel.initialize();
    await viewModel.start();

    clock = clock.add(const Duration(seconds: 2));
    await viewModel.pause();
    expect(viewModel.activeDuration, const Duration(seconds: 2));

    clock = clock.add(const Duration(seconds: 10));
    await viewModel.resume();
    clock = clock.add(const Duration(seconds: 3));
    await viewModel.stop();

    expect(repository.items.single.duration, const Duration(seconds: 5));
    expect(viewModel.state, RecordingState.completed);
    viewModel.dispose();
  });

  test('preserves a transcript draft when audio copying fails', () async {
    final viewModel = buildViewModel(
      audioFileStore: AudioFileStore(
        documentsDirectoryProvider: () async =>
            Directory('${temporaryDirectory.path}/documents'),
        copier: (_, _) => throw const FileSystemException('disk full'),
      ),
    );
    await viewModel.initialize();
    await viewModel.start();
    capture.emitTranscript('keep this text', isFinal: true);
    await Future<void>.delayed(Duration.zero);
    await viewModel.stop();

    expect(viewModel.state, RecordingState.error);
    expect(viewModel.errorMessage, contains('draft was preserved'));
    final draft = await TranscriptDraftStore(
      directoryProvider: () async =>
          Directory('${temporaryDirectory.path}/support'),
    ).load();
    expect(draft?.transcript, 'keep this text');
    expect(repository.items, isEmpty);
    viewModel.dispose();
  });

  test(
    'provider disposal cancels subscriptions and releases capture service',
    () async {
      final viewModel = buildViewModel();
      await viewModel.initialize();
      await viewModel.start();
      viewModel.dispose();
      capture.emitTranscript('ignored after dispose', isFinal: false);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.transcript, isEmpty);
      await capture.dispose();
      expect(capture.disposeCalls, 1);
    },
  );
}

class FakeSpeechCaptureService extends DisposableSpeechCaptureService {
  FakeSpeechCaptureService({required this.audioPath});

  final String audioPath;
  final StreamController<TranscriptSnapshot> _transcripts =
      StreamController<TranscriptSnapshot>.broadcast();
  final StreamController<CaptureSessionEvent> _states =
      StreamController<CaptureSessionEvent>.broadcast();
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  bool permissionGranted = true;
  bool throwOnStart = false;

  @override
  Stream<TranscriptSnapshot> get transcriptStream => _transcripts.stream;

  @override
  Stream<CaptureSessionEvent> get sessionEventStream => _states.stream;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<List<RecognitionLocale>> getSupportedLocales() async => const [
    RecognitionLocale(id: 'en-IN', name: 'English (India)'),
    RecognitionLocale(id: 'ml-IN', name: 'Malayalam (India)'),
  ];

  @override
  Future<void> start({required String localeId}) async {
    startCalls++;
    if (throwOnStart) throw StateError('start failed');
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _states.add(CaptureSessionEvent.paused);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _states.add(CaptureSessionEvent.resumed);
  }

  @override
  Future<String> stop() async {
    stopCalls++;
    return audioPath;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<double> getAmplitude() async => 0.35;

  void emitTranscript(String text, {required bool isFinal}) {
    if (!_transcripts.isClosed) {
      _transcripts.add(TranscriptSnapshot(text: text, isFinal: isFinal));
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _transcripts.close();
    await _states.close();
  }
}

class InMemoryRecordingRepository implements RecordingRepository {
  final List<Recording> items = <Recording>[];

  @override
  Future<int> count({String query = ''}) async => _filtered(query).length;

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> deleteAll() async => items.clear();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> insert(Recording recording) async => items.add(recording);

  @override
  Future<List<Recording>> search({
    required String query,
    required int offset,
    required int limit,
  }) async {
    final filtered = _filtered(query);
    return filtered.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<int> totalBytes() async =>
      items.fold<int>(0, (total, item) => total + item.fileSizeBytes);

  @override
  Future<void> update(Recording recording) async {
    final index = items.indexWhere((item) => item.id == recording.id);
    if (index >= 0) items[index] = recording;
  }

  List<Recording> _filtered(String query) {
    final normalized = query.toLowerCase().trim();
    return items
        .where((item) {
          return normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized) ||
              item.transcript.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }
}

Future<String> _createWav(Directory directory, {required int dataBytes}) async {
  final path = '${directory.path}/capture.wav';
  final bytes = List<int>.filled(44 + dataBytes, 0);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  _writeUint32(bytes, 4, 36 + dataBytes);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  _writeUint32(bytes, 16, 16);
  _writeUint16(bytes, 20, 1);
  _writeUint16(bytes, 22, 1);
  _writeUint32(bytes, 24, 16000);
  _writeUint32(bytes, 28, 32000);
  _writeUint16(bytes, 32, 2);
  _writeUint16(bytes, 34, 16);
  bytes.setRange(36, 40, 'data'.codeUnits);
  _writeUint32(bytes, 40, dataBytes);
  await File(path).writeAsBytes(bytes);
  return path;
}

void _writeUint16(List<int> bytes, int offset, int value) {
  bytes[offset] = value & 0xFF;
  bytes[offset + 1] = (value >> 8) & 0xFF;
}

void _writeUint32(List<int> bytes, int offset, int value) {
  bytes[offset] = value & 0xFF;
  bytes[offset + 1] = (value >> 8) & 0xFF;
  bytes[offset + 2] = (value >> 16) & 0xFF;
  bytes[offset + 3] = (value >> 24) & 0xFF;
}
