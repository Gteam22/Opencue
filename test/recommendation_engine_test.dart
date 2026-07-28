import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/context_snapshot.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/recommendation/recommendation_engine.dart';
import 'package:opencue/domain/recommendation/recommendation_models.dart';

import 'helpers.dart';

void main() {
  const engine = RecommendationEngine();

  /// Convenience: the ids the engine put in the three main slots.
  List<String> idsOf(List<ScoredLine> scored) =>
      scored.map((s) => s.line.id).toList();

  group('approach advisory', () {
    test('is quiet when nothing is wrong', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[line('a', locations: <LocationTag>{
          LocationTag.bar,
        })],
      );
      expect(result.advisory.discouraged, isFalse);
      expect(result.advisory.reasons, isEmpty);
      expect(result.primary, isNotEmpty);
    });

    test('fires for each of the five conditions, naming the specific one', () {
      final cases = <ContextSnapshotCase>[
        ContextSnapshotCase(
          situation(location: LocationTag.cafe, occupied: true),
          AvoidCondition.personOccupied,
        ),
        ContextSnapshotCase(
          situation(location: LocationTag.cafe, working: true),
          AvoidCondition.personWorking,
        ),
        ContextSnapshotCase(
          situation(location: LocationTag.cafe, headphones: true),
          AvoidCondition.headphonesOn,
        ),
        ContextSnapshotCase(
          situation(location: LocationTag.street, movingQuickly: true),
          AvoidCondition.movingQuickly,
        ),
        ContextSnapshotCase(
          situation(location: LocationTag.park, isolated: true),
          AvoidCondition.isolatedSetting,
        ),
      ];

      for (final testCase in cases) {
        final result = engine.recommend(
          context: testCase.context,
          library: <OpenerLine>[line('a')],
        );
        expect(
          result.advisory.discouraged,
          isTrue,
          reason: 'expected ${testCase.expected.name} to discourage',
        );
        expect(result.advisory.reasons, contains(testCase.expected));
      }
    });

    test('withholds openers entirely when the advisory fires', () {
      // Warning and then handing over an opener anyway would make the warning
      // decorative. The library stays browsable; this screen does not help.
      final result = engine.recommend(
        context: situation(location: LocationTag.cafe, working: true),
        library: <OpenerLine>[
          line('a', locations: <LocationTag>{LocationTag.cafe}),
          line('b', locations: <LocationTag>{LocationTag.cafe}),
        ],
      );
      expect(result.primary, isEmpty);
      expect(result.alternates, isEmpty);
    });

    test('still offers graceful exits when the advisory fires', () {
      // An exit line is exactly what someone needs at that moment.
      final result = engine.recommend(
        context: situation(location: LocationTag.cafe, working: true),
        library: <OpenerLine>[
          line('opener', locations: <LocationTag>{LocationTag.cafe}),
          line(
            'exit',
            japanese: '仕事中にすみません。頑張ってください。',
            category: LineCategory.gracefulExit,
          ),
        ],
      );
      expect(result.exitLines.map((s) => s.line.id), contains('exit'));
    });

    test('reports several reasons at once', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.street,
          movingQuickly: true,
          headphones: true,
        ),
        library: <OpenerLine>[line('a')],
      );
      expect(result.advisory.reasons, hasLength(2));
    });
  });

  group('hard exclusion', () {
    test('excludes a line whose avoid condition the context matches', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.bar,
          groupSize: GroupSize.alone,
        ),
        library: <OpenerLine>[
          line(
            'needs-quiet',
            locations: <LocationTag>{LocationTag.bar},
            avoidConditions: <AvoidCondition>{AvoidCondition.veryLoudSetting},
          ),
          line('fine', locations: <LocationTag>{LocationTag.bar}),
        ],
      );
      // The bar context above is not loud, so nothing is excluded yet.
      expect(idsOf(result.primary), contains('needs-quiet'));

      final loud = engine.recommend(
        context: situation(
          location: LocationTag.bar,
          noiseLevel: NoiseLevel.veryLoud,
        ),
        library: <OpenerLine>[
          line(
            'needs-quiet',
            locations: <LocationTag>{LocationTag.bar},
            avoidConditions: <AvoidCondition>{AvoidCondition.veryLoudSetting},
          ),
          line('fine', locations: <LocationTag>{LocationTag.bar}),
        ],
      );
      expect(idsOf(loud.primary), isNot(contains('needs-quiet')));
      expect(
        loud.excluded.map((e) => e.line.id),
        contains('needs-quiet'),
      );
      expect(
        loud.excluded.single.reason,
        ExclusionReason.conflictingAvoidCondition,
      );
    });

    test('excludes a line whose required condition is not met', () {
      final library = <OpenerLine>[
        line(
          'needs-eye-contact',
          locations: <LocationTag>{LocationTag.bar},
          conditions: <UseCondition>{UseCondition.eyeContactEstablished},
        ),
        line('unconditional', locations: <LocationTag>{LocationTag.bar}),
      ];

      final without = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: library,
      );
      expect(idsOf(without.primary), isNot(contains('needs-eye-contact')));

      final withContact = engine.recommend(
        context: situation(location: LocationTag.bar, eyeContact: true),
        library: library,
      );
      expect(idsOf(withContact.primary), contains('needs-eye-contact'));
    });

    test('never auto-excludes on genuine knowledge of the subject', () {
      // Only the user can know whether they have actually read the book, so
      // this condition is surfaced on the card rather than acted on.
      final result = engine.recommend(
        context: situation(location: LocationTag.bookstore),
        library: <OpenerLine>[
          line(
            'knows-it',
            locations: <LocationTag>{LocationTag.bookstore},
            conditions: <UseCondition>{
              UseCondition.genuineKnowledgeOfSubject,
            },
          ),
        ],
      );
      expect(idsOf(result.primary), contains('knows-it'));
    });

    test('excludes a line that needs a concrete cue nobody observed', () {
      final library = <OpenerLine>[
        line(
          'about-the-dog',
          locations: <LocationTag>{LocationTag.park},
          cues: <ObservableCue>{ObservableCue.dog},
        ),
        line('generic', locations: <LocationTag>{LocationTag.park}),
      ];

      final noDog = engine.recommend(
        context: situation(
          location: LocationTag.park,
          cues: <ObservableCue>{ObservableCue.weather},
        ),
        library: library,
      );
      expect(idsOf(noDog.primary), isNot(contains('about-the-dog')));

      final withDog = engine.recommend(
        context: situation(
          location: LocationTag.park,
          cues: <ObservableCue>{ObservableCue.dog},
        ),
        library: library,
      );
      expect(idsOf(withDog.primary), contains('about-the-dog'));
    });

    test('treats an empty cue selection as unknown, not as absent', () {
      // Someone who skipped the cue section has not told us the dog is absent,
      // and losing every cue-specific line for that would be wrong.
      final result = engine.recommend(
        context: situation(location: LocationTag.park),
        library: <OpenerLine>[
          line(
            'about-the-dog',
            locations: <LocationTag>{LocationTag.park},
            cues: <ObservableCue>{ObservableCue.dog},
          ),
        ],
      );
      expect(idsOf(result.primary), contains('about-the-dog'));
    });

    test('excludes an invalid line rather than showing blank text', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line('empty', japanese: '   '),
          line('good', locations: <LocationTag>{LocationTag.bar}),
        ],
      );
      expect(idsOf(result.primary), <String>['good']);
      expect(
        result.excluded.single.reason,
        ExclusionReason.invalidLine,
      );
    });

    test('keeps exit lines out of the three main slots', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line('exit', category: LineCategory.gracefulExit),
          line('opener', locations: <LocationTag>{LocationTag.bar}),
        ],
      );
      expect(idsOf(result.primary), isNot(contains('exit')));
      expect(result.exitLines.map((s) => s.line.id), contains('exit'));
    });
  });

  group('matching', () {
    test('prefers a line tagged for the current location', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: <OpenerLine>[
          line('for-bar', locations: <LocationTag>{LocationTag.bar}),
          line('for-cafe', locations: <LocationTag>{LocationTag.cafe}),
        ],
      );
      expect(result.primary.first.line.id, 'for-cafe');
    });

    test('an untagged line beats a wrongly tagged one', () {
      // A universal line is usable anywhere; a bar line in a bookstore is not.
      final result = engine.recommend(
        context: situation(location: LocationTag.bookstore),
        library: <OpenerLine>[
          line('for-bar', locations: <LocationTag>{LocationTag.bar}),
          line('universal'),
        ],
      );
      expect(result.primary.first.line.id, 'universal');
    });

    test('rewards each observed cue the line refers to', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.festival,
          cues: <ObservableCue>{
            ObservableCue.festivalItem,
            ObservableCue.smile,
          },
        ),
        library: <OpenerLine>[
          line(
            'one-cue',
            locations: <LocationTag>{LocationTag.festival},
            cues: <ObservableCue>{ObservableCue.festivalItem},
          ),
          line(
            'two-cues',
            locations: <LocationTag>{LocationTag.festival},
            cues: <ObservableCue>{
              ObservableCue.festivalItem,
              ObservableCue.smile,
            },
          ),
        ],
      );
      expect(result.primary.first.line.id, 'two-cues');
    });

    test('matches group size', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.bar,
          groupSize: GroupSize.withOneFriend,
        ),
        library: <OpenerLine>[
          line(
            'for-pairs',
            locations: <LocationTag>{LocationTag.bar},
            groupSizes: <GroupSize>{GroupSize.withOneFriend},
          ),
          line(
            'for-anyone',
            locations: <LocationTag>{LocationTag.bar},
            groupSizes: <GroupSize>{
              GroupSize.alone,
              GroupSize.withOneFriend,
              GroupSize.smallGroup,
            },
          ),
        ],
      );
      expect(result.primary.first.line.id, 'for-pairs');
    });

    test('will not use a solo-only line on someone with a friend', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.bar,
          groupSize: GroupSize.withOneFriend,
        ),
        library: <OpenerLine>[
          line(
            'solo-only',
            locations: <LocationTag>{LocationTag.bar},
            groupSizes: <GroupSize>{GroupSize.alone},
          ),
          line(
            'either',
            locations: <LocationTag>{LocationTag.bar},
            groupSizes: <GroupSize>{
              GroupSize.alone,
              GroupSize.withOneFriend,
            },
          ),
        ],
      );
      expect(result.primary.first.line.id, 'either');
    });

    test('matches noise level', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.club,
          noiseLevel: NoiseLevel.veryLoud,
        ),
        library: <OpenerLine>[
          line(
            'for-quiet',
            locations: <LocationTag>{LocationTag.club},
            noiseLevels: <NoiseLevel>{NoiseLevel.quiet},
          ),
          line(
            'for-loud',
            locations: <LocationTag>{LocationTag.club},
            noiseLevels: <NoiseLevel>{NoiseLevel.veryLoud},
          ),
        ],
      );
      expect(result.primary.first.line.id, 'for-loud');
    });

    test('prefers short lines in a loud venue', () {
      final short = line(
        'short',
        japanese: 'その曲、最高ですね！',
        locations: <LocationTag>{LocationTag.club},
      );
      final long = line(
        'long',
        japanese: 'さっきから何回か目が合ってる気がして、'
            '話しかけようかずっと迷っていたんですけど、思い切って来ました。',
        locations: <LocationTag>{LocationTag.club},
      );

      final loud = engine.recommend(
        context: situation(
          location: LocationTag.club,
          noiseLevel: NoiseLevel.veryLoud,
        ),
        library: <OpenerLine>[long, short],
      );
      expect(loud.primary.first.line.id, 'short');

      // In a quiet room the length preference should not dominate, so the two
      // lines are close enough that the long one is still offered.
      final quiet = engine.recommend(
        context: situation(
          location: LocationTag.club,
          noiseLevel: NoiseLevel.quiet,
        ),
        library: <OpenerLine>[long, short],
      );
      expect(idsOf(quiet.primary), contains('long'));
    });

    test('honours the requested directness', () {
      final library = <OpenerLine>[
        line(
          'gentle',
          locations: <LocationTag>{LocationTag.bar},
          directness: 1,
        ),
        line(
          'bold',
          locations: <LocationTag>{LocationTag.bar},
          directness: 5,
        ),
      ];

      final wantsGentle = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: library,
        preferences: const RecommendationPreferences(desiredDirectness: 1),
      );
      expect(wantsGentle.primary.first.line.id, 'gentle');

      final wantsBold = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: library,
        preferences: const RecommendationPreferences(desiredDirectness: 5),
      );
      expect(wantsBold.primary.first.line.id, 'bold');
    });

    test('nudges toward a preferred tone', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line(
            'safe',
            locations: <LocationTag>{LocationTag.bar},
            tones: <Tone>{Tone.safe},
          ),
          line(
            'playful',
            locations: <LocationTag>{LocationTag.bar},
            tones: <Tone>{Tone.playful},
          ),
        ],
        preferences: const RecommendationPreferences(
          preferredTones: <Tone>{Tone.playful},
        ),
      );
      expect(result.primary.first.line.id, 'playful');
    });
  });

  group('personal signal', () {
    test('gives favourites a small boost', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line('plain', locations: <LocationTag>{LocationTag.bar}),
          line(
            'favourite',
            locations: <LocationTag>{LocationTag.bar},
            isFavorite: true,
          ),
        ],
      );
      expect(result.primary.first.line.id, 'favourite');
    });

    test('a favourite boost does not outweigh a location mismatch', () {
      // Personal preference nudges the order; it does not override fit.
      final result = engine.recommend(
        context: situation(location: LocationTag.bookstore),
        library: <OpenerLine>[
          line(
            'favourite-wrong-place',
            locations: <LocationTag>{LocationTag.club},
            isFavorite: true,
          ),
          line(
            'right-place',
            locations: <LocationTag>{LocationTag.bookstore},
          ),
        ],
      );
      expect(result.primary.first.line.id, 'right-place');
    });

    test('rewards a positive personal record', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line('untested', locations: <LocationTag>{LocationTag.bar}),
          line(
            'worked-before',
            locations: <LocationTag>{LocationTag.bar},
            timesUsed: 4,
            positive: 4,
          ),
        ],
      );
      expect(result.primary.first.line.id, 'worked-before');
    });

    test('penalises a poor personal record', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line('untested', locations: <LocationTag>{LocationTag.bar}),
          line(
            'never-worked',
            locations: <LocationTag>{LocationTag.bar},
            timesUsed: 4,
            negative: 4,
          ),
        ],
      );
      expect(result.primary.first.line.id, 'untested');
    });

    test('ignores a single result as too small a sample', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line(
            'one-good-result',
            locations: <LocationTag>{LocationTag.bar},
            timesUsed: 1,
            positive: 1,
          ),
        ],
      );
      final factors = result.primary.single.factors.map((f) => f.code);
      expect(
        factors,
        isNot(contains(ScoreFactorCode.positiveHistory)),
      );
    });
  });

  group('rotation', () {
    test('demotes a line shown in a recent round', () {
      final library = <OpenerLine>[
        line('just-shown', locations: <LocationTag>{LocationTag.bar}),
        line('not-shown', locations: <LocationTag>{LocationTag.bar}),
      ];
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: library,
        recentlyShownIds: <String>{'just-shown'},
      );
      expect(result.primary.first.line.id, 'not-shown');
    });

    test('still returns a recently shown line when it is the only option', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: <OpenerLine>[
          line('only-one', locations: <LocationTag>{LocationTag.bar}),
        ],
        recentlyShownIds: <String>{'only-one'},
      );
      expect(idsOf(result.primary), <String>['only-one']);
    });
  });

  group('slots and determinism', () {
    test('returns at most three primary suggestions', () {
      final library = <OpenerLine>[
        for (var i = 0; i < 12; i++)
          line(
            'line-$i',
            japanese: 'テスト $i の一言です。',
            locations: <LocationTag>{LocationTag.bar},
            tones: <Tone>{Tone.values[i % Tone.values.length]},
            directness: (i % kMaxDirectness) + 1,
          ),
      ];
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: library,
      );
      expect(result.primary.length, lessThanOrEqualTo(3));
    });

    test('fills the safest, playful and more-direct slots distinctly', () {
      final library = <OpenerLine>[
        line(
          'safe-one',
          japanese: 'ここ、いい雰囲気ですね。',
          locations: <LocationTag>{LocationTag.bar},
          tones: <Tone>{Tone.safe},
          directness: 1,
        ),
        line(
          'playful-one',
          japanese: 'その注文、常連感ありますね。',
          locations: <LocationTag>{LocationTag.bar},
          tones: <Tone>{Tone.playful},
          directness: 3,
        ),
        line(
          'direct-one',
          japanese: '率直に言うと、すごくタイプです。',
          locations: <LocationTag>{LocationTag.bar},
          tones: <Tone>{Tone.direct},
          directness: 5,
        ),
      ];
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: library,
      );
      expect(result.primary, hasLength(3));
      expect(
        result.primary.map((s) => s.category).toSet(),
        <RecommendationCategory>{
          RecommendationCategory.safest,
          RecommendationCategory.playful,
          RecommendationCategory.moreDirect,
        },
      );
      expect(idsOf(result.primary).toSet(), hasLength(3));
    });

    test('is deterministic for the same inputs', () {
      final library = <OpenerLine>[
        for (var i = 0; i < 8; i++)
          line(
            'line-$i',
            japanese: '同じ長さの一言です $i。',
            locations: <LocationTag>{LocationTag.cafe},
          ),
      ];
      final first = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: library,
      );
      final second = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: library,
      );
      expect(idsOf(first.primary), idsOf(second.primary));
      expect(idsOf(first.alternates), idsOf(second.alternates));
    });

    test('breaks score ties by id so ordering never wobbles', () {
      // Two identical lines differing only by id must always come back in the
      // same order, otherwise "Show another" could loop.
      final library = <OpenerLine>[
        line('zzz', locations: <LocationTag>{LocationTag.cafe}),
        line('aaa', locations: <LocationTag>{LocationTag.cafe}),
      ];
      final result = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: library,
      );
      final reversed = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: library.reversed.toList(),
      );
      expect(idsOf(result.primary), idsOf(reversed.primary));
    });

    test('returns nothing at all for an empty library', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.bar),
        library: const <OpenerLine>[],
      );
      expect(result.primary, isEmpty);
      expect(result.exitLines, isEmpty);
      expect(result.consideredCount, 0);
      expect(result.advisory.discouraged, isFalse);
    });
  });

  group('explanation', () {
    test('every scored line carries factors that explain its score', () {
      final result = engine.recommend(
        context: situation(
          location: LocationTag.cafe,
          cues: <ObservableCue>{ObservableCue.drink},
        ),
        library: <OpenerLine>[
          line(
            'explained',
            locations: <LocationTag>{LocationTag.cafe},
            cues: <ObservableCue>{ObservableCue.drink},
            isFavorite: true,
          ),
        ],
      );
      final scored = result.primary.single;
      expect(scored.factors, isNotEmpty);
      expect(
        scored.factors.map((f) => f.code),
        containsAll(<ScoreFactorCode>[
          ScoreFactorCode.locationMatch,
          ScoreFactorCode.cueMatch,
          ScoreFactorCode.favorite,
        ]),
      );
      // The factors must actually add up to the score, or the explanation is
      // decorative rather than a debugging tool.
      final total = scored.factors.fold<int>(0, (sum, f) => sum + f.delta);
      expect(total, scored.score);
    });

    test('separates matching reasons from penalties', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: <OpenerLine>[
          line(
            'mixed',
            locations: <LocationTag>{LocationTag.club},
            directness: 5,
          ),
        ],
      );
      final scored = result.primary.single;
      expect(scored.penalties, isNotEmpty);
      expect(scored.penalties.every((f) => f.delta < 0), isTrue);
      expect(scored.matchingReasons.every((f) => f.delta > 0), isTrue);
    });

    test('debugReport mentions the considered and excluded counts', () {
      final result = engine.recommend(
        context: situation(location: LocationTag.cafe),
        library: <OpenerLine>[
          line('ok', locations: <LocationTag>{LocationTag.cafe}),
          line('broken', japanese: ''),
        ],
      );
      final report = result.debugReport();
      expect(report, contains('considered'));
      expect(report, contains('excluded'));
    });
  });
}

/// One advisory case: a context and the condition it must report.
class ContextSnapshotCase {
  ContextSnapshotCase(this.context, this.expected);

  final ContextSnapshot context;
  final AvoidCondition expected;
}
