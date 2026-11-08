import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:voicenote/core/errors/voice_note_exception.dart';
import 'package:voicenote/core/storage/audio_file_store.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'voicenote_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('validates and persists a non-empty PCM WAV file', () async {
    final source = File('${temporaryDirectory.path}/input.wav');
    await source.writeAsBytes(_wavBytes(dataBytes: 4));
    final destinationDirectory = Directory(
      '${temporaryDirectory.path}/documents',
    );
    final store = AudioFileStore(
      documentsDirectoryProvider: () async => destinationDirectory,
    );

    final persisted = await store.persist(
      temporaryPath: source.path,
      recordingId: 'recording-1',
    );

    expect(await File(persisted.path).exists(), isTrue);
    expect(persisted.sizeBytes, 48);
  });

  test('rejects an empty audio payload', () async {
    final source = File('${temporaryDirectory.path}/empty.wav');
    await source.writeAsBytes(_wavBytes(dataBytes: 0));
    final store = AudioFileStore(
      documentsDirectoryProvider: () async =>
          Directory('${temporaryDirectory.path}/documents'),
    );

    expect(
      () => store.persist(temporaryPath: source.path, recordingId: 'empty'),
      throwsA(
        isA<VoiceNoteException>().having(
          (error) => error.code,
          'code',
          VoiceNoteErrorCode.audioEmpty,
        ),
      ),
    );
  });

  test('surfaces a failed copy without leaving metadata behind', () async {
    final source = File('${temporaryDirectory.path}/input.wav');
    await source.writeAsBytes(_wavBytes(dataBytes: 4));
    final store = AudioFileStore(
      documentsDirectoryProvider: () async =>
          Directory('${temporaryDirectory.path}/documents'),
      copier: (_, _) => throw const FileSystemException('copy failed'),
    );

    expect(
      () => store.persist(temporaryPath: source.path, recordingId: 'copy-fail'),
      throwsA(
        isA<VoiceNoteException>().having(
          (error) => error.code,
          'code',
          VoiceNoteErrorCode.audioCopyFailed,
        ),
      ),
    );
  });
}

List<int> _wavBytes({required int dataBytes}) {
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
  return bytes;
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
