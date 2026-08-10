// Tests for context presets: the model, the v2→v3 migration, the repository's
// ordering and recency rules, and the new radial settings.
//
// The migration test matters most. A user upgrading from 0.1.0 has a v2
// database with no `context_presets` table; they must arrive at exactly the
// schema a fresh install produces, with their lines and history intact.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:opencue/core/app_info.dart';
import 'package:opencue/data/db/app_database.dart';
import 'package:opencue/data/repositories/sqlite_repositories.dart';
import 'package:opencue/data/seed/starter_presets.dart';
import 'package:opencue/domain/context/context_draft.dart';
import 'package:opencue/domain/context/radial_geometry.dart';
import 'package:opencue/domain/context/radial_menu_tree.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/context_preset.dart';
import 'package:opencue/domain/scan/venue_category.dart';

void main() {
  setUpAll(AppDatabase.initialiseFfi);

  group('ContextPreset model', () {
    ContextPreset sample() => ContextPreset(
          id: 'p1',
          name: 'Quiet cafe',
          draft: ContextDraft.empty()
              .apply(const SetLocation(LocationTag.cafe))
              .apply(const SetGroupSize(GroupSize.alone))
              .apply(const ToggleCue(ObservableCue.drink))
              .apply(const ToggleCaution(AvoidCondition.headphonesOn)),
          createdAt: DateTime.utc(2026, 3, 1),
        );

    test('round-trips through a database row', () {
      final restored = ContextPreset.fromDbRow(sample().toDbRow());
      expect(restored.id, 'p1');
      expect(restored.name, 'Quiet cafe');
      expect(restored.draft.location, LocationTag.cafe);
      expect(restored.draft.groupSize, GroupSize.alone);
      expect(restored.draft.cues, <ObservableCue>{ObservableCue.drink});
      expect(
        restored.draft.cautions,
        <AvoidCondition>{AvoidCondition.headphonesOn},
      );
    });

    test('a venue subtype survives the round trip', () {
      final preset = sample().copyWith(
        draft: ContextDraft.empty().apply(const SetLocation(
          LocationTag.trainStation,
          venue: VenueCategory.trainPlatform,
        )),
      );
      final restored = ContextPreset.fromDbRow(preset.toDbRow());
      expect(restored.draft.venue, VenueCategory.trainPlatform);
      expect(restored.draft.location, LocationTag.trainStation);
    });

    test('a corrupt draft blob costs one preset its context, not the list',
        () {
      final row = sample().toDbRow()..['draft'] = 'not json at all';
      final restored = ContextPreset.fromDbRow(row);
      expect(restored.id, 'p1');
      expect(restored.draft.location, LocationTag.other);
    });

    test('unknown enum names in a draft are skipped, not fatal', () {
      final row = sample().toDbRow()
        ..['draft'] = '{"location":"teleportPad","cues":["drink","warpCore"]}';
      final restored = ContextPreset.fromDbRow(row);
      expect(restored.draft.location, LocationTag.other);
      expect(restored.draft.cues, <ObservableCue>{ObservableCue.drink});
    });

    test('a derived avoid condition in a file is filtered out', () {
      // Only the five user-settable conditions belong on a draft.
      final row = sample().toDbRow()
        ..['draft'] = '{"cautions":["personWorking","companionsPresent"]}';
      final restored = ContextPreset.fromDbRow(row);
      expect(
        restored.draft.cautions,
        <AvoidCondition>{AvoidCondition.personWorking},
      );
    });

    test('markUsed bumps the counter and the timestamp', () {
      final used = sample().markUsed(at: DateTime.utc(2026, 4, 1));
      expect(used.timesUsed, 1);
      expect(used.lastUsedAt, DateTime.utc(2026, 4, 1));
    });

    test('validation rejects an empty id or name', () {
      expect(sample().validationErrors(), isEmpty);
      expect(sample().copyWith(name: '  ').validationErrors(),
          contains('preset.error.emptyName'));
      expect(sample().copyWith(id: '').validationErrors(),
          contains('preset.error.emptyId'));
    });
  });

  group('starter presets', () {
    final starter = const StarterPresets().load();

    test('all eight load, with unique ids and no validation errors', () {
      expect(starter, hasLength(8));
      expect(starter.map((p) => p.id).toSet(), hasLength(8));
      for (final preset in starter) {
        expect(preset.validationErrors(), isEmpty, reason: preset.id);
      }
    });

    test('their names are localization keys, not literal text', () {
      for (final preset in starter) {
        expect(preset.isStarter, isTrue);
        expect(preset.nameIsLocalizationKey, isTrue);
        expect(preset.name, startsWith('preset.starter.'));
      }
    });

    test('each one actually establishes a context', () {
      for (final preset in starter) {
        expect(preset.draft.establishedDimensionCount, greaterThan(1),
            reason: preset.id);
      }
    });

    test('they are ordinary rows: nothing treats their ids as special', () {
      // A starter preset renamed becomes a user preset, which is what the
      // AppState rename path relies on.
      final renamed =
          starter.first.copyWith(name: 'My cafe', isStarter: false);
      expect(renamed.nameIsLocalizationKey, isFalse);
      expect(renamed.name, 'My cafe');
    });
  });

  group('v2 to v3 migration', () {
    test('the current version is at least 3', () {
      // v3 added context_presets; later versions add more. This test guards
      // the presets migration, so it only needs the floor, not an exact
      // number that every future migration would have to come and edit.
      expect(AppInfo.databaseVersion, greaterThanOrEqualTo(3));
    });

    test('a v1 file gains the presets table when it is upgraded', () async {
      // A real file on disk, not the in-memory path. An in-memory database
      // cannot be closed and reopened - and worse, reopening the shared
      // in-memory path hands back the database that is already open, so the
      // v1 file appeared to already have the v3 schema. Reopening is the
      // whole point of a migration test, so it needs a real directory, the
      // same arrangement test/database_test.dart uses.
      final temp = await Directory.systemTemp.createTemp('opencue-presets');
      addTearDown(() => temp.delete(recursive: true));
      final path = p.join(temp.path, 'opencue.db');

      final legacy = await AppDatabase.openLegacyV1ForTest(path);
      expect(await _tableNamesOf(legacy), isNot(contains('context_presets')));
      await legacy.close();

      final upgraded = await AppDatabase.open(path);
      expect(await _tableNames(upgraded), contains('context_presets'));
      expect(await upgraded.db.getVersion(), AppInfo.databaseVersion);
      await upgraded.close();
    });

    test('a fresh install has the presets table', () async {
      final fresh = await AppDatabase.openInMemory();
      expect(await _tableNames(fresh), contains('context_presets'));
      await fresh.close();
    });

    test('the presets table has every column the model writes', () async {
      final db = await AppDatabase.openInMemory();
      final columns = await AppDatabase.columnsOf(db.db, 'context_presets');
      expect(
        columns,
        containsAll(<String>[
          'id',
          'name',
          'draft',
          'is_favorite',
          'is_starter',
          'sort_order',
          'created_at',
          'last_used_at',
          'times_used',
        ]),
      );
      await db.close();
    });

    test('wipeAll clears presets too', () async {
      final db = await AppDatabase.openInMemory();
      final repository = SqliteContextPresetRepository(db.db);
      await repository.insertMany(const StarterPresets().load());
      expect(await repository.count(), 8);
      await db.wipeAll();
      expect(await repository.count(), 0);
      await db.close();
    });
  });

  group('SqliteContextPresetRepository', () {
    late AppDatabase db;
    late SqliteContextPresetRepository repository;

    setUp(() async {
      db = await AppDatabase.openInMemory();
      repository = SqliteContextPresetRepository(db.db);
    });

    tearDown(() => db.close());

    ContextPreset make(String id, {int order = 0, bool favorite = false}) =>
        ContextPreset(
          id: id,
          name: id,
          draft: ContextDraft.empty(),
          sortOrder: order,
          isFavorite: favorite,
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('insert, read back, and delete', () async {
      await repository.insert(make('a'));
      expect((await repository.getById('a'))?.name, 'a');
      await repository.delete('a');
      expect(await repository.getById('a'), isNull);
      expect(await repository.count(), 0);
    });

    test('favourites sort ahead of everything else', () async {
      await repository.insertMany(<ContextPreset>[
        make('first', order: 0),
        make('second', order: 1),
        make('starred', order: 9, favorite: true),
      ]);
      final all = await repository.getAll();
      expect(all.map((p) => p.id), <String>['starred', 'first', 'second']);
    });

    test('reorder rewrites sort_order from the given sequence', () async {
      await repository.insertMany(<ContextPreset>[
        make('a', order: 0),
        make('b', order: 1),
        make('c', order: 2),
      ]);
      await repository.reorder(<String>['c', 'a', 'b']);
      final all = await repository.getAll();
      expect(all.map((p) => p.id), <String>['c', 'a', 'b']);
    });

    test('setFavorite toggles without touching anything else', () async {
      await repository.insert(make('a'));
      await repository.setFavorite('a', isFavorite: true);
      final loaded = await repository.getById('a');
      expect(loaded!.isFavorite, isTrue);
      expect(loaded.name, 'a');
    });

    test('recentlyUsed excludes never-applied presets', () async {
      await repository.insertMany(<ContextPreset>[
        make('used'),
        make('never'),
      ]);
      await repository.markUsed('used');
      final recent = await repository.recentlyUsed();
      expect(recent.map((p) => p.id), <String>['used']);
      expect((await repository.getById('used'))!.timesUsed, 1);
    });

    test('recentlyUsed is newest first and honours the limit', () async {
      await repository.insertMany(<ContextPreset>[
        make('a'),
        make('b'),
        make('c'),
      ]);
      await repository.markUsed('a');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.markUsed('b');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.markUsed('c');

      final recent = await repository.recentlyUsed(limit: 2);
      expect(recent.map((p) => p.id), <String>['c', 'b']);
    });

    test('existingIds reports what is stored', () async {
      await repository.insertMany(<ContextPreset>[make('a'), make('b')]);
      expect(await repository.existingIds(), <String>{'a', 'b'});
    });
  });

  group('radial settings', () {
    test('defaults: automatic handedness, haptics on, tutorial unseen', () {
      const settings = AppSettings.defaults;
      expect(settings.radialHandedness, RadialHandedness.automatic);
      expect(settings.radialHapticsEnabled, isTrue);
      expect(settings.radialTutorialSeen, isFalse);
    });

    test('round-trips through JSON and the string map', () {
      const settings = AppSettings(
        radialHandedness: RadialHandedness.leftHanded,
        radialHapticsEnabled: false,
        radialTutorialSeen: true,
      );
      final viaJson = AppSettings.fromJson(settings.toJson());
      expect(viaJson.radialHandedness, RadialHandedness.leftHanded);
      expect(viaJson.radialHapticsEnabled, isFalse);
      expect(viaJson.radialTutorialSeen, isTrue);

      final viaMap = AppSettings.fromStringMap(settings.toStringMap());
      expect(viaMap.radialHandedness, RadialHandedness.leftHanded);
      expect(viaMap.radialHapticsEnabled, isFalse);
      expect(viaMap.radialTutorialSeen, isTrue);
    });

    test('an older settings row without the new keys keeps the defaults', () {
      // Haptics default to on, so an absent key must not read as false.
      final old = AppSettings.fromStringMap(<String, String>{
        'languageMode': 'bilingual',
        'defaultDirectness': '3',
      });
      expect(old.radialHapticsEnabled, isTrue);
      expect(old.radialHandedness, RadialHandedness.automatic);
      expect(old.defaultDirectness, 3);
    });

    test('an unknown handedness name falls back rather than throwing', () {
      final odd = AppSettings.fromStringMap(<String, String>{
        'radialHandedness': 'ambidextrous',
      });
      expect(odd.radialHandedness, RadialHandedness.automatic);
    });
  });
}

Future<List<String>> _tableNames(AppDatabase db) => _tableNamesOf(db.db);

/// Typed rather than dynamic: `strict-casts` is on in analysis_options.yaml.
Future<List<String>> _tableNamesOf(Database database) async {
  final rows = await database.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  return rows.map((row) => row['name']! as String).toList();
}
