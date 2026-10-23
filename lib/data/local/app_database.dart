import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database and owns schema migrations.
abstract final class AppDatabase {
  static const fileName = 'neurallens.db';
  static const schemaVersion = 1;

  /// [factory] and [path] are overridable for tests (sqflite_common_ffi).
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, _) => _createV1(db),
      ),
    );
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE scripts (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        sections_json TEXT,
        format TEXT NOT NULL,
        tone TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_ai_generated INTEGER NOT NULL DEFAULT 0,
        generation_meta_json TEXT,
        last_position INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_scripts_updated_at ON scripts (updated_at DESC)',
    );
  }
}
