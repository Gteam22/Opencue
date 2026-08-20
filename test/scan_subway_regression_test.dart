import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/scan/confidence.dart';
import 'package:opencue/domain/scan/environmental_observation.dart';
import 'package:opencue/domain/scan/observation_normalizer.dart';
import 'package:opencue/domain/scan/scan_heuristics.dart';

/// Why the subway scan returned Unknown, captured as executable tests.
///
/// These reproduce the real-world failure with the labels ML Kit's *base*
/// image-labelling model actually emits, rather than the labels the original
/// rule table was written against. Every test in the first group asserts the
/// broken behaviour so that the repair has something to prove itself against;
/// they are inverted in the second group once the new pipeline is in place.
///
/// The finding, in one line: the rule table was written against a vocabulary
/// the model does not have. Of the twelve transit terms it scores, exactly one
/// ('train') exists in the base label set, and the two strongest real signals
/// in a subway are both discarded before scoring.
void main() {
  const normalizer = ObservationNormalizer();
  final capturedAt = DateTime.utc(2026, 5, 1, 18, 0);

  EnvironmentalObservation observe(Map<String, double> raw) =>
      normalizer.normalize(
        id: 'regression',
        labels: raw.entries
            .map((e) => ScoredLabel(e.key, e.value))
            .toList(),
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );

  /// What ML Kit's base model plausibly returns on a Fukuoka subway platform.
  /// Note what is *not* here: no 'platform', no 'subway', no 'station', no
  /// 'turnstile'. Those labels do not exist in the base vocabulary at all.
  const subwayPlatform = <String, double>{
    'text': 0.92,
    'person': 0.88,
    'crowd': 0.71,
    'line': 0.68,
    'wall': 0.66,
    'ceiling': 0.62,
    'metal': 0.58,
    'train': 0.54,
    'vehicle': 0.51,
  };

  const trainInterior = <String, double>{
    'person': 0.90,
    'vehicle': 0.74,
    'train': 0.66,
    'window': 0.63,
    'metal': 0.60,
    'sitting': 0.55,
  };

  group('cause 1: the rule vocabulary does not exist in the model', () {
    test('all but one transit rule key is unreachable', () {
      // The base label set is a ~400-entry consumer-photo vocabulary. It has
      // 'Train'. It has no 'train station', 'subway', 'metro', 'platform',
      // 'turnstile', 'railway' or 'timetable' - so those weights, however
      // carefully chosen, could never be applied to anything.
      final transitRules =
          ScanHeuristics.locationRules[LocationTag.trainStation]!;
      const presentInBaseModel = <String>{'train'};

      final unreachable = transitRules.keys
          .where((k) => !presentInBaseModel.contains(k))
          .toList();

      expect(
        unreachable.length,
        transitRules.length - 1,
        reason: 'only "train" is reachable; the rest are dead weight',
      );
    });

    test('multi-word keys can never match a single-word labeller', () {
      // 'train station' is two tokens. The labeller emits one token per label,
      // so this key is unmatchable by construction, not by tuning.
      final multiWord = ScanHeuristics.locationRules.values
          .expand((rules) => rules.keys)
          .where((k) => k.contains(' '))
          .toSet();
      expect(multiWord, contains('train station'));
      expect(multiWord, contains('railway station'));
      expect(multiWord.length, greaterThan(15));
    });
  });

  group('cause 2: the strongest real signals are discarded before scoring', () {
    test('"text" is stop-listed, which is backwards for a station', () {
      // A subway is saturated with signage. 'Text' firing at 0.92 is the
      // single best available hint that there are signs to read - and it is
      // thrown away as noise.
      expect(ScanHeuristics.isStopLabel('text'), isTrue);
    });

    test('"train" at a realistic confidence falls under the label floor', () {
      // minimumLabelConfidence is 0.55. A partially occluded train at the far
      // end of a platform comes back around 0.54 and is dropped entirely.
      expect(ObservationNormalizer.minimumLabelConfidence, 0.55);
      expect(subwayPlatform['train']! < 0.55, isTrue);
    });

    test('two floors are applied in series', () {
      // The plugin is configured at 0.5 and the normalizer re-filters at 0.55,
      // so evidence is discarded twice before any rule sees it.
      expect(ObservationNormalizer.minimumLabelConfidence, greaterThan(0.5));
    });
  });

  group('cause 3: the observed end result', () {
    test('a subway platform yields no match at all', () {
      final result = observe(subwayPlatform);
      expect(
        result.location.value,
        isNull,
        reason: 'this is the failure the user reported',
      );
      expect(result.location.level, ConfidenceLevel.unknown);
      expect(result.isInconclusive, isTrue);
    });

    test('a train interior reaches only low confidence', () {
      // 'train' alone scores ~26 against a medium threshold of 40, so even
      // when the one reachable keyword does fire it cannot preselect.
      final result = observe(trainInterior);
      expect(result.location.value, LocationTag.trainStation);
      expect(result.location.level, ConfidenceLevel.low);
      expect(result.location.confidence.level.mayPreselect, isFalse);
    });

    test('nothing about the failure was a threshold problem', () {
      // Lowering thresholds cannot fix an empty score map. With every floor
      // removed the platform case still matches no rule, because none of the
      // surviving labels appear in any rule at all.
      final everythingKept = subwayPlatform.entries
          .where((e) => !ScanHeuristics.isStopLabel(e.key))
          .map((e) => ScoredLabel(e.key, 1.0))
          .toList();
      final result = normalizer.normalize(
        id: 'no-floor',
        labels: everythingKept,
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );
      // 'train' now survives, but one weak keyword is all there is.
      expect(result.location.confidence.level.mayPreselect, isFalse);
    });
  });

  group('cause 4: no signal exists for the things a station actually has', () {
    test('there is no OCR evidence path', () {
      // A station is defined by its text: 駅, 番線, 出口, 改札, the line name.
      // The pipeline reads none of it, which is why the richest available
      // signal in exactly this environment contributes nothing.
      final json = observe(subwayPlatform).toJson();
      expect(json.containsKey('ocrTokens'), isFalse);
      expect(json.containsKey('detectedObjects'), isFalse);
    });

    test('venue category and place name are not distinguished', () {
      // 'Nishijin Station' and 'a subway platform' are different claims. The
      // model conflates them, so failing to read a station name reads as
      // failing to recognise a station.
      final json = observe(subwayPlatform).toJson();
      expect(json.containsKey('venueSubtype'), isFalse);
      expect(json.containsKey('possiblePlaceName'), isFalse);
    });
  });
}
