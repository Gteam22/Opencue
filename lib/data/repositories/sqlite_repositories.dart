import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/enums/enums.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/interaction_record.dart';
import '../../domain/models/opener_line.dart';
import '../../domain/repositories/library_query.dart';
import '../../domain/repositories/repositories.dart';

/// SQLite-backed opener storage.
class SqliteOpenerLineRepository implements OpenerLineRepository {
  SqliteOpenerLineRepository(this._db);

  final Database _db;

  static const String _table = 'opener_lines';

  @override
  Future<List<OpenerLine>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'created_at DESC, id ASC');
    return rows.map(OpenerLine.fromDbRow).toList();
  }

  @override
  Future<OpenerLine?> getById(String id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OpenerLine.fromDbRow(rows.first);
  }

  /// Applies the library filters.
  ///
  /// Text search, favourites and the directness range are pushed into SQL. The
  /// tag filters are applied in Dart: the tag columns hold small comma-joined
  /// controlled vocabularies, and a LIKE on them would match `alone` inside
  /// nothing but would still need per-value OR clauses, so doing the set
  /// intersection in Dart is both clearer and correct. The library is a few
  /// hundred rows, so this is not a performance concern.
  @override
  Future<List<OpenerLine>> query(LibraryQuery query) async {
    final where = <String>[];
    final args = <Object?>[];

    final search = query.searchText.trim();
    if (search.isNotEmpty) {
      where.add(
        '(japanese_text LIKE ? OR '
        'LOWER(COALESCE(english_meaning, \'\')) LIKE ?)',
      );
      args
        ..add('%$search%')
        ..add('%${search.toLowerCase()}%');
    }
    if (query.favoritesOnly) {
      where.add('is_favorite = 1');
    }
    if (query.userCreatedOnly) {
      where.add('is_user_created = 1');
    }
    where.add('directness BETWEEN ? AND ?');
    args
      ..add(query.minDirectness)
      ..add(query.maxDirectness);

    final rows = await _db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
    );

    var lines = rows.map(OpenerLine.fromDbRow).toList();

    if (query.locations.isNotEmpty) {
      lines = lines
          .where((l) => l.locations.intersection(query.locations).isNotEmpty)
          .toList();
    }
    if (query.cues.isNotEmpty) {
      lines = lines
          .where((l) => l.observableCues.intersection(query.cues).isNotEmpty)
          .toList();
    }
    if (query.tones.isNotEmpty) {
      lines = lines
          .where((l) => l.tones.intersection(query.tones).isNotEmpty)
          .toList();
    }
    if (query.categories.isNotEmpty) {
      lines =
          lines.where((l) => query.categories.contains(l.category)).toList();
    }

    _applySort(lines, query.sort);
    return lines;
  }

  void _applySort(List<OpenerLine> lines, LibrarySort sort) {
    switch (sort) {
      case LibrarySort.recentlyAdded:
        lines.sort((a, b) {
          final byDate = b.createdAt.compareTo(a.createdAt);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      case LibrarySort.mostUsed:
        lines.sort((a, b) {
          final byUse = b.timesUsed.compareTo(a.timesUsed);
          return byUse != 0 ? byUse : a.id.compareTo(b.id);
        });
      case LibrarySort.highestPositiveHistory:
        lines.sort((a, b) {
          // Lines with too little history sort last rather than appearing to
          // outrank well-evidenced ones on a single lucky record.
          final aSignal = a.personalSignal;
          final bSignal = b.personalSignal;
          if (aSignal == null && bSignal == null) return a.id.compareTo(b.id);
          if (aSignal == null) return 1;
          if (bSignal == null) return -1;
          final bySignal = bSignal.compareTo(aSignal);
          return bySignal != 0 ? bySignal : a.id.compareTo(b.id);
        });
      case LibrarySort.alphabetical:
        lines.sort((a, b) {
          final byText = a.japaneseText.compareTo(b.japaneseText);
          return byText != 0 ? byText : a.id.compareTo(b.id);
        });
    }
  }

  @override
  Future<void> insert(OpenerLine line) async {
    await _db.insert(
      _table,
      line.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> insertMany(List<OpenerLine> lines) async {
    if (lines.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final line in lines) {
        batch.insert(
          _table,
          line.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> update(OpenerLine line) async {
    await _db.update(
      _table,
      line.toDbMap(),
      where: 'id = ?',
      whereArgs: <Object?>[line.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> replaceAll(List<OpenerLine> lines) async {
    await _db.transaction((txn) async {
      await txn.delete(_table);
      final batch = txn.batch();
      for (final line in lines) {
        batch.insert(_table, line.toDbMap());
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) async {
    await _db.update(
      _table,
      <String, Object?>{
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<void> incrementTimesShown(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final placeholders = List.filled(list.length, '?').join(', ');
    await _db.rawUpdate(
      'UPDATE $_table SET times_shown = times_shown + 1 '
      'WHERE id IN ($placeholders)',
      list,
    );
  }

  @override
  Future<void> recordOutcome(String id, InteractionOutcome outcome) async {
    final column = switch (outcome) {
      InteractionOutcome.positive => 'positive_results',
      InteractionOutcome.neutral => 'neutral_results',
      InteractionOutcome.unreceptive => 'negative_results',
      InteractionOutcome.notRecorded => null,
    };
    final sets = <String>['times_used = times_used + 1'];
    if (column != null) {
      sets.add('$column = $column + 1');
    }
    await _db.rawUpdate(
      'UPDATE $_table SET ${sets.join(', ')}, updated_at = ? WHERE id = ?',
      <Object?>[DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  @override
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n']! as num).toInt();
  }

  @override
  Future<Set<String>> existingIds() async {
    final rows = await _db.query(_table, columns: <String>['id']);
    return rows.map((row) => row['id']! as String).toSet();
  }

  /// Resets every usage counter without deleting any line. Used by the
  /// "Clear interaction history" action, so that clearing the log also clears
  /// the statistics derived from it.
  Future<void> resetAllCounters() async {
    await _db.rawUpdate(
      'UPDATE $_table SET times_shown = 0, times_used = 0, '
      'positive_results = 0, neutral_results = 0, negative_results = 0',
    );
  }
}

/// SQLite-backed interaction log.
class SqliteInteractionRepository implements InteractionRepository {
  SqliteInteractionRepository(this._db);

  final Database _db;

  static const String _table = 'interactions';

  @override
  Future<List<InteractionRecord>> getAll({int? limit}) async {
    final rows = await _db.query(
      _table,
      orderBy: 'date_used DESC, id ASC',
      limit: limit,
    );
    return rows.map(InteractionRecord.fromDbRow).toList();
  }

  @override
  Future<List<InteractionRecord>> getForLine(String openerLineId) async {
    final rows = await _db.query(
      _table,
      where: 'opener_line_id = ?',
      whereArgs: <Object?>[openerLineId],
      orderBy: 'date_used DESC',
    );
    return rows.map(InteractionRecord.fromDbRow).toList();
  }

  @override
  Future<void> insert(InteractionRecord record) async {
    await _db.insert(
      _table,
      record.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertMany(List<InteractionRecord> records) async {
    if (records.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert(
          _table,
          record.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> clearAll() async {
    await _db.delete(_table);
  }

  @override
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n']! as num).toInt();
  }

  @override
  Future<Set<String>> existingIds() async {
    final rows = await _db.query(_table, columns: <String>['id']);
    return rows.map((row) => row['id']! as String).toSet();
  }
}

/// Key/value settings storage.
class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._db);

  final Database _db;

  static const String _table = 'settings';

  @override
  Future<AppSettings> load() async {
    final rows = await _db.query(_table);
    final map = <String, String>{};
    for (final row in rows) {
      map[row['key']! as String] = row['value']! as String;
    }
    if (map.isEmpty) return AppSettings.defaults;
    return AppSettings.fromStringMap(map);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final map = settings.toStringMap();
    await _db.transaction((txn) async {
      final batch = txn.batch();
      map.forEach((key, value) {
        batch.insert(
          _table,
          <String, Object?>{'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      await batch.commit(noResult: true);
    });
  }
}
