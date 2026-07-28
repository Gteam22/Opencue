import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/data/db/app_database.dart';
import 'package:opencue/data/seed/seed_loader.dart';
import 'package:opencue/data/statistics_service.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/interaction_record.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/recommendation/recommendation_engine.dart';

import 'helpers.dart';

void main() {
  setUpAll(AppDatabase.initialiseFfi);

  group('starter library', () {
    const loader = SeedLoader();

    test('parses and meets the size the specification asks for', () {
      final lines = loader.load();
      expect(lines.length, greaterThanOrEqualTo(60));
    });

    test('every line is valid by the model own rules', () {
      for (final seeded in loader.load()) {
        expect(
          seeded.validationErrors(),
          isEmpty,
          reason: '${seeded.id}: ${seeded.japaneseText}',
        );
      }
    });

    test('has no duplicate ids and no duplicate Japanese text', () {
      final lines = loader.load();
      final ids = lines.map((l) => l.id).toList();
      final texts = lines.map((l) => l.japaneseText).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(texts.toSet(), hasLength(texts.length));
    });

    test('every line carries an English meaning', () {
      for (final seeded in loader.load()) {
        expect(seeded.englishMeaning, isNotNull, reason: seeded.id);
        expect(seeded.englishMeaning, isNotEmpty, reason: seeded.id);
      }
    });

    test('is marked as not user-created, so it can be restored', () {
      expect(loader.load().every((l) => !l.isUserCreated), isTrue);
    });

    test('spans the situations the specification lists', () {
      final categories = loader.load().map((l) => l.category).toSet();
      expect(
        categories,
        containsAll(<LineCategory>[
          LineCategory.universal,
          LineCategory.eyeContactEstablished,
          LineCategory.cafe,
          LineCategory.bar,
          LineCategory.standingBar,
          LineCategory.club,
          LineCategory.streetOrShopping,
          LineCategory.parkOrWaterfront,
          LineCategory.festival,
          LineCategory.cosplayEvent,
          LineCategory.concert,
          LineCategory.fitnessClass,
          LineCategory.meetupOrLanguageExchange,
          LineCategory.waitingLine,
          LineCategory.weather,
          LineCategory.withOneFriend,
          LineCategory.gracefulExit,
        ]),
      );
    });

    test('includes the four graceful exits the specification names', () {
      final texts = loader.load().map((l) => l.japaneseText).toSet();
      expect(texts, contains('すみません、急に声かけて。よい一日を。'));
      expect(texts, contains('邪魔してすみません。楽しんでください。'));
      expect(texts, contains('話してくれてありがとうございました。'));
      expect(texts, contains('では、よい夜を。'));
    });

    test('every exit line sits in its own quickly reachable category', () {
      final exits = loader.load().where((l) => l.isExitLine).toList();
      expect(exits.length, greaterThanOrEqualTo(4));
      expect(exits.every((l) => l.category == LineCategory.gracefulExit),
          isTrue);
    });

    test('exit lines work in any venue, so they are always available', () {
      // Someone needing to leave gracefully should never be told that no exit
      // fits the room.
      const engine = RecommendationEngine();
      for (final location in LocationTag.values) {
        final result = engine.recommend(
          context: situation(location: location),
          library: loader.load(),
        );
        expect(
          result.exitLines,
          isNotEmpty,
          reason: 'no exit line offered at ${location.name}',
        );
      }
    });

    test('produces suggestions for every location it claims to cover', () {
      const engine = RecommendationEngine();
      final library = loader.load();
      for (final location in LocationTag.values) {
        final result = engine.recommend(
          context: situation(location: location),
          library: library,
        );
        expect(
          result.primary,
          isNotEmpty,
          reason: 'no suggestion at ${location.name}',
        );
      }
    });
  });

  group('seeding', () {
    test('an empty database gets the starter library', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      final inserted = await stack.service.seedIfEmpty();
      expect(inserted, greaterThanOrEqualTo(60));
      expect(await stack.service.lines.count(), inserted);
    });

    test('seeding a second time does nothing', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      final first = await stack.service.seedIfEmpty();
      final second = await stack.service.seedIfEmpty();
      expect(second, 0);
      expect(await stack.service.lines.count(), first);
    });

    test('a database holding only the user own line is not re-seeded',
        () async {
      // Someone who deleted the starter lines on purpose should not have them
      // reappear on the next launch.
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('mine'));
      expect(await stack.service.seedIfEmpty(), 0);
      expect(await stack.service.lines.count(), 1);
    });
  });

  group('restore starter library', () {
    test('puts back a deleted starter line', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.seedIfEmpty();
      final all = await stack.service.lines.getAll();
      final victim = all.first;
      await stack.service.lines.delete(victim.id);

      final restored = await stack.service.restoreStarterLibrary();

      expect(restored, 1);
      expect(await stack.service.lines.getById(victim.id), isNotNull);
    });

    test('leaves the user own lines untouched', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.seedIfEmpty();
      await stack.service.lines.insert(line('mine', japanese: '自分の一言。'));
      await stack.service.restoreStarterLibrary();
      final mine = await stack.service.lines.getById('mine');
      expect(mine?.japaneseText, '自分の一言。');
    });

    test('does not overwrite an edited starter line by default', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.seedIfEmpty();
      final original = (await stack.service.lines.getAll()).first;
      await stack.service.lines.update(
        original.copyWith(japaneseText: '自分で書き換えました。'),
      );

      await stack.service.restoreStarterLibrary();

      final after = await stack.service.lines.getById(original.id);
      expect(after?.japaneseText, '自分で書き換えました。');
    });

    test('overwriteEdited restores the original wording', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.seedIfEmpty();
      final original = (await stack.service.lines.getAll()).first;
      await stack.service.lines.update(
        original.copyWith(japaneseText: '自分で書き換えました。'),
      );

      await stack.service.restoreStarterLibrary(overwriteEdited: true);

      final after = await stack.service.lines.getById(original.id);
      expect(after?.japaneseText, original.japaneseText);
    });
  });

  group('recording usage', () {
    test('writes the log entry and the counters together', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('used'));
      final target = (await stack.service.lines.getById('used'))!;

      await stack.service.recordUsage(
        line: target,
        outcome: InteractionOutcome.positive,
        notes: 'Went well.',
        contextSnapshot: situation(location: LocationTag.bar),
      );

      final after = await stack.service.lines.getById('used');
      expect(after?.timesUsed, 1);
      expect(after?.positiveResults, 1);

      final history = await stack.service.interactions.getAll();
      expect(history, hasLength(1));
      expect(history.single.optionalNotes, 'Went well.');
      expect(history.single.contextSnapshot?.location, LocationTag.bar);
    });

    test('clearing history also resets the counters', () async {
      // Otherwise the statistics screen would report uses with no records
      // behind them, and the two views would contradict each other.
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      await stack.service.lines.insert(line('used'));
      final target = (await stack.service.lines.getById('used'))!;
      await stack.service.recordUsage(
        line: target,
        outcome: InteractionOutcome.positive,
      );
      await stack.service.noteShown(<String>['used']);

      await stack.service.clearInteractionHistory();

      final after = await stack.service.lines.getById('used');
      expect(await stack.service.interactions.count(), 0);
      expect(after?.timesUsed, 0);
      expect(after?.timesShown, 0);
      expect(after?.positiveResults, 0);
    });
  });

  group('duplicate', () {
    test('copies the content and marks the copy as the user own', () async {
      final stack = await TestStack.create();
      addTearDown(stack.dispose);
      final source = line(
        'seeded',
        japanese: '元の一言です。',
        isUserCreated: false,
        timesUsed: 5,
        positive: 5,
      );
      await stack.service.lines.insert(source);

      final copy = await stack.service.duplicate(source);

      expect(copy.id, isNot(source.id));
      expect(copy.japaneseText, source.japaneseText);
      expect(copy.isUserCreated, isTrue);
      // History belongs to the original line, not to a fresh copy of it.
      expect(copy.timesUsed, 0);
      expect(copy.positiveResults, 0);
      expect(await stack.service.lines.count(), 2);
    });
  });

  group('statistics', () {
    const stats = StatisticsService();

    test('are empty on a fresh install', () {
      final computed = stats.compute(
        lines: <OpenerLine>[line('a')],
        interactions: const <InteractionRecord>[],
      );
      expect(computed.isEmpty, isTrue);
      expect(computed.recordedOutcomeCount, 0);
    });

    test('sums views and uses across the library', () {
      final computed = stats.compute(
        lines: <OpenerLine>[
          line('a', timesShown: 4, timesUsed: 1),
          line('b', timesShown: 2, timesUsed: 2),
        ],
        interactions: const <InteractionRecord>[],
      );
      expect(computed.totalSuggestionsViewed, 6);
      expect(computed.totalLinesUsed, 3);
    });

    test('withholds proportions on a small sample', () {
      final computed = stats.compute(
        lines: <OpenerLine>[line('a', timesUsed: 1, positive: 1)],
        interactions: <InteractionRecord>[record('r', 'a')],
      );
      expect(computed.hasEnoughForRates, isFalse);
      expect(computed.rateFor(InteractionOutcome.positive), isNull);
    });

    test('reports proportions once the sample is large enough', () {
      final interactions = <InteractionRecord>[
        for (var i = 0; i < 8; i++)
          record(
            'r$i',
            'a',
            outcome: i < 6
                ? InteractionOutcome.positive
                : InteractionOutcome.neutral,
          ),
      ];
      final computed = stats.compute(
        lines: <OpenerLine>[line('a')],
        interactions: interactions,
      );
      expect(computed.hasEnoughForRates, isTrue);
      expect(
        computed.rateFor(InteractionOutcome.positive),
        closeTo(0.75, 1e-9),
      );
    });

    test('does not count a not-recorded outcome towards the sample', () {
      final computed = stats.compute(
        lines: <OpenerLine>[line('a')],
        interactions: <InteractionRecord>[
          for (var i = 0; i < 10; i++)
            record('r$i', 'a', outcome: InteractionOutcome.notRecorded),
        ],
      );
      expect(computed.recordedOutcomeCount, 0);
      expect(computed.hasEnoughForRates, isFalse);
    });

    test('ranks locations by how often they were actually used', () {
      final computed = stats.compute(
        lines: <OpenerLine>[line('a')],
        interactions: <InteractionRecord>[
          record('r1', 'a', context: situation(location: LocationTag.bar)),
          record('r2', 'a', context: situation(location: LocationTag.bar)),
          record('r3', 'a', context: situation(location: LocationTag.cafe)),
        ],
      );
      expect(computed.topLocations.first.key, LocationTag.bar);
      expect(computed.topLocations.first.count, 2);
    });

    test('derives tone popularity from usage, not from library shape', () {
      // A library with fifty safe lines and one playful one should not report
      // "safe" as the favourite tone if only the playful one is ever used.
      final computed = stats.compute(
        lines: <OpenerLine>[
          for (var i = 0; i < 5; i++)
            line('safe-$i', tones: <Tone>{Tone.safe}),
          line('playful', tones: <Tone>{Tone.playful}),
        ],
        interactions: <InteractionRecord>[
          record('r1', 'playful'),
          record('r2', 'playful'),
        ],
      );
      expect(computed.topTones.first.key, Tone.playful);
    });

    test('withholds a per-line ranking until there is enough history', () {
      final computed = stats.compute(
        lines: <OpenerLine>[line('a', timesUsed: 3, positive: 3)],
        interactions: <InteractionRecord>[
          for (var i = 0; i < 3; i++) record('r$i', 'a'),
        ],
      );
      expect(computed.bestLines, isEmpty);
    });

    test('ranks lines once there is enough history', () {
      final lines = <OpenerLine>[
        line('good', timesUsed: 6, positive: 6),
        line('poor', timesUsed: 6, negative: 6),
      ];
      final interactions = <InteractionRecord>[
        for (var i = 0; i < 6; i++) record('g$i', 'good'),
        for (var i = 0; i < 6; i++)
          record('p$i', 'poor', outcome: InteractionOutcome.unreceptive),
      ];
      final computed = stats.compute(lines: lines, interactions: interactions);
      expect(computed.bestLines.first.id, 'good');
    });

    test('tolerates a record whose line has been deleted', () {
      final computed = stats.compute(
        lines: <OpenerLine>[line('a')],
        interactions: <InteractionRecord>[record('r', 'deleted-line')],
      );
      expect(computed.recordedOutcomeCount, 1);
    });
  });
}
