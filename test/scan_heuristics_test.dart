import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/scan/confidence.dart';
import 'package:opencue/domain/scan/context_snapshot_mapper.dart';
import 'package:opencue/domain/scan/environmental_observation.dart';
import 'package:opencue/domain/scan/observation_normalizer.dart';
import 'package:opencue/domain/scan/scan_heuristics.dart';

void main() {
  const normalizer = ObservationNormalizer();
  final capturedAt = DateTime.utc(2026, 5, 1, 20, 30);

  /// Builds labels at a given model confidence.
  List<ScoredLabel> labels(Map<String, double> raw) => raw.entries
      .map((e) => ScoredLabel(e.key, e.value))
      .toList(growable: false);

  EnvironmentalObservation observe(Map<String, double> raw) =>
      normalizer.normalize(
        id: 'test',
        labels: labels(raw),
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );

  group('location inference', () {
    test('a café is recognised from corroborating labels', () {
      final result = observe(<String, double>{
        'cafe': 0.88,
        'coffee': 0.83,
        'mug': 0.72,
        'table': 0.66,
      });
      expect(result.location.value, LocationTag.cafe);
      expect(result.location.level, ConfidenceLevel.high);
    });

    test('a bar is recognised', () {
      final result = observe(<String, double>{
        'bar': 0.85,
        'beer': 0.80,
        'bottle': 0.70,
        'stool': 0.64,
      });
      expect(result.location.value, LocationTag.bar);
      expect(result.location.confidence.level.mayPreselect, isTrue);
    });

    test('a train station is recognised', () {
      final result = observe(<String, double>{
        'train station': 0.90,
        'platform': 0.82,
        'train': 0.78,
      });
      expect(result.location.value, LocationTag.trainStation);
      expect(result.location.level, ConfidenceLevel.high);
    });

    test('a gym is recognised', () {
      final result = observe(<String, double>{
        'gym': 0.88,
        'dumbbell': 0.81,
        'treadmill': 0.76,
      });
      expect(result.location.value, LocationTag.gym);
    });

    test('boxing equipment points at the kickboxing class, not the gym', () {
      final result = observe(<String, double>{
        'boxing glove': 0.90,
        'punching bag': 0.86,
        'boxing': 0.82,
      });
      expect(result.location.value, LocationTag.kickboxingClass);
    });

    test('a bookstore is recognised', () {
      final result = observe(<String, double>{
        'bookstore': 0.87,
        'bookshelf': 0.80,
        'book': 0.79,
      });
      expect(result.location.value, LocationTag.bookstore);
    });

    test('a single weak label cannot preselect a location', () {
      // The whole point of the weighting: one generic object is not a room.
      final result = observe(<String, double>{'cup': 0.60});
      expect(result.location.confidence.level.mayPreselect, isFalse);
    });

    test('visible food alone does not imply a restaurant', () {
      // Explicitly required: a plate of food is equally a café, a festival
      // stall or someone's kitchen.
      final result = observe(<String, double>{
        'food': 0.88,
        'plate': 0.80,
      });
      expect(
        result.location.value == LocationTag.restaurant &&
            result.location.confidence.level.mayPreselect,
        isFalse,
      );
      // But the cue itself is fine to report.
      expect(result.observableCues, contains(ObservableCue.food));
    });

    test('conflicting evidence is demoted rather than picked confidently', () {
      // Café and bar labels in equal measure: the honest answer is "not sure",
      // not a confident coin flip.
      final both = observe(<String, double>{
        'cafe': 0.85,
        'coffee': 0.85,
        'bar': 0.85,
        'beer': 0.85,
      });
      final cleanCafe = observe(<String, double>{
        'cafe': 0.85,
        'coffee': 0.85,
      });
      expect(
        both.location.confidence.score,
        lessThan(cleanCafe.location.confidence.score + 1),
        reason: 'a near-tie must not score higher than a clean read',
      );
    });

    test('nothing recognisable yields an unset location and a warning', () {
      final result = observe(<String, double>{'blur': 0.9, 'shadow': 0.8});
      expect(result.location.value, isNull);
      expect(result.location.level, ConfidenceLevel.unknown);
      expect(result.isInconclusive, isTrue);
      expect(result.warnings, contains('scan.warning.nothingRecognised'));
    });

    test('labels below the model confidence floor are ignored', () {
      final result = observe(<String, double>{
        'cafe': 0.20,
        'coffee': 0.15,
      });
      expect(result.location.value, isNull);
    });

    test('generic stop labels never contribute', () {
      final result = observe(<String, double>{
        'person': 0.99,
        'crowd': 0.99,
        'indoor': 0.99,
        'room': 0.99,
      });
      expect(result.detectedLabels, isEmpty);
      expect(result.isInconclusive, isTrue);
    });

    test('cosplay is capped and never becomes a confident answer', () {
      final result = observe(<String, double>{
        'cosplay': 0.95,
        'costume': 0.95,
        'convention': 0.95,
        'wig': 0.95,
        'anime': 0.95,
      });
      if (result.location.value == LocationTag.cosplayEvent) {
        expect(
          result.location.level,
          isNot(ConfidenceLevel.high),
          reason: 'costume labels fire on uniforms and mascots too',
        );
      }
    });
  });

  group('cue inference', () {
    test('a dog is recognised', () {
      final result = observe(<String, double>{'dog': 0.92, 'leash': 0.71});
      expect(result.preselectedCues, contains(ObservableCue.dog));
    });

    test('a book cue is recognised', () {
      final result = observe(<String, double>{'book': 0.89, 'reading': 0.70});
      expect(result.observableCues, contains(ObservableCue.book));
    });

    test('an umbrella maps to the weather cue', () {
      final result = observe(<String, double>{'umbrella': 0.90, 'rain': 0.82});
      expect(result.preselectedCues, contains(ObservableCue.weather));
    });

    test('sports equipment is recognised', () {
      final result = observe(<String, double>{
        'dumbbell': 0.88,
        'treadmill': 0.80,
      });
      expect(result.preselectedCues, contains(ObservableCue.sportsEquipment));
    });

    test('a drink is recognised', () {
      final result = observe(<String, double>{'beer': 0.90, 'bottle': 0.75});
      expect(result.preselectedCues, contains(ObservableCue.drink));
    });

    test('weak cue evidence is offered but not preselected', () {
      final result = observe(<String, double>{'ball': 0.60});
      expect(result.preselectedCues, isNot(contains(
        ObservableCue.sportsEquipment,
      )));
    });
  });

  group('cues about a person are never inferred', () {
    test('no rule exists for any blocked cue', () {
      // A rule added for one of these would leak it into scans, so the rule
      // table itself is asserted rather than only the output.
      for (final blocked in ScanHeuristics.neverInferred) {
        expect(
          ScanHeuristics.cueRules.containsKey(blocked),
          isFalse,
          reason: '${blocked.name} must have no detection rule',
        );
      }
    });

    test('labels that might tempt one produce none of them', () {
      final result = observe(<String, double>{
        'smile': 0.99,
        'face': 0.99,
        'person': 0.99,
        'people': 0.99,
        'crowd': 0.99,
        'hair': 0.99,
        'fashion': 0.99,
        'dress': 0.99,
      });
      for (final blocked in ScanHeuristics.neverInferred) {
        expect(
          result.observableCues.containsKey(blocked),
          isFalse,
          reason: '${blocked.name} was inferred from an image',
        );
      }
    });

    test('label rules never produce group size', () {
      // Coarse head-counting is allowed, but it comes from a generic person
      // detector via PersonPresence - never from venue label heuristics, which
      // have no business inferring how many people are in a room from the fact
      // that it looks like a cafe.
      final observation = observe(<String, double>{
        'cafe': 0.9,
        'person': 0.99,
        'crowd': 0.99,
      });
      expect(observation.personPresence.groupSize, GroupSize.unknown);
    });

    test('no identity or demographic field exists anywhere in the model', () {
      // This is the boundary that did not move. Counting people is scene
      // description; describing or identifying them is not, and no amount of
      // product pressure makes a field like these acceptable.
      final json = observe(<String, double>{'cafe': 0.9}).toJson().toString();
      for (final forbidden in <String>[
        'identity',
        'gender',
        'age',
        'ethnic',
        'race',
        'attractive',
        'emotion',
        'mood',
        'orientation',
        'relationship',
        'single',
        'interest',
        'consent',
        'vulnerab',
        'embedding',
        'landmark',
        'faceid',
        'trackid',
      ]) {
        expect(
          json.toLowerCase().contains(forbidden),
          isFalse,
          reason: 'model exposes "$forbidden"',
        );
      }
    });
  });

  group('noise level', () {
    test('is derived from a confident location', () {
      final result = observe(<String, double>{
        'nightclub': 0.92,
        'dance floor': 0.88,
        'dj': 0.80,
      });
      expect(result.location.value, LocationTag.club);
      expect(result.noiseLevel.value, NoiseLevel.veryLoud);
    });

    test('is never more confident than the location it came from', () {
      final result = observe(<String, double>{
        'nightclub': 0.92,
        'dance floor': 0.88,
        'dj': 0.80,
      });
      expect(result.noiseLevel.level.index,
          greaterThanOrEqualTo(result.location.level.index));
    });

    test('stays unset when the location is uncertain', () {
      final result = observe(<String, double>{'cup': 0.60});
      expect(result.noiseLevel.value, isNull);
    });
  });

  group('activity inference', () {
    test('a gym suggests exercising', () {
      final result = observe(<String, double>{
        'gym': 0.90,
        'treadmill': 0.85,
        'exercise': 0.80,
      });
      expect(result.activity.value, ActivityTag.exercising);
    });

    test('a station suggests commuting', () {
      final result = observe(<String, double>{
        'train station': 0.90,
        'platform': 0.85,
      });
      expect(result.activity.value, ActivityTag.commuting);
    });
  });

  group('multi-frame merging', () {
    test('a label in every frame beats one seen once', () {
      final merged = normalizer.mergeFrames(
        id: 'merged',
        perFrameLabels: <List<ScoredLabel>>[
          labels(<String, double>{'cafe': 0.85, 'coffee': 0.82}),
          labels(<String, double>{'cafe': 0.86, 'coffee': 0.84}),
          labels(<String, double>{'cafe': 0.84, 'nightclub': 0.83}),
        ],
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );
      expect(merged.location.value, LocationTag.cafe);
      expect(merged.frameCount, 3);
    });

    test('a single misread frame does not decide the result', () {
      final merged = normalizer.mergeFrames(
        id: 'merged',
        perFrameLabels: <List<ScoredLabel>>[
          labels(<String, double>{'bookstore': 0.88, 'bookshelf': 0.85}),
          labels(<String, double>{'bookstore': 0.87, 'book': 0.84}),
          // One frame catching a passing label at high confidence.
          labels(<String, double>{'nightclub': 0.95}),
        ],
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );
      expect(merged.location.value, LocationTag.bookstore);
    });

    test('an empty frame set is inconclusive rather than an error', () {
      final merged = normalizer.mergeFrames(
        id: 'empty',
        perFrameLabels: const <List<ScoredLabel>>[],
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );
      expect(merged.isInconclusive, isTrue);
      expect(merged.frameCount, 0);
    });

    test('merging is deterministic', () {
      List<List<ScoredLabel>> frames() => <List<ScoredLabel>>[
            labels(<String, double>{'bar': 0.85, 'beer': 0.83}),
            labels(<String, double>{'bar': 0.84, 'cocktail': 0.80}),
          ];
      final first = normalizer.mergeFrames(
        id: 'a',
        perFrameLabels: frames(),
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );
      final second = normalizer.mergeFrames(
        id: 'a',
        perFrameLabels: frames(),
        source: FrameSourceKind.fake,
        capturedAt: capturedAt,
      );
      expect(first.location.value, second.location.value);
      expect(
        first.location.confidence.score,
        second.location.confidence.score,
      );
    });
  });

  group('serialization', () {
    test('an observation survives a JSON round trip', () {
      final original = observe(<String, double>{
        'cafe': 0.88,
        'coffee': 0.84,
        'dog': 0.91,
      });
      final restored = EnvironmentalObservation.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.location.value, original.location.value);
      expect(restored.location.level, original.location.level);
      expect(
        restored.observableCues.keys.toSet(),
        original.observableCues.keys.toSet(),
      );
      expect(restored.capturedAt.toUtc(), original.capturedAt.toUtc());
    });

    test('confidence survives a round trip', () {
      const original = FieldConfidence(
        ConfidenceLevel.medium,
        score: 55,
        evidence: <String>['coffee', 'mug'],
      );
      final restored = FieldConfidence.fromJson(original.toJson());
      expect(restored.level, ConfidenceLevel.medium);
      expect(restored.score, 55);
      expect(restored.evidence, <String>['coffee', 'mug']);
    });

    test('an unknown confidence level degrades rather than throwing', () {
      final restored = FieldConfidence.fromJson(<String, Object?>{
        'level': 'telepathic',
        'score': 10,
      });
      expect(restored.level, ConfidenceLevel.unknown);
    });
  });

  group('mapping to a ContextSnapshot', () {
    const mapper = ContextSnapshotMapper();

    test('preselects only what the scan was confident about', () {
      final observation = observe(<String, double>{
        'cafe': 0.88,
        'coffee': 0.85,
        'mug': 0.75,
      });
      final initial = mapper.initialFrom(observation);
      expect(initial.location, LocationTag.cafe);
      // Never inferred, so never preset.
      expect(initial.groupSize, isNull);
      expect(initial.eyeContact, isFalse);
      expect(initial.isWorking, isFalse);
      expect(initial.isUsingHeadphones, isFalse);
    });

    test('a low-confidence guess is not preselected', () {
      final observation = observe(<String, double>{'cup': 0.60});
      final initial = mapper.initialFrom(observation);
      expect(initial.location, isNull);
    });

    test('the snapshot is tagged as a camera scan', () {
      final snapshot = mapper.toSnapshot(
        const ConfirmedScanContext(
          observationId: 'x',
          location: LocationTag.cafe,
        ),
      );
      expect(snapshot.source, ContextSource.cameraScan);
      expect(snapshot.location, LocationTag.cafe);
    });

    test('unset fields fall back to the honest defaults', () {
      final snapshot = mapper.toSnapshot(
        const ConfirmedScanContext(observationId: 'x'),
      );
      expect(snapshot.location, LocationTag.other);
      expect(snapshot.groupSize, GroupSize.unknown);
      expect(snapshot.discouragesApproach, isFalse);
    });

    test('user-set caution flags survive into the snapshot', () {
      final snapshot = mapper.toSnapshot(
        const ConfirmedScanContext(
          observationId: 'x',
          location: LocationTag.cafe,
          isWorking: true,
          isUsingHeadphones: true,
        ),
      );
      expect(snapshot.isWorking, isTrue);
      expect(snapshot.isUsingHeadphones, isTrue);
      expect(snapshot.discouragesApproach, isTrue);
    });
  });
}
