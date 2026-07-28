import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/app.dart';
import 'package:opencue/data/db/app_database.dart';
import 'package:opencue/data/library_service.dart';
import 'package:opencue/data/repositories/sqlite_repositories.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/features/shared/app_scope.dart';
import 'package:opencue/l10n/strings_en.dart';

import 'helpers.dart';

void main() {
  setUpAll(AppDatabase.initialiseFfi);

  /// Builds a live app over an in-memory database.
  ///
  /// Nothing is stubbed: the widgets talk to the real repositories and the real
  /// recommendation engine, so this exercises the actual wiring rather than a
  /// parallel test-only assembly.
  ///
  /// sqflite_common_ffi runs every database operation on a background isolate.
  /// flutter_test's default zone only understands Dart's simulated Timers and
  /// microtasks, not a reply arriving from a real isolate, so a plain `await`
  /// on that work — or a plain `pumpAndSettle()` waiting on it — never
  /// completes; it eventually fails with a ten-minute timeout instead of the
  /// few milliseconds the work actually takes. `tester.runAsync` steps outside
  /// that simulated zone for exactly the calls that need real time to pass.
  Future<AppState> pumpApp(
    WidgetTester tester, {
    List<OpenerLine> preload = const <OpenerLine>[],
    bool seed = false,
  }) async {
    late final AppDatabase database;
    late final LibraryService service;

    await tester.runAsync(() async {
      database = await AppDatabase.openInMemory();
      service = LibraryService(
        lines: SqliteOpenerLineRepository(database.db),
        interactions: SqliteInteractionRepository(database.db),
        settings: SqliteSettingsRepository(database.db),
      );
      if (preload.isNotEmpty) {
        await service.lines.insertMany(preload);
      }
      if (seed) {
        await service.seedIfEmpty();
      }
    });
    addTearDown(database.close);

    final state = AppState(service: service);
    addTearDown(state.dispose);
    await tester.pumpWidget(OpenCueApp(state: state));

    // OpenCueApp.initState() kicks off state.bootstrap() itself, which does
    // the same kind of real database I/O. Poll for it to finish inside
    // runAsync, capped well short of pumpAndSettle's own ten-minute timeout so
    // a genuine problem fails fast with a clear reason instead of a
    // stack-trace-only timeout.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (state.isLoading && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(
      state.isLoading,
      isFalse,
      reason: 'AppState never finished bootstrapping within 20s',
    );
    await settle(tester);
    return state;
  }

  /// Drop-in replacement for `tester.pumpAndSettle()` after an action that
  /// touches the database (a tap that saves, deletes, favourites, records an
  /// outcome, and so on). See the comment on [pumpApp] for why the plain
  /// version hangs instead of completing.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
  }

  group('startup', () {
    testWidgets('an empty database seeds itself and shows the home screen',
        (tester) async {
      final state = await pumpApp(tester);

      expect(find.text('OpenCue'), findsWidgets);
      expect(find.text(stringsEn['home.findLine']!), findsOneWidget);
      // seedIfEmpty runs during bootstrap, so a first launch is never a blank
      // library the user has to populate by hand.
      expect(state.lineCount, greaterThanOrEqualTo(60));
    });

    testWidgets('a database that already holds the starter library opens',
        (tester) async {
      final state = await pumpApp(tester, seed: true);
      expect(find.text(stringsEn['home.browseLibrary']!), findsOneWidget);
      expect(state.lineCount, greaterThanOrEqualTo(60));
    });

    testWidgets('a database holding only the user own line is left alone',
        (tester) async {
      final state = await pumpApp(
        tester,
        preload: <OpenerLine>[line('mine', japanese: '自分の一言。')],
      );
      expect(state.lineCount, 1);
      expect(find.text(stringsEn['home.findLine']!), findsOneWidget);
    });

    testWidgets('the scan tile is present, labelled and not tappable',
        (tester) async {
      await pumpApp(tester, preload: <OpenerLine>[line('a')]);
      expect(find.text(stringsEn['home.scan']!), findsOneWidget);
      expect(find.text(stringsEn['home.scanPlanned']!), findsOneWidget);
      // Nothing in the tile is a button, so there is no way to trigger a
      // permission prompt for a feature this build does not have.
      final tile = find.ancestor(
        of: find.text(stringsEn['home.scan']!),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: tile, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
    });

    testWidgets('the recent section starts empty', (tester) async {
      await pumpApp(tester, preload: <OpenerLine>[line('a')]);
      expect(find.text(stringsEn['home.recentEmpty']!), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('reaches the library and lists lines', (tester) async {
      await pumpApp(
        tester,
        preload: <OpenerLine>[
          line('a', japanese: 'ライブラリの一言です。'),
        ],
      );

      await tester.tap(find.text(stringsEn['home.browseLibrary']!));
      await settle(tester);

      expect(find.text('ライブラリの一言です。'), findsOneWidget);
    });

    testWidgets('reaches favourites and filters to them', (tester) async {
      await pumpApp(
        tester,
        preload: <OpenerLine>[
          line('plain', japanese: 'ふつうの一言。'),
          line('starred', japanese: 'お気に入りの一言。', isFavorite: true),
        ],
      );

      await tester.tap(find.text(stringsEn['home.favorites']!));
      await settle(tester);

      expect(find.text('お気に入りの一言。'), findsOneWidget);
      expect(find.text('ふつうの一言。'), findsNothing);
    });

    testWidgets('reaches settings and the privacy screen', (tester) async {
      await pumpApp(tester, preload: <OpenerLine>[line('a')]);

      await tester.tap(find.text(stringsEn['nav.settings']!).last);
      await settle(tester);
      expect(find.text(stringsEn['settings.language']!), findsOneWidget);

      await tester.tap(find.text(stringsEn['settings.about']!).last);
      await settle(tester);
      expect(find.text(stringsEn['about.privacyNoCamera']!), findsOneWidget);
    });
  });

  group('the recommendation flow end to end', () {
    testWidgets('a described situation produces suggestions', (tester) async {
      await pumpApp(
        tester,
        preload: <OpenerLine>[
          line(
            'bar-line',
            japanese: 'ここ、いい雰囲気ですね。',
            locations: <LocationTag>{LocationTag.bar},
          ),
        ],
      );

      await tester.tap(find.text(stringsEn['home.findLine']!));
      await settle(tester);
      expect(find.text(stringsEn['context.title']!), findsOneWidget);

      await tester.tap(find.text(stringsEn['location.bar']!));
      await settle(tester);

      await tester.tap(find.text(stringsEn['context.showSuggestions']!));
      await settle(tester);

      expect(find.text('ここ、いい雰囲気ですね。'), findsOneWidget);
      expect(find.text(stringsEn['rec.category.safest']!), findsOneWidget);
      expect(find.text(stringsEn['advisory.title']!), findsNothing);
    });

    testWidgets('an unsuitable moment shows the warning and no openers',
        (tester) async {
      await pumpApp(
        tester,
        preload: <OpenerLine>[
          line(
            'cafe-line',
            japanese: 'ここ、雰囲気いいですよね。',
            locations: <LocationTag>{LocationTag.cafe},
          ),
        ],
      );

      await tester.tap(find.text(stringsEn['home.findLine']!));
      await settle(tester);
      await tester.tap(find.text(stringsEn['location.cafe']!));
      await settle(tester);

      // Switch on "appears to be working", one of the five hard conditions.
      final workingSwitch = find.ancestor(
        of: find.text(stringsEn['context.isWorking']!),
        matching: find.byType(SwitchListTile),
      );
      await tester.scrollUntilVisible(workingSwitch, 200);
      await tester.tap(workingSwitch);
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text(stringsEn['context.showSuggestions']!),
        200,
      );
      await tester.tap(find.text(stringsEn['context.showSuggestions']!));
      await settle(tester);

      expect(find.text(stringsEn['advisory.title']!), findsOneWidget);
      // The specific triggering condition must be named, not just the warning.
      expect(
        find.textContaining(stringsEn['avoid.personWorking']!),
        findsWidgets,
      );
      expect(find.text('ここ、雰囲気いいですよね。'), findsNothing);
    });

    testWidgets('recording an outcome persists and reaches the home screen',
        (tester) async {
      final state = await pumpApp(
        tester,
        preload: <OpenerLine>[
          line(
            'bar-line',
            japanese: 'ここ、いい雰囲気ですね。',
            locations: <LocationTag>{LocationTag.bar},
          ),
        ],
      );

      await tester.tap(find.text(stringsEn['home.findLine']!));
      await settle(tester);
      await tester.tap(find.text(stringsEn['location.bar']!));
      await settle(tester);
      await tester.tap(find.text(stringsEn['context.showSuggestions']!));
      await settle(tester);

      await tester.tap(find.text(stringsEn['action.usedThisLine']!));
      await settle(tester);

      await tester.tap(find.text(stringsEn['outcome.positive']!));
      await settle(tester);
      await tester.tap(find.text(stringsEn['action.save']!));
      await settle(tester);

      expect(state.history, hasLength(1));
      expect(state.history.single.outcome, InteractionOutcome.positive);
      expect(state.lineById('bar-line')?.positiveResults, 1);

      // And it survives a reload from storage, which is what "persists after
      // restart" comes down to.
      await state.reload();
      expect(state.history, hasLength(1));
    });
  });

  group('library editing', () {
    testWidgets('a new line can be written and appears in the list',
        (tester) async {
      final state = await pumpApp(tester, preload: <OpenerLine>[line('a')]);

      await tester.tap(find.text(stringsEn['home.browseLibrary']!));
      await settle(tester);
      await tester.tap(find.text(stringsEn['action.addLine']!).first);
      await settle(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        '書いてみた一言です。',
      );
      await settle(tester);
      await tester.tap(find.text(stringsEn['action.save']!));
      await settle(tester);

      expect(state.lineCount, 2);
      expect(find.text('書いてみた一言です。'), findsOneWidget);
    });

    testWidgets('a line with no Japanese text is refused', (tester) async {
      final state = await pumpApp(tester, preload: <OpenerLine>[line('a')]);

      await tester.tap(find.text(stringsEn['home.browseLibrary']!));
      await settle(tester);
      await tester.tap(find.text(stringsEn['action.addLine']!).first);
      await settle(tester);
      await tester.tap(find.text(stringsEn['action.save']!));
      await settle(tester);

      expect(state.lineCount, 1);
      expect(
        find.text(stringsEn['validation.japaneseRequired']!),
        findsWidgets,
      );
    });

    testWidgets('favouriting from the library persists', (tester) async {
      final state = await pumpApp(
        tester,
        preload: <OpenerLine>[line('a', japanese: '星をつける一言。')],
      );

      await tester.tap(find.text(stringsEn['home.browseLibrary']!));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.star_outline).first);
      await settle(tester);

      expect(state.lineById('a')?.isFavorite, isTrue);
    });

    testWidgets('deleting asks first and can be cancelled', (tester) async {
      final state = await pumpApp(
        tester,
        preload: <OpenerLine>[line('a', japanese: '消される一言。')],
      );

      await tester.tap(find.text(stringsEn['home.browseLibrary']!));
      await settle(tester);
      await tester.tap(find.text('消される一言。'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);

      expect(find.text(stringsEn['library.deleteTitle']!), findsOneWidget);
      await tester.tap(find.text(stringsEn['action.cancel']!));
      await settle(tester);

      expect(state.lineCount, 1);
    });
  });

  group('search', () {
    testWidgets('narrows the list as you type', (tester) async {
      await pumpApp(
        tester,
        preload: <OpenerLine>[
          line('a', japanese: '海の話をしましょう。', english: 'Talk about the sea.'),
          line('b', japanese: '山の話をしましょう。', english: 'Talk about mountains.'),
        ],
      );

      await tester.tap(find.text(stringsEn['home.browseLibrary']!));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '海');
      await settle(tester);

      expect(find.text('海の話をしましょう。'), findsOneWidget);
      expect(find.text('山の話をしましょう。'), findsNothing);
    });
  });
}
