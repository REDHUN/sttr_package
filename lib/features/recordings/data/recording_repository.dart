import '../../../core/errors/voice_note_exception.dart';
import '../../../core/storage/recording_database.dart';
import '../domain/recording.dart';

abstract interface class RecordingRepository {
  Future<List<Recording>> search({
    required String query,
    required int offset,
    required int limit,
  });

  Future<int> count({String query = ''});

  Future<int> totalBytes();

  Future<void> insert(Recording recording);

  Future<void> update(Recording recording);

  Future<void> delete(String id);

  Future<void> deleteAll();

  Future<void> dispose();
}

class SqliteRecordingRepository implements RecordingRepository {
  SqliteRecordingRepository(this._database);

  final RecordingDatabase _database;

  @override
  Future<List<Recording>> search({
    required String query,
    required int offset,
    required int limit,
  }) async {
    try {
      final db = await _database.database;
      final normalized = query.trim();
      final args = normalized.isEmpty
          ? <Object?>[limit, offset]
          : <Object?>['%$normalized%', '%$normalized%', limit, offset];
      final rows = await db.query(
        'recordings',
        where: normalized.isEmpty ? null : 'title LIKE ? OR transcript LIKE ?',
        whereArgs: normalized.isEmpty ? null : args.sublist(0, 2),
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );
      return rows
          .map((row) => Recording.fromMap(Map<String, Object?>.from(row)))
          .toList(growable: false);
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to load recordings.',
        cause: error,
      );
    }
  }

  @override
  Future<int> count({String query = ''}) async {
    try {
      final db = await _database.database;
      final normalized = query.trim();
      final result = await db.rawQuery(
        normalized.isEmpty
            ? 'SELECT COUNT(*) AS count FROM recordings'
            : 'SELECT COUNT(*) AS count FROM recordings '
                  'WHERE title LIKE ? OR transcript LIKE ?',
        normalized.isEmpty ? null : <Object?>['%$normalized%', '%$normalized%'],
      );
      return (result.first['count'] as int?) ?? 0;
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to count recordings.',
        cause: error,
      );
    }
  }

  @override
  Future<int> totalBytes() async {
    try {
      final db = await _database.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(file_size_bytes), 0) AS bytes FROM recordings',
      );
      return (result.first['bytes'] as int?) ?? 0;
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to calculate storage usage.',
        cause: error,
      );
    }
  }

  @override
  Future<void> insert(Recording recording) async {
    try {
      final db = await _database.database;
      await db.insert('recordings', recording.toMap());
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to save recording metadata.',
        cause: error,
      );
    }
  }

  @override
  Future<void> update(Recording recording) async {
    try {
      final db = await _database.database;
      final changed = await db.update(
        'recordings',
        recording.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[recording.id],
      );
      if (changed == 0) {
        throw StateError('Recording ${recording.id} no longer exists.');
      }
    } on VoiceNoteException {
      rethrow;
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to update recording metadata.',
        cause: error,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final db = await _database.database;
      await db.delete('recordings', where: 'id = ?', whereArgs: <Object?>[id]);
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to delete recording metadata.',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final db = await _database.database;
      await db.delete('recordings');
    } on Exception catch (error) {
      throw VoiceNoteException(
        code: VoiceNoteErrorCode.databaseFailed,
        message: 'Unable to clear recording metadata.',
        cause: error,
      );
    }
  }

  @override
  Future<void> dispose() => _database.close();
}
