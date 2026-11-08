class Recording {
  const Recording({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.localeId,
    required this.localeName,
    required this.duration,
    required this.audioPath,
    required this.fileSizeBytes,
    required this.transcript,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String localeId;
  final String localeName;
  final Duration duration;
  final String audioPath;
  final int fileSizeBytes;
  final String transcript;

  Recording copyWith({
    String? title,
    String? audioPath,
    String? localeName,
    Duration? duration,
    int? fileSizeBytes,
    String? transcript,
  }) {
    return Recording(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      localeId: localeId,
      localeName: localeName ?? this.localeName,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      transcript: transcript ?? this.transcript,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'locale_id': localeId,
      'locale_name': localeName,
      'duration_ms': duration.inMilliseconds,
      'audio_path': audioPath,
      'file_size_bytes': fileSizeBytes,
      'transcript': transcript,
    };
  }

  factory Recording.fromMap(Map<String, Object?> map) {
    return Recording(
      id: map['id']! as String,
      title: map['title']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      localeId: map['locale_id']! as String,
      localeName: map['locale_name']! as String,
      duration: Duration(milliseconds: map['duration_ms']! as int),
      audioPath: map['audio_path']! as String,
      fileSizeBytes: map['file_size_bytes']! as int,
      transcript: map['transcript']! as String,
    );
  }
}
