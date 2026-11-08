import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class RecordingDatabase {
  RecordingDatabase({this._databasePath});

  final String? _databasePath;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final resolvedPath =
        _databasePath ??
        path.join(await getDatabasesPath(), 'voicenote.sqlite');
    final opened = await openDatabase(
      resolvedPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recordings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            locale_id TEXT NOT NULL,
            locale_name TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            audio_path TEXT NOT NULL,
            file_size_bytes INTEGER NOT NULL,
            transcript TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX recordings_created_at_idx '
          'ON recordings(created_at DESC)',
        );
        await db.execute(
          'CREATE INDEX recordings_title_idx ON recordings(title)',
        );
      },
    );
    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
