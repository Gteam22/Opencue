import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/core/app_info.dart';
import 'package:opencue/data/db/app_database.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/interaction_record.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/repositories/library_query.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  setUpAll(AppDatabase.initialiseFfi);

  group('schema', () {
    test('a fresh database opens at the current version', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      expect(await stack.database.db.getVersion(), AppInfo.databaseVersion);
    });

    test('creates every table the app reads', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      final rows = await stack.database.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = rows.map((r) => r['name']! as String).toSet();
      expect(
        names,
        containsAll(<String>['opener_lines', 'interactions', 'settings']),
      );
    });

    test('enforces foreign keys, so no orphan interaction can be written',
        () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await expectLater(
        stack.service.interactions.insert(record('orphan', 'no-such-line')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('migration', () {
    // A real directory, because an in-memory database cannot be closed and
    // reopened, and reopening is the whole point of a migration test.
    late Directory temp;
    late String path;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('opencue-migration');
      path = p.join(temp.path, 'opencue.db');
    });

    tearDown(() => temp.delete(recursive: true));

    test('a v1 file upgrades to the current version and keeps its rows',
        () async {
      final legacy = await AppDatabase.openLegacyV1ForTest(path);
      expect(
        await AppDatabase.columnsOf(legacy, 'opener_lines'),
        isNot(contains('activities')),
      );
      // Written as a raw row because the v1 schema has no activities column,
      // so OpenerLine.toDbMap cannot be used here.
      await legacy.insert('opener_lines', <String, Object?>{
        'id': 'legacy-1',
        'japanese_text': '古いデータです。',
        'english_meaning': 'An old row.',
        'category': 'universal',
        'locations': 'cafe',
        'observable_cues': '',
        'group_sizes': 'alone',
        'noise_levels': 'normal',
        'tones': 'friendly',
        'directness': 2,
        'conditions': '',
        'avoid_conditions': '',
        'follow_up_suggestion': null,
        'notes': null,
        'is_favorite': 1,
        'is_user_created': 0,
        'created_at': testTime.toIso8601String(),
        'updated_at': testTime.toIso8601String(),
        'times_shown': 3,
        'times_used': 1,
        'positive_results': 1,
        'neutral_results': 0,
        'negative_results': 0,
      });
      await legacy.close();

      final upgraded = await AppDatabase.open(path);
      addTearDown(upgraded.close);

      expect(await upgraded.db.getVersion(), AppInfo.databaseVersion);
      expect(
        await AppDatabase.columnsOf(upgraded.db, 'opener_lines'),
        contains('activities'),
      );

      // The row must still be readable through the current model, which is the
      // property an upgrade actually has to preserve.
      final rows = await upgraded.db.query('opener_lines');
      expect(rows, hasLength(1));
      final restored = OpenerLine.fromDbRow(rows.single);
      expect(restored.id, 'legacy-1');
      expect(restored.japaneseText, '古いデータです。');
      expect(restored.locations, <LocationTag>{LocationTag.cafe});
      expect(restored.isFavorite, isTrue);
      expect(restored.timesShown, 3);
      expect(restored.activities, isEmpty);
    });

    test('a v1 upgrade produces the same columns as a fresh install',
        () async {
      // _createV1 is never edited in place; later versions are reached only
      // through _onUpgrade. This is the assertion that keeps the create path
      // and the upgrade path from drifting apart.
      final legacy = await AppDatabase.openLegacyV1ForTest(path);
      await legacy.close();
      final upgraded = await AppDatabase.open(path);
      final upgradedColumns =
          await AppDatabase.columnsOf(upgraded.db, 'opener_lines');
      await upgraded.close();

      final fresh = await AppDatabase.openInMemory();
      final freshColumns =
          await AppDatabase.columnsOf(fresh.db, 'opener_lines');
      await fresh.close();

      expect(upgradedColumns.toSet(), freshColumns.toSet());
    });

    test('opening an already-current file leaves the data alone', () async {
      // This is what happens on every ordinary launch, and after an installer
      // upgrade replaces the executable next to an existing database.
      final first = await AppDatabase.open(path);
      await first.db.insert('opener_lines', line('kept').toDbMap());
      await first.close();

      final second = await AppDatabase.open(path);
      addTearDown(second.close);
      final rows = await second.db.query('opener_lines');
      expect(rows, hasLength(1));
      expect(OpenerLine.fromDbRow(rows.single).id, 'kept');
      expect(await second.db.getVersion(), AppInfo.databaseVersion);
    });
  });

  group('OpenerLine repository', () {
    test('inserts, reads back, updates and deletes', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      final repo = stack.service.lines;

      await repo.insert(line('a', japanese: '最初の一言。'));
      expect(await repo.count(), 1);

      final fetched = await repo.getById('a');
      expect(fetched?.japaneseText, '最初の一言。');

      await repo.update(
        fetched!.copyWith(japaneseText: '書き換えた一言。', directness: 4),
      );
      final updated = await repo.getById('a');
      expect(updated?.japaneseText, '書き換えた一言。');
      expect(updated?.directness, 4);

      await repo.delete('a');
      expect(await repo.count(), 0);
      expect(await repo.getById('a'), isNull);
    });

    test('insertMany writes every line in one go', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insertMany(<OpenerLine>[
        line('a'),
        line('b'),
        line('c'),
      ]);
      expect(await stack.service.lines.count(), 3);
      expect(await stack.service.lines.existingIds(), <String>{'a', 'b', 'c'});
    });

    test('replaceAll clears what was there first', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insertMany(<OpenerLine>[line('old')]);
      await stack.service.lines.replaceAll(<OpenerLine>[
        line('new-1'),
        line('new-2'),
      ]);
      expect(
        await stack.service.lines.existingIds(),
        <String>{'new-1', 'new-2'},
      );
    });

    test('setFavorite touches only the favourite flag', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('fav'));
      await stack.service.lines.setFavorite('fav', isFavorite: true);
      final after = await stack.service.lines.getById('fav');
      expect(after?.isFavorite, isTrue);
      expect(after?.timesUsed, 0);
    });

    test('recordOutcome moves the right counters', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('counted'));
      await stack.service.lines.recordOutcome(
        'counted',
        InteractionOutcome.positive,
      );
      await stack.service.lines.recordOutcome(
        'counted',
        InteractionOutcome.unreceptive,
      );
      final after = await stack.service.lines.getById('counted');
      expect(after?.timesUsed, 2);
      expect(after?.positiveResults, 1);
      expect(after?.negativeResults, 1);
    });

    test('a not-recorded outcome counts as a use but not as a result',
        () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('unrecorded'));
      await stack.service.lines.recordOutcome(
        'unrecorded',
        InteractionOutcome.notRecorded,
      );
      final after = await stack.service.lines.getById('unrecorded');
      expect(after?.timesUsed, 1);
      expect(after?.recordedOutcomes, 0);
    });

    test('incrementTimesShown does not count as a use', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('shown'));
      await stack.service.lines.incrementTimesShown(<String>['shown']);
      await stack.service.lines.incrementTimesShown(<String>['shown']);
      final after = await stack.service.lines.getById('shown');
      expect(after?.timesShown, 2);
      expect(after?.timesUsed, 0);
    });
  });

  group('search and filter', () {
    Future<TestStack> seeded() async {
      final stack = await TestStack.create();
      await stack.service.lines.insertMany(<OpenerLine>[
        line(
          'bar-playful',
          japanese: 'それ、何飲んでるんですか？',
          english: 'What are you drinking?',
          category: LineCategory.bar,
          locations: <LocationTag>{LocationTag.bar},
          cues: <ObservableCue>{ObservableCue.drink},
          tones: <Tone>{Tone.playful},
        ),
        line(
          'cafe-safe',
          japanese: 'ここ、雰囲気いいですよね。',
          english: 'This place has a nice atmosphere.',
          category: LineCategory.cafe,
          locations: <LocationTag>{LocationTag.cafe},
          tones: <Tone>{Tone.safe},
          directness: 1,
          isFavorite: true,
        ),
        line(
          'direct-street',
          japanese: '率直に言うと、すごくタイプです。',
          english: 'Honestly, you are very much my type.',
          category: LineCategory.streetOrShopping,
          locations: <LocationTag>{LocationTag.street},
          tones: <Tone>{Tone.direct},
          directness: 5,
          isUserCreated: false,
        ),
      ]);
      return stack;
    }

    test('matches Japanese text', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(searchText: '雰囲気'),
      );
      expect(results.map((l) => l.id), <String>['cafe-safe']);
    });

    test('matches English meaning case-insensitively', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(searchText: 'DRINKING'),
      );
      expect(results.map((l) => l.id), <String>['bar-playful']);
    });

    test('an empty query returns everything', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(const LibraryQuery());
      expect(results, hasLength(3));
    });

    test('filters by location', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(locations: <LocationTag>{LocationTag.cafe}),
      );
      expect(results.map((l) => l.id), <String>['cafe-safe']);
    });

    test('filters by cue', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(cues: <ObservableCue>{ObservableCue.drink}),
      );
      expect(results.map((l) => l.id), <String>['bar-playful']);
    });

    test('filters by tone', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(tones: <Tone>{Tone.direct}),
      );
      expect(results.map((l) => l.id), <String>['direct-street']);
    });

    test('filters by favourites', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(favoritesOnly: true),
      );
      expect(results.map((l) => l.id), <String>['cafe-safe']);
    });

    test('filters by directness range', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(minDirectness: 3, maxDirectness: 5),
      );
      expect(results.map((l) => l.id), <String>['direct-street']);
    });

    test('filters to user-created lines only', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(userCreatedOnly: true),
      );
      expect(
        results.map((l) => l.id).toSet(),
        <String>{'bar-playful', 'cafe-safe'},
      );
    });

    test('combines filters conjunctively', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(
          locations: <LocationTag>{LocationTag.bar},
          tones: <Tone>{Tone.safe},
        ),
      );
      expect(results, isEmpty);
    });

    test('sorts alphabetically by Japanese text', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      final results = await stack.service.lines.query(
        const LibraryQuery(sort: LibrarySort.alphabetical),
      );
      final texts = results.map((l) => l.japaneseText).toList();
      final sorted = <String>[...texts]..sort();
      expect(texts, sorted);
    });

    test('sorts most-used first', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      await stack.service.lines.recordOutcome(
        'cafe-safe',
        InteractionOutcome.positive,
      );
      final results = await stack.service.lines.query(
        const LibraryQuery(sort: LibrarySort.mostUsed),
      );
      expect(results.first.id, 'cafe-safe');
    });

    test('a line with real history leads the positive-history sort', () async {
      final stack = await seeded();
      addTearDown(stack.dispose);
      for (var i = 0; i < 3; i++) {
        await stack.service.lines.recordOutcome(
          'bar-playful',
          InteractionOutcome.positive,
        );
      }
      final results = await stack.service.lines.query(
        const LibraryQuery(sort: LibrarySort.highestPositiveHistory),
      );
      expect(results.first.id, 'bar-playful');
    });
  });

  group('interaction repository', () {
    test('stores and reads records newest first', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('a'));
      await stack.service.interactions.insert(
        record('r1', 'a', when: DateTime.utc(2026, 1, 1)),
      );
      await stack.service.interactions.insert(
        record('r2', 'a', when: DateTime.utc(2026, 2, 1)),
      );
      final all = await stack.service.interactions.getAll();
      expect(all.map((r) => r.id), <String>['r2', 'r1']);
    });

    test('honours the limit', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('a'));
      await stack.service.interactions.insertMany(<InteractionRecord>[
        record('r1', 'a', when: DateTime.utc(2026, 1, 1)),
        record('r2', 'a', when: DateTime.utc(2026, 2, 1)),
        record('r3', 'a', when: DateTime.utc(2026, 3, 1)),
      ]);
      final limited = await stack.service.interactions.getAll(limit: 2);
      expect(limited.map((r) => r.id), <String>['r3', 'r2']);
    });

    test('deleting a line cascades to its records', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('doomed'));
      await stack.service.interactions.insert(record('r', 'doomed'));
      expect(await stack.service.interactions.count(), 1);
      await stack.service.lines.delete('doomed');
      expect(await stack.service.interactions.count(), 0);
    });

    test('getForLine returns only that line records', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insertMany(<OpenerLine>[line('a'), line('b')]);
      await stack.service.interactions.insertMany(<InteractionRecord>[
        record('r1', 'a'),
        record('r2', 'b'),
      ]);
      final forA = await stack.service.interactions.getForLine('a');
      expect(forA.map((r) => r.id), <String>['r1']);
    });

    test('round-trips the context snapshot through storage', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('a'));
      await stack.service.interactions.insert(
        record(
          'r',
          'a',
          context: situation(
            location: LocationTag.festival,
            noiseLevel: NoiseLevel.loud,
            cues: <ObservableCue>{ObservableCue.festivalItem},
          ),
          notes: 'Waiting for the fireworks.',
        ),
      );
      final stored = (await stack.service.interactions.getAll()).single;
      expect(stored.contextSnapshot?.location, LocationTag.festival);
      expect(stored.contextSnapshot?.noiseLevel, NoiseLevel.loud);
      expect(
        stored.contextSnapshot?.observableCues,
        <ObservableCue>{ObservableCue.festivalItem},
      );
      expect(stored.optionalNotes, 'Waiting for the fireworks.');
    });
  });

  group('settings repository', () {
    test('returns defaults on a database that has never been written',
        () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      final loaded = await stack.service.settings.load();
      expect(loaded.languageMode, AppSettings.defaults.languageMode);
      expect(loaded.themePreference, AppSettings.defaults.themePreference);
    });

    test('saves and reloads', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.settings.save(
        const AppSettings(
          languageMode: LanguageMode.japanese,
          themePreference: AppThemePreference.dark,
          defaultDirectness: 5,
          includeHistoryInExport: true,
        ),
      );
      final loaded = await stack.service.settings.load();
      expect(loaded.languageMode, LanguageMode.japanese);
      expect(loaded.themePreference, AppThemePreference.dark);
      expect(loaded.defaultDirectness, 5);
      expect(loaded.includeHistoryInExport, isTrue);
    });

    test('saving twice updates rather than duplicating rows', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.settings.save(
        AppSettings.defaults.copyWith(defaultDirectness: 3),
      );
      await stack.service.settings.save(
        AppSettings.defaults.copyWith(defaultDirectness: 4),
      );
      expect((await stack.service.settings.load()).defaultDirectness, 4);
      final rows = await stack.database.db.query('settings');
      final keys = rows.map((r) => r['key']).toSet();
      expect(keys.length, rows.length);
    });
  });
}
