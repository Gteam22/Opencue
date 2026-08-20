import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/scan/confidence.dart';
import 'package:opencue/domain/scan/evidence_fusion.dart';
import 'package:opencue/domain/scan/text_evidence.dart';
import 'package:opencue/domain/scan/venue_category.dart';

/// The cases the repaired pipeline has to get right.
///
/// Written against evidence patterns rather than images, so they are
/// deterministic and need no camera, no model and no device. The evidence in
/// each case is what the analyzers would plausibly produce for that scene.
void main() {
  const fusion = EvidenceFusion();

  List<TextToken> ocr(List<String> lines) => TextEvidence.tokenize(lines);

  FusionResult run({
    List<String> text = const <String>[],
    Map<VenueCategory, int> objects = const <VenueCategory, int>{},
    Map<VenueCategory, int> labels = const <VenueCategory, int>{},
    Map<VenueCategory, int> scene = const <VenueCategory, int>{},
    int frameAgreement = 3,
    int frameCount = 3,
  }) {
    final tokens = ocr(text);
    final textEvidence = TextEvidence.scoreTransit(tokens);
    final placeName = TextEvidence.extractStationName(tokens);

    return fusion.fuse(
      evidence: <AnalyzerEvidence>[
        if (textEvidence.score > 0)
          AnalyzerEvidence(
            source: 'text',
            venueScores: <VenueCategory, int>{
              VenueCategory.subwayOrTrainStation: textEvidence.score,
            },
            terms: textEvidence.terms,
            placeName: placeName,
          ),
        if (objects.isNotEmpty)
          AnalyzerEvidence(source: 'objects', venueScores: objects),
        if (labels.isNotEmpty)
          AnalyzerEvidence(source: 'labels', venueScores: labels),
        if (scene.isNotEmpty)
          AnalyzerEvidence(source: 'scene', venueScores: scene),
      ],
      textEvidence: textEvidence,
      frameAgreement: frameAgreement,
      frameCount: frameCount,
    );
  }

  group('station platform', () {
    test('is identified with high confidence', () {
      final result = run(
        text: <String>['福岡市地下鉄', '空港線', '2番線'],
        objects: <VenueCategory, int>{
          VenueCategory.trainPlatform: 55,
        },
        scene: <VenueCategory, int>{
          VenueCategory.subwayOrTrainStation: 60,
        },
      );

      expect(result.guess.category.isTransit, isTrue);
      expect(result.confidence.level, ConfidenceLevel.high);
      expect(
        result.guess.category.toLocationTag(),
        LocationTag.trainStation,
      );
    });

    test('keeps the platform subtype', () {
      final result = run(
        text: <String>['空港線', '2番線'],
        objects: <VenueCategory, int>{VenueCategory.trainPlatform: 50},
      );
      expect(result.guess.subtype, VenueCategory.trainPlatform.name);
    });

    test('the exact scene that failed before now resolves', () {
      // Same visual poverty as the real failure - the labeller offers almost
      // nothing - but the signage is read, and that is enough.
      final result = run(
        text: <String>['地下鉄', '2番線', '空港線'],
        labels: <VenueCategory, int>{
          // 'train' at low confidence, which was all the old pipeline had.
          VenueCategory.subwayOrTrainStation: 26,
        },
      );
      expect(result.guess.category.isTransit, isTrue);
      expect(
        result.confidence.level.mayPreselect,
        isTrue,
        reason: 'this returned Unknown before OCR existed',
      );
    });
  });

  group('station concourse', () {
    test('is identified from gates and exit signage', () {
      final result = run(
        text: <String>['改札', '出口 5'],
        objects: <VenueCategory, int>{
          VenueCategory.ticketGateArea: 50,
        },
        scene: <VenueCategory, int>{
          VenueCategory.stationConcourse: 55,
        },
      );
      expect(result.guess.category.isTransit, isTrue);
      expect(result.confidence.level.mayPreselect, isTrue);
      expect(
        result.guess.category.toLocationTag(),
        LocationTag.trainStation,
      );
    });
  });

  group('train interior', () {
    test('is identified without any station text', () {
      final result = run(
        objects: <VenueCategory, int>{
          VenueCategory.trainInterior: 60,
        },
        scene: <VenueCategory, int>{
          VenueCategory.trainInterior: 65,
        },
      );
      expect(result.guess.category, VenueCategory.trainInterior);
      expect(result.confidence.level.mayPreselect, isTrue);
      expect(
        result.guess.category.toLocationTag(),
        LocationTag.publicTransport,
        reason: 'a train interior is public transport, not a station',
      );
    });
  });

  group('ambiguous underground corridor', () {
    test('does not claim a station', () {
      // An indoor corridor with no train, no rails, no gates and no transit
      // text. Plenty of underground corridors are shopping arcades.
      final result = run(
        labels: <VenueCategory, int>{
          VenueCategory.other: 20,
        },
      );
      expect(
        result.confidence.level,
        isNot(ConfidenceLevel.high),
        reason: 'a corridor alone is not a subway',
      );
      expect(result.guess.category.isTransit, isFalse);
    });
  });

  group('OCR-only station clue', () {
    test('a readable station name proposes a station and the name', () {
      final tokens = ocr(<String>['西新駅', '地下鉄']);
      final evidence = TextEvidence.scoreTransit(tokens);
      expect(evidence.score, greaterThan(0));
      expect(TextEvidence.extractStationName(tokens), isNotNull);

      final result = run(text: <String>['西新駅', '地下鉄']);
      expect(result.guess.category.isTransit, isTrue);
      expect(result.guess.possiblePlaceName, isNotNull);
      expect(result.guess.placeNameFromText, isTrue);
    });

    test('a missing station name does not fail the whole scan', () {
      // The distinction that broke the original: "which station" and "is this
      // a station" are separate questions.
      final result = run(
        text: <String>['番線', '改札'],
        objects: <VenueCategory, int>{VenueCategory.trainPlatform: 45},
      );
      expect(result.guess.possiblePlaceName, isNull);
      expect(result.guess.category.isTransit, isTrue);
      expect(result.confidence.level, isNot(ConfidenceLevel.unknown));
    });
  });

  group('misleading text', () {
    test('the word "station" on an advert does not make a station', () {
      final result = run(
        text: <String>['SALE', 'Station Coffee', 'NEW'],
      );
      expect(
        result.confidence.level,
        isNot(ConfidenceLevel.high),
        reason: 'one English word plus commercial context is not a station',
      );
    });

    test('a single transit term is capped below preselection', () {
      final evidence = TextEvidence.scoreTransit(ocr(<String>['station']));
      expect(evidence.distinctStrongTerms, lessThanOrEqualTo(1));
      expect(evidence.score, lessThanOrEqualTo(30));
    });

    test('"stationery" does not fire the station rule', () {
      final evidence = TextEvidence.scoreTransit(ocr(<String>['stationery']));
      expect(evidence.score, 0);
    });

    test('but three real transit terms are not capped', () {
      final evidence =
          TextEvidence.scoreTransit(ocr(<String>['地下鉄', '番線', '改札']));
      expect(evidence.distinctStrongTerms, greaterThanOrEqualTo(2));
      expect(evidence.score, greaterThan(60));
      expect(evidence.isStrong, isTrue);
    });
  });

  group('text normalisation', () {
    test('full-width characters fold to half-width', () {
      final tokens = ocr(<String>['ＳＴＡＴＩＯＮ']);
      expect(tokens.single.normalized, 'station');
    });

    test('punctuation is stripped', () {
      final tokens = ocr(<String>['出口 5 、 改札']);
      expect(tokens.map((t) => t.normalized), contains('改札'));
    });

    test('scripts are labelled', () {
      final tokens = ocr(<String>['番線', 'exit', '5']);
      expect(tokens.map((t) => t.script).toSet(),
          <String>{'japanese', 'latin', 'digits'});
    });
  });

  group('fusion behaviour', () {
    test('related transit categories reinforce rather than compete', () {
      // Platform from objects and station from text are the same answer at
      // two levels of detail, and must not damp each other.
      final result = run(
        text: <String>['地下鉄', '番線'],
        objects: <VenueCategory, int>{VenueCategory.trainPlatform: 50},
      );
      expect(result.contested, isFalse);
      expect(result.confidence.level.mayPreselect, isTrue);
    });

    test('unrelated close scores are treated as disagreement', () {
      // Weighted these land at 60 and 62 - close enough that picking one
      // would be a coin flip, which is exactly when the user should be asked.
      final result = run(
        objects: <VenueCategory, int>{VenueCategory.cafe: 60},
        scene: <VenueCategory, int>{VenueCategory.gym: 52},
      );
      expect(result.contested, isTrue);
      expect(result.isHighConfidence, isFalse);
    });

    test('sibling venues reinforce rather than compete', () {
      // A bar and a standing bar are genuinely hard to tell apart, and both
      // map to sensible lines. Treating them as disagreement would damp a
      // correct answer for no reason.
      final result = run(
        objects: <VenueCategory, int>{VenueCategory.bar: 50},
        scene: <VenueCategory, int>{VenueCategory.standingBar: 48},
      );
      expect(result.contested, isFalse);
      expect(
        VenueCategory.bar.family,
        VenueCategory.standingBar.family,
      );
    });

    test('unrelated venues still contest', () {
      final result = run(
        objects: <VenueCategory, int>{VenueCategory.cafe: 60},
        scene: <VenueCategory, int>{VenueCategory.gym: 52},
      );
      expect(result.contested, isTrue);
    });

    test('every family member maps to a real engine location', () {
      for (final members in VenueCategory.families.values) {
        for (final member in members) {
          expect(member.toLocationTag(), isNotNull, reason: member.name);
        }
      }
    });

    test('text outweighs a vague label for venue identification', () {
      final result = run(
        text: <String>['改札', '番線', '地下鉄'],
        labels: <VenueCategory, int>{VenueCategory.cafe: 35},
      );
      expect(result.guess.category.isTransit, isTrue);
    });

    test('frame disagreement lowers confidence', () {
      final agreed = run(
        text: <String>['地下鉄', '番線'],
        frameAgreement: 3,
        frameCount: 3,
      );
      final disagreed = run(
        text: <String>['地下鉄', '番線'],
        frameAgreement: 1,
        frameCount: 3,
      );
      expect(
        disagreed.confidence.score,
        lessThan(agreed.confidence.score),
      );
    });

    test('no evidence produces Unknown, not a guess', () {
      final result = fusion.fuse(evidence: const <AnalyzerEvidence>[]);
      expect(result.guess.category, VenueCategory.unknown);
      expect(result.guess.category.toLocationTag(), isNull);
      expect(result.confidence.level, ConfidenceLevel.unknown);
    });

    test('fusion explains itself', () {
      final result = run(text: <String>['地下鉄', '番線', '改札']);
      expect(result.explanation, contains('text contained'));
    });

    test('is deterministic', () {
      FusionResult once() => run(
            text: <String>['地下鉄', '番線'],
            objects: <VenueCategory, int>{VenueCategory.trainPlatform: 50},
          );
      expect(once().confidence.score, once().confidence.score);
      expect(once().guess.category, once().guess.category);
    });
  });

  group('synonym folding', () {
    test('model dialects fold to canonical terms', () {
      // The original failure in miniature: the rule table said 'railway', the
      // model said 'train'. Both now mean the same thing.
      expect(SynonymTable.canonical('Railway'), 'train');
      expect(SynonymTable.canonical('locomotive'), 'train');
      expect(SynonymTable.canonical('電車'), 'train');
      expect(SynonymTable.canonical('turnstile'), 'ticket_gate');
      expect(SynonymTable.canonical('改札'), 'ticket_gate');
      expect(SynonymTable.canonical('mug'), 'cup');
    });

    test('unmapped labels pass through lower-cased', () {
      expect(SynonymTable.canonical('Ceiling'), 'ceiling');
    });
  });

  group('venue category mapping', () {
    test('every transit subtype maps to a real engine location', () {
      for (final category in VenueCategory.values) {
        if (!category.isTransit) continue;
        expect(
          category.toLocationTag(),
          anyOf(LocationTag.trainStation, LocationTag.publicTransport),
          reason: category.name,
        );
      }
    });

    test('unknown maps to null rather than to Other', () {
      // "I could not tell" and "some other kind of place" are different
      // answers, and collapsing them lets an unknown masquerade as a decision.
      expect(VenueCategory.unknown.toLocationTag(), isNull);
      expect(VenueCategory.other.toLocationTag(), LocationTag.other);
    });

    test('every category maps somewhere or explicitly nowhere', () {
      for (final category in VenueCategory.values) {
        if (category == VenueCategory.unknown) continue;
        expect(category.toLocationTag(), isNotNull, reason: category.name);
      }
    });
  });
}
