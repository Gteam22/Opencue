import 'package:sqflite_common/sqlite_api.dart';

import '../../core/app_info.dart';
import 'database_platform.dart';

/// Opens and migrates the local SQLite database.
///
/// Which SQLite implementation backs this is decided by [DatabasePlatform]:
/// `sqflite_common_ffi` on desktop, `sqflite` on Android and iOS. The schema,
/// the migrations and every repository are written against the shared
/// `sqflite_common` API, so nothing below this line differs per platform.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// Prepares the platform's SQLite. Safe to call more than once.
  ///
  /// Named `initialiseFfi` for continuity: every existing test calls it in
  /// `setUpAll`, and on desktop it still does exactly what it always did. On
  /// mobile it is a no-op.
  static void initialiseFfi() => DatabasePlatform.initialise();

  /// Opens the database at [path], creating and migrating as needed.
  ///
  /// Pass [DatabasePlatform.inMemoryPath] for tests.
  static Future<AppDatabase> open(String path) async {
    initialiseFfi();
    final database = await DatabasePlatform.factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppInfo.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(database);
  }

  /// Opens a throwaway in-memory database. Used by the tests.
  static Future<AppDatabase> openInMemory() =>
      open(DatabasePlatform.inMemoryPath);

  static Future<void> _onConfigure(Database db) async {
    // Interactions reference lines, so foreign keys must be enforced.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> close() => db.close();

  /// The schema as of version 1. Later versions are reached by [_onUpgrade],
  /// never by editing this method, so that an upgrade from v1 and a fresh
  /// install end up byte-identical. The migration test asserts exactly that.
  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE opener_lines (
        id TEXT PRIMARY KEY NOT NULL,
        japanese_text TEXT NOT NULL,
        english_meaning TEXT,
        category TEXT NOT NULL DEFAULT 'universal',
        locations TEXT NOT NULL DEFAULT '',
        observable_cues TEXT NOT NULL DEFAULT '',
        group_sizes TEXT NOT NULL DEFAULT '',
        noise_levels TEXT NOT NULL DEFAULT '',
        tones TEXT NOT NULL DEFAULT '',
        directness INTEGER NOT NULL DEFAULT 2,
        conditions TEXT NOT NULL DEFAULT '',
        avoid_conditions TEXT NOT NULL DEFAULT '',
        follow_up_suggestion TEXT,
        notes TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_user_created INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        times_shown INTEGER NOT NULL DEFAULT 0,
        times_used INTEGER NOT NULL DEFAULT 0,
        positive_results INTEGER NOT NULL DEFAULT 0,
        neutral_results INTEGER NOT NULL DEFAULT 0,
        negative_results INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE interactions (
        id TEXT PRIMARY KEY NOT NULL,
        opener_line_id TEXT NOT NULL,
        context_snapshot TEXT,
        date_used TEXT NOT NULL,
        outcome TEXT NOT NULL DEFAULT 'notRecorded',
        optional_notes TEXT,
        FOREIGN KEY (opener_line_id)
          REFERENCES opener_lines (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_lines_favorite ON opener_lines (is_favorite)',
    );
    await db.execute(
      'CREATE INDEX idx_lines_category ON opener_lines (category)',
    );
    await db.execute(
      'CREATE INDEX idx_interactions_line ON interactions (opener_line_id)',
    );
    await db.execute(
      'CREATE INDEX idx_interactions_date ON interactions (date_used)',
    );
  }

  /// Version 2 added the `activities` column.
  static Future<void> _migrateV1ToV2(Database db) async {
    await db.execute(
      "ALTER TABLE opener_lines ADD COLUMN activities TEXT NOT NULL "
      "DEFAULT ''",
    );
  }

  /// Version 3 added `context_presets`, backing the radial menu's saved and
  /// recent contexts. The draft is one JSON column for the same reason
  /// `interactions.context_snapshot` is: adding a field to ContextDraft must
  /// not require a migration.
  static Future<void> _migrateV2ToV3(Database db) async {
    await db.execute('''
      CREATE TABLE context_presets (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        draft TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_starter INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_used_at TEXT,
        times_used INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_presets_order ON context_presets (sort_order)',
    );
    await db.execute(
      'CREATE INDEX idx_presets_used ON context_presets (last_used_at)',
    );
  }

  /// Version 4 added Korean (and, structurally, any language) to a line.
  ///
  /// Two nullable columns, added to the existing table rather than a new one:
  /// `translations` holds a JSON object keyed by language code, and
  /// `korean_romanization` holds the Roman reading. Nullable and additive, so
  /// every existing row stays valid and the Japanese text is untouched.
  static Future<void> _migrateV3ToV4(Database db) async {
    await db.execute('ALTER TABLE opener_lines ADD COLUMN translations TEXT');
    await db.execute(
      'ALTER TABLE opener_lines ADD COLUMN korean_romanization TEXT',
    );
  }

  /// Version 5 adds metadata for the manually browsed conversation library.
  /// Existing situational lines keep null metadata and remain recommendable.
  static Future<void> _migrateV4ToV5(Database db) async {
    await db.execute('ALTER TABLE opener_lines ADD COLUMN boldness TEXT');
    await db.execute('ALTER TABLE opener_lines ADD COLUMN usage_type TEXT');
    await db.execute(
      "ALTER TABLE opener_lines ADD COLUMN topics TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'ALTER TABLE opener_lines ADD COLUMN manual_only INTEGER NOT NULL '
      'DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE opener_lines ADD COLUMN tts_japanese INTEGER NOT NULL '
      'DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE opener_lines ADD COLUMN tts_korean INTEGER NOT NULL '
      'DEFAULT 1',
    );
    await db.execute(
      'CREATE INDEX idx_lines_manual_only ON opener_lines (manual_only)',
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createV1(db);
    // A fresh install runs the same migration steps as an upgrade, so the two
    // paths cannot drift apart.
    await _onUpgrade(db, 1, version);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _migrateV1ToV2(db);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await _migrateV2ToV3(db);
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await _migrateV3ToV4(db);
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await _migrateV4ToV5(db);
    }
    // Future migrations append here. Never edit an existing step.
  }

  /// Creates a v1-schema database for the migration test.
  static Future<Database> openLegacyV1ForTest(String path) async {
    initialiseFfi();
    return DatabasePlatform.factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: _onConfigure,
        onCreate: (db, _) => _createV1(db),
      ),
    );
  }

  /// Column names actually present on a table, used by the migration test.
  static Future<List<String>> columnsOf(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name']! as String).toList();
  }

  /// Deletes every row in every table. Backs the "Reset all local data"
  /// action in settings.
  Future<void> wipeAll() async {
    await db.transaction((txn) async {
      await txn.delete('interactions');
      await txn.delete('opener_lines');
      await txn.delete('context_presets');
      await txn.delete('settings');
    });
  }
}
