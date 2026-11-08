import 'dart:async';

class RecognitionLocale {
  const RecognitionLocale({required this.id, required this.name});

  final String id;
  final String name;
}

class TranscriptSnapshot {
  const TranscriptSnapshot({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

enum CaptureSessionEvent { paused, resumed }

abstract interface class SpeechCaptureService {
  Stream<TranscriptSnapshot> get transcriptStream;

  Stream<CaptureSessionEvent> get sessionEventStream;

  Future<bool> requestPermission();

  Future<List<RecognitionLocale>> getSupportedLocales();

  Future<void> start({required String localeId});

  Future<void> pause();

  Future<void> resume();

  Future<String> stop();

  Future<void> cancel();

  Future<double> getAmplitude();
}

/// A small adapter interface keeps native microphone ownership behind a
/// replaceable boundary. Tests can provide a deterministic fake service.
abstract class DisposableSpeechCaptureService implements SpeechCaptureService {
  Future<void> dispose() async {}
}
