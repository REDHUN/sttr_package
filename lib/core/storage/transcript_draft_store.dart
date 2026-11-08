import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TranscriptDraft {
  const TranscriptDraft({
    required this.createdAt,
    required this.localeId,
    required this.localeName,
    required this.duration,
    required this.transcript,
    required this.reason,
  });

  final DateTime createdAt;
  final String localeId;
  final String localeName;
  final Duration duration;
  final String transcript;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'createdAt': createdAt.toIso8601String(),
    'localeId': localeId,
    'localeName': localeName,
    'durationMs': duration.inMilliseconds,
    'transcript': transcript,
    'reason': reason,
  };

  factory TranscriptDraft.fromJson(Map<String, Object?> json) {
    return TranscriptDraft(
      createdAt: DateTime.parse(json['createdAt']! as String),
      localeId: json['localeId']! as String,
      localeName: json['localeName']! as String,
      duration: Duration(milliseconds: json['durationMs']! as int),
      transcript: json['transcript']! as String,
      reason: json['reason']! as String,
    );
  }
}

class TranscriptDraftStore {
  TranscriptDraftStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File(
      path.join(directory.path, 'VoiceNote', 'transcript_draft.json'),
    );
  }

  Future<void> save(TranscriptDraft draft) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(draft.toJson()), flush: true);
  }

  Future<TranscriptDraft?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TranscriptDraft.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
