import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../errors/voice_note_exception.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef AudioFileCopier =
    Future<File> Function(File source, String destination);

class PersistedAudio {
  const PersistedAudio({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

class WavInfo {
  const WavInfo({required this.fileSizeBytes, required this.dataSizeBytes});

  final int fileSizeBytes;
  final int dataSizeBytes;
}

class AudioFileStore {
  AudioFileStore({
    DocumentsDirectoryProvider? documentsDirectoryProvider,
    AudioFileCopier? copier,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _copier = copier ?? _copyFile;

  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  final AudioFileCopier _copier;

  static Future<File> _copyFile(File source, String destination) {
    return source.copy(destination);
  }

  Future<PersistedAudio> persist({
    required String temporaryPath,
    required String recordingId,
  }) async {
    final source = File(temporaryPath);
    final sourceInfo = await validateWav(source);
    if (sourceInfo.dataSizeBytes <= 0) {
      throw const VoiceNoteException(
        code: VoiceNoteErrorCode.audioEmpty,
        message: 'The recorder returned an empty audio file.',
      );
    }

    try {
      final documents = await _documentsDirectoryProvider();
      final recordingsDirectory = Directory(
        path.join(documents.path, 'VoiceNote', 'recordings'),
      );
      await recordingsDirectory.create(recursive: true);

      final destination = path.join(
        recordingsDirectory.path,
        '$recordingId.wav',
      );
      final copied = await _copier(source, destination);
      final persistedInfo = await validateWav(copied);
      return PersistedAudio(
        path: copied.path,
        sizeBytes: persistedInfo.fileSizeBytes,
      );
    } on VoiceNoteException {
      rethrow;
    } on FileSystemException catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.audioCopyFailed,
        message: 'Unable to copy the recorded audio to app storage.',
        cause: error,
      );
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.storageUnavailable,
        message: 'Unable to access app storage.',
        cause: error,
      );
    }
  }

  Future<void> delete(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<WavInfo> validateWav(File file) async {
    if (!await file.exists()) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.audioMissing,
        message: 'The temporary audio file is missing.',
      );
    }

    final size = await file.length();
    if (size < 44) {
      throw const VoiceNoteException(
        code: VoiceNoteErrorCode.audioInvalid,
        message: 'The audio file is not a complete WAV file.',
      );
    }

    final handle = await file.open();
    late final Uint8List header;
    try {
      header = await handle.read(44);
    } finally {
      await handle.close();
    }

    final riff = String.fromCharCodes(header.sublist(0, 4));
    final wave = String.fromCharCodes(header.sublist(8, 12));
    final audioFormat = _readUint16(header, 20);
    final channels = _readUint16(header, 22);
    final sampleRate = _readUint32(header, 24);
    final bitsPerSample = _readUint16(header, 34);
    final dataSize = _readUint32(header, 40);

    if (riff != 'RIFF' || wave != 'WAVE' || audioFormat != 1) {
      throw const VoiceNoteException(
        code: VoiceNoteErrorCode.audioInvalid,
        message: 'The recorder returned an unsupported WAV structure.',
      );
    }
    if (channels <= 0 || sampleRate <= 0 || bitsPerSample != 16) {
      throw const VoiceNoteException(
        code: VoiceNoteErrorCode.audioInvalid,
        message: 'The recorder returned invalid WAV audio properties.',
      );
    }
    if (dataSize <= 0) {
      throw const VoiceNoteException(
        code: VoiceNoteErrorCode.audioEmpty,
        message: 'The recorder returned an empty audio payload.',
      );
    }
    if (size < 44 + dataSize) {
      throw const VoiceNoteException(
        code: VoiceNoteErrorCode.audioInvalid,
        message: 'The WAV header is larger than the audio file.',
      );
    }

    return WavInfo(fileSizeBytes: size, dataSizeBytes: dataSize);
  }

  static int _readUint16(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }
}
