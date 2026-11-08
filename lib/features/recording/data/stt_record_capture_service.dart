import 'dart:io';

import 'package:flutter/services.dart';
import 'package:stt_record/stt_record.dart';

import '../../../core/errors/voice_note_exception.dart';
import 'speech_capture_service.dart';

class SttRecordCaptureService extends DisposableSpeechCaptureService {
  SttRecordCaptureService({SttRecord? plugin})
    : _plugin = plugin ?? SttRecord();

  final SttRecord _plugin;

  @override
  Stream<TranscriptSnapshot> get transcriptStream => _plugin.transcripts.map(
    (event) => TranscriptSnapshot(text: event.text, isFinal: event.isFinal),
  );

  @override
  Stream<CaptureSessionEvent> get sessionEventStream =>
      _plugin.sessionStates.map((event) {
        return switch (event) {
          SttRecordSessionState.paused => CaptureSessionEvent.paused,
          SttRecordSessionState.resumed => CaptureSessionEvent.resumed,
        };
      });

  @override
  Future<bool> requestPermission() async {
    try {
      return await _plugin.requestPermission();
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<List<RecognitionLocale>> getSupportedLocales() async {
    try {
      final locales = await _plugin.getLocales(
        preferLocales: const <String>['en-IN', 'ml-IN', 'en-US'],
      );
      return locales
          .map(
            (locale) =>
                RecognitionLocale(id: locale.localeId, name: locale.name),
          )
          .toList(growable: false);
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<void> start({required String localeId}) async {
    try {
      await _plugin.start(
        localeId: localeId,
        partialResults: true,
        enableSystemNotification: Platform.isAndroid,
        systemNotificationTitle: 'VoiceNote is recording',
        systemNotificationBody: 'Tap to return to your live transcript',
        enableSystemNotificationActionPause: false,
        enableSystemNotificationActionStop: false,
      );
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _plugin.pause();
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _plugin.resume();
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<String> stop() async {
    try {
      return (await _plugin.stop()).audioPath;
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    } on StateError catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _plugin.cancel();
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }

  @override
  Future<double> getAmplitude() async {
    try {
      final amplitude = await _plugin.getAmplitude();
      return amplitude.clamp(0.0, 1.0);
    } on PlatformException catch (error) {
      throw VoiceNoteException.fromObject(error);
    }
  }
}
