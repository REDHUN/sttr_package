import 'package:flutter/services.dart';

enum VoiceNoteErrorCode {
  permissionDenied,
  recognitionUnavailable,
  unsupportedLocale,
  startFailed,
  stopFailed,
  cancelFailed,
  audioMissing,
  audioEmpty,
  audioInvalid,
  audioCopyFailed,
  storageUnavailable,
  databaseFailed,
  playbackFailed,
  unknown,
}

class VoiceNoteException implements Exception {
  const VoiceNoteException({
    required this.code,
    required this.message,
    this.cause,
  });

  final VoiceNoteErrorCode code;
  final String message;
  final Object? cause;

  factory VoiceNoteException.fromObject(Object error) {
    if (error is VoiceNoteException) {
      return error;
    }

    if (error is PlatformException) {
      final code = switch (error.code) {
        'permission_denied' => VoiceNoteErrorCode.permissionDenied,
        'stt_unavailable' => VoiceNoteErrorCode.recognitionUnavailable,
        'start_failed' => VoiceNoteErrorCode.startFailed,
        'cancel_failed' => VoiceNoteErrorCode.cancelFailed,
        _ => VoiceNoteErrorCode.unknown,
      };
      return VoiceNoteException(
        code: code,
        message: error.message ?? error.code,
        cause: error,
      );
    }

    if (error is StateError) {
      return VoiceNoteException(
        code: VoiceNoteErrorCode.stopFailed,
        message: error.message,
        cause: error,
      );
    }

    return VoiceNoteException(
      code: VoiceNoteErrorCode.unknown,
      message: error.toString(),
      cause: error,
    );
  }

  @override
  String toString() => 'VoiceNoteException($code): $message';
}
