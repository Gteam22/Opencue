// Regression tests for the library filter dimensions.
//
// `OpenerLine` has always carried `activities`, `groupSizes` and
// `noiseLevels`, but `LibraryQuery` could not filter on any of them, so three
// tagged dimensions of every line were invisible to search. These tests pin
// the behaviour so the gap cannot reopen, and assert alongside it that the
// dimensions that were already filterable still are.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/repositories/library_query.dart';

import 'helpers.dart';

void main() {
  // A small library in which each line is distinguishable on exactly one
  // dimension, so a filter that matches the wrong field fails loudly.
  final library = <OpenerLine>[
    line(
      'cafe-quiet-solo',
      japanese: 'ここ、雰囲気いいですよね。',
      english: 'This place has a nice atmosphere.',
      category: LineCategory.cafe,
      locations: <LocationTag>{LocationTag.cafe},
      activities: <ActivityTag>{ActivityTag.drinking},
      groupSizes: <GroupSize>{GroupSize.alone},
      noiseLevels: <NoiseLevel>{NoiseLevel.quiet},
      cues: <ObservableCue>{ObservableCue.drink},
      tones: <Tone>{Tone.situational},
      directness: 1,
      isFavorite: true,
    ),
    line(
      'club-loud-group',
      japanese: 'その曲、最高ですね！',
      english: 'This song is amazing!',
      category: LineCategory.club,
      locations: <LocationTag>{LocationTag.club},
      activities: <ActivityTag>{ActivityTag.dancing},
      groupSizes: <GroupSize>{GroupSize.smallGroup, GroupSize.largeGroup},
      noiseLevels: <NoiseLevel>{NoiseLevel.veryLoud},
      cues: <ObservableCue>{ObservableCue.music},
      tones: <Tone>{Tone.playful},
      directness: 3,
    ),
    line(
      'station-waiting-pair',
      japanese: '今日、電車かなり混んでますね。',
      english: 'The trains are really crowded today.',
      category: LineCategory.transport,
      locations: <LocationTag>{LocationTag.trainStation},
      activities: <ActivityTag>{ActivityTag.waiting},
      groupSizes: <GroupSize>{GroupSize.withOneFriend},
      noiseLevels: <NoiseLevel>{NoiseLevel.normal},
      cues: <ObservableCue>{ObservableCue.waiting},
      tones: <Tone>{Tone.safe},
      directness: 1,
      isUserCreated: false,
    ),
  ];

  List<String> idsFor(LibraryQuery query) =>
      query.applyTo(library).map((l) => l.id).toList()..sort();

  group('restored filter dimensions', () {
    test('activity filter selects only lines tagged with that activity', () {
      expect(
        idsFor(const LibraryQuery(activities: <ActivityTag>{
          ActivityTag.dancing,
        })),
        <String>['club-loud-group'],
      );
    });

    test('activity filter is a union, not an intersection', () {
      expect(
        idsFor(const LibraryQuery(activities: <ActivityTag>{
          ActivityTag.dancing,
          ActivityTag.waiting,
        })),
        <String>['club-loud-group', 'station-waiting-pair'],
      );
    });

    test('group-size filter selects only lines tagged for that size', () {
      expect(
        idsFor(const LibraryQuery(groupSizes: <GroupSize>{
          GroupSize.withOneFriend,
        })),
        <String>['station-waiting-pair'],
      );
    });

    test('group-size filter matches a line tagged for several sizes', () {
      expect(
        idsFor(const LibraryQuery(groupSizes: <GroupSize>{
          GroupSize.largeGroup,
        })),
        <String>['club-loud-group'],
      );
    });

    test('noise filter selects only lines tagged for that level', () {
      expect(
        idsFor(const LibraryQuery(noiseLevels: <NoiseLevel>{
          NoiseLevel.quiet,
        })),
        <String>['cafe-quiet-solo'],
      );
    });

    test('an empty set means no filter, not "matches nothing"', () {
      expect(
        idsFor(const LibraryQuery()),
        <String>['cafe-quiet-solo', 'club-loud-group', 'station-waiting-pair'],
      );
    });
  });

  group('previously supported filters still work', () {
    test('Japanese text search', () {
      expect(
        idsFor(const LibraryQuery(searchText: '電車')),
        <String>['station-waiting-pair'],
      );
    });

    test('English text search', () {
      expect(
        idsFor(const LibraryQuery(searchText: 'crowded')),
        <String>['station-waiting-pair'],
      );
    });

    test('location, cue, tone, category, favourites and origin', () {
      expect(
        idsFor(const LibraryQuery(locations: <LocationTag>{LocationTag.cafe})),
        <String>['cafe-quiet-solo'],
      );
      expect(
        idsFor(const LibraryQuery(cues: <ObservableCue>{ObservableCue.music})),
        <String>['club-loud-group'],
      );
      expect(
        idsFor(const LibraryQuery(tones: <Tone>{Tone.safe})),
        <String>['station-waiting-pair'],
      );
      expect(
        idsFor(const LibraryQuery(categories: <LineCategory>{
          LineCategory.club,
        })),
        <String>['club-loud-group'],
      );
      expect(
        idsFor(const LibraryQuery(favoritesOnly: true)),
        <String>['cafe-quiet-solo'],
      );
      expect(
        idsFor(const LibraryQuery(userCreatedOnly: true)),
        <String>['cafe-quiet-solo', 'club-loud-group'],
      );
      expect(
        idsFor(const LibraryQuery(minDirectness: 3)),
        <String>['club-loud-group'],
      );
    });

    test('every sort order is still reachable and total', () {
      for (final sort in LibrarySort.values) {
        expect(
          LibraryQuery(sort: sort).applyTo(library),
          hasLength(library.length),
          reason: 'sort $sort dropped or duplicated lines',
        );
      }
    });
  });

  group('combined filters and bookkeeping', () {
    test('several dimensions at once narrow to the intersection', () {
      const query = LibraryQuery(
        locations: <LocationTag>{LocationTag.club},
        activities: <ActivityTag>{ActivityTag.dancing},
        noiseLevels: <NoiseLevel>{NoiseLevel.veryLoud},
        groupSizes: <GroupSize>{GroupSize.smallGroup},
        tones: <Tone>{Tone.playful},
      );
      expect(idsFor(query), <String>['club-loud-group']);
    });

    test('contradictory filters return nothing rather than throwing', () {
      const query = LibraryQuery(
        locations: <LocationTag>{LocationTag.cafe},
        noiseLevels: <NoiseLevel>{NoiseLevel.veryLoud},
      );
      expect(idsFor(query), isEmpty);
    });

    test('activeFilterCount counts the three new dimensions', () {
      const query = LibraryQuery(
        activities: <ActivityTag>{ActivityTag.waiting},
        groupSizes: <GroupSize>{GroupSize.alone},
        noiseLevels: <NoiseLevel>{NoiseLevel.quiet},
      );
      expect(query.activeFilterCount, 3);
    });

    test('isEmpty is false once a new dimension is set', () {
      expect(const LibraryQuery().isEmpty, isTrue);
      expect(
        const LibraryQuery(activities: <ActivityTag>{ActivityTag.waiting})
            .isEmpty,
        isFalse,
      );
      expect(
        const LibraryQuery(groupSizes: <GroupSize>{GroupSize.alone}).isEmpty,
        isFalse,
      );
      expect(
        const LibraryQuery(noiseLevels: <NoiseLevel>{NoiseLevel.loud}).isEmpty,
        isFalse,
      );
    });

    test('copyWith carries the new dimensions through', () {
      const base = LibraryQuery(
        activities: <ActivityTag>{ActivityTag.waiting},
        groupSizes: <GroupSize>{GroupSize.alone},
        noiseLevels: <NoiseLevel>{NoiseLevel.quiet},
      );
      final copied = base.copyWith(searchText: 'x');
      expect(copied.activities, base.activities);
      expect(copied.groupSizes, base.groupSizes);
      expect(copied.noiseLevels, base.noiseLevels);
    });

    test('clearing rebuilds an empty query', () {
      const query = LibraryQuery(
        activities: <ActivityTag>{ActivityTag.waiting},
        noiseLevels: <NoiseLevel>{NoiseLevel.quiet},
      );
      expect(LibraryQuery(sort: query.sort).isEmpty, isTrue);
    });
  });

  group('no domain option is unreachable through search', () {
    // The point of the audit: every value of every filterable enum must be
    // expressible as a filter. A value that no query can name is a value the
    // user cannot find.
    test('every enum value is accepted by a query without throwing', () {
      for (final value in LocationTag.values) {
        LibraryQuery(locations: <LocationTag>{value}).applyTo(library);
      }
      for (final value in ActivityTag.values) {
        LibraryQuery(activities: <ActivityTag>{value}).applyTo(library);
      }
      for (final value in GroupSize.values) {
        LibraryQuery(groupSizes: <GroupSize>{value}).applyTo(library);
      }
      for (final value in NoiseLevel.values) {
        LibraryQuery(noiseLevels: <NoiseLevel>{value}).applyTo(library);
      }
      for (final value in ObservableCue.values) {
        LibraryQuery(cues: <ObservableCue>{value}).applyTo(library);
      }
      for (final value in Tone.values) {
        LibraryQuery(tones: <Tone>{value}).applyTo(library);
      }
      for (final value in LineCategory.values) {
        LibraryQuery(categories: <LineCategory>{value}).applyTo(library);
      }
      for (var d = kMinDirectness; d <= kMaxDirectness; d++) {
        LibraryQuery(minDirectness: d, maxDirectness: d).applyTo(library);
      }
    });
  });
}
