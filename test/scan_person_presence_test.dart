import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/scan/confidence.dart';
import 'package:opencue/domain/scan/person_presence.dart';
import 'package:opencue/domain/scan/venue_category.dart';

/// Builds a detection. Boxes are transient and exist only so overlapping
/// detections in one frame can be collapsed.
PersonDetection person(
  double confidence, {
  double left = 0.1,
  double top = 0.1,
  double size = 0.2,
}) =>
    PersonDetection(
      confidence: confidence,
      left: left,
      top: top,
      width: size,
      height: size,
    );

/// Three frames each containing [count] well-separated people.
List<List<PersonDetection>> steady(int count, {int frames = 3}) =>
    List<List<PersonDetection>>.generate(
      frames,
      (_) => List<PersonDetection>.generate(
        count,
        (i) => person(0.9, left: 0.05 + i * 0.15, top: 0.3),
      ),
    );

void main() {
  group('coarse buckets', () {
    test('no detections means nobody visible', () {
      final result = PersonPresence.fromFrames(
        <List<PersonDetection>>[[], [], []],
      );
      expect(result.groupSize, GroupSize.noneVisible);
    });

    test('one stable detection across three frames stays one person', () {
      final result = PersonPresence.fromFrames(steady(1));
      expect(result.groupSize, GroupSize.alone);
      expect(result.confidence.level, ConfidenceLevel.high);
    });

    test('two stable detections stay two people, never six', () {
      // The obvious way to get this wrong is to add the frames together.
      final result = PersonPresence.fromFrames(steady(2));
      expect(result.groupSize, GroupSize.withOneFriend);
      expect(result.rawCountPerFrame, <int>[2, 2, 2]);
    });

    test('four people is a small group', () {
      expect(
        PersonPresence.fromFrames(steady(4)).groupSize,
        GroupSize.smallGroup,
      );
    });

    test('eight people is a large group', () {
      expect(
        PersonPresence.fromFrames(steady(8)).groupSize,
        GroupSize.largeGroup,
      );
    });

    test('no exact count above two is ever exposed', () {
      // The stored answer is a bucket. "Six people" is not a claim the app
      // makes, and is not a value any consumer can read.
      for (final count in <int>[3, 4, 5, 6, 9, 20]) {
        final json = PersonPresence.fromFrames(steady(count)).toJson();
        expect(json.keys.toSet(), <String>{'groupSize', 'confidence'});
        expect(
          GroupSize.values.map((g) => g.name),
          contains(json['groupSize']),
        );
      }
    });
  });

  group('multi-frame handling', () {
    test('frames are combined by consensus, not by sum', () {
      final result = PersonPresence.fromFrames(steady(2));
      expect(result.groupSize, GroupSize.withOneFriend);
    });

    test('a single odd frame does not decide the answer', () {
      final frames = <List<PersonDetection>>[
        ...steady(2, frames: 2),
        <PersonDetection>[person(0.9, left: 0.05, top: 0.3)],
      ];
      final result = PersonPresence.fromFrames(frames);
      expect(result.groupSize, GroupSize.withOneFriend);
      expect(result.confidence.level, isNot(ConfidenceLevel.high));
    });

    test('wildly inconsistent frames produce unknown, not a guess', () {
      final frames = <List<PersonDetection>>[
        <PersonDetection>[],
        steady(1).first,
        List<PersonDetection>.generate(
          5,
          (i) => person(0.9, left: 0.05 + i * 0.15, top: 0.3),
        ),
      ];
      final result = PersonPresence.fromFrames(frames);
      expect(result.groupSize, GroupSize.unknown);
    });

    test('disagreement lowers confidence even when it does not reach unknown',
        () {
      final agreed = PersonPresence.fromFrames(steady(4));
      final mixed = PersonPresence.fromFrames(<List<PersonDetection>>[
        steady(4).first,
        steady(4).first,
        List<PersonDetection>.generate(
          5,
          (i) => person(0.9, left: 0.05 + i * 0.15, top: 0.3),
        ),
      ]);
      expect(agreed.confidence.level, ConfidenceLevel.high);
      expect(mixed.confidence.level, isNot(ConfidenceLevel.high));
    });
  });

  group('false positives', () {
    test('low-confidence detections are ignored', () {
      final frames = List<List<PersonDetection>>.generate(
        3,
        (_) => <PersonDetection>[person(0.3), person(0.4), person(0.2)],
      );
      expect(
        PersonPresence.fromFrames(frames).groupSize,
        GroupSize.noneVisible,
      );
    });

    test('tiny distant detections are ignored', () {
      final frames = List<List<PersonDetection>>.generate(
        3,
        (_) => <PersonDetection>[person(0.9, size: 0.01)],
      );
      expect(
        PersonPresence.fromFrames(frames).groupSize,
        GroupSize.noneVisible,
      );
    });

    test('overlapping boxes in one frame are one person, not two', () {
      final frames = List<List<PersonDetection>>.generate(
        3,
        (_) => <PersonDetection>[
          person(0.92, left: 0.30, top: 0.30, size: 0.20),
          person(0.88, left: 0.32, top: 0.31, size: 0.20),
        ],
      );
      final result = PersonPresence.fromFrames(frames);
      expect(result.groupSize, GroupSize.alone);
      expect(result.deduplicatedWithinFrames, greaterThan(0));
    });

    test('people printed on a poster do not count', () {
      // A station advertisement is full of people, none of whom are there.
      final poster = person(0.99, left: 0.0, top: 0.0, size: 0.5);
      final frames = List<List<PersonDetection>>.generate(
        3,
        (_) => <PersonDetection>[
          person(0.95, left: 0.05, top: 0.05, size: 0.15),
          person(0.93, left: 0.25, top: 0.10, size: 0.15),
          person(0.90, left: 0.70, top: 0.60, size: 0.20),
        ],
      );
      final surfaces =
          List<List<PersonDetection>>.generate(3, (_) => <PersonDetection>[
                poster,
              ]);

      final withoutSuppression = PersonPresence.fromFrames(frames);
      final withSuppression = PersonPresence.fromFrames(
        frames,
        flatSurfacesPerFrame: surfaces,
      );

      expect(withoutSuppression.groupSize, GroupSize.smallGroup);
      expect(withSuppression.groupSize, GroupSize.alone);
      expect(withSuppression.suppressedAsFlatSurface, greaterThan(0));
    });

    test('unusable image quality yields unknown, not nobody visible', () {
      // "Too dark to tell" is not "the room is empty".
      final result = PersonPresence.fromFrames(
        steady(2),
        imageQualityAdequate: false,
      );
      expect(result.groupSize, GroupSize.unknown);
    });
  });

  group('nothing identifying survives', () {
    test('the stored form carries only a bucket and a confidence', () {
      final json = PersonPresence.fromFrames(steady(2)).toJson();
      expect(json.keys.toSet(), <String>{'groupSize', 'confidence'});
    });

    test('no coordinate, box or count of individuals is serialized', () {
      final json = PersonPresence.fromFrames(steady(3)).toJson().toString();
      for (final forbidden in <String>[
        'left',
        'top',
        'width',
        'height',
        'box',
        'bounds',
        'track',
        'embedding',
        'landmark',
      ]) {
        expect(json.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('PersonDetection has no identifier of any kind', () {
      // Nothing on this type could match a detection in one frame to one in
      // another frame, or in another scan. That is what keeps it anonymous.
      const detection = PersonDetection(
        confidence: 0.9,
        left: 0,
        top: 0,
        width: 0.1,
        height: 0.1,
      );
      expect(detection.confidence, 0.9);
      // If a field named like an identifier is ever added, this test is the
      // place it will be noticed.
      expect(
        detection.toString().toLowerCase().contains('id'),
        isFalse,
      );
    });

    test('a round trip preserves only the coarse answer', () {
      final original = PersonPresence.fromFrames(steady(2));
      final restored = PersonPresence.fromJson(original.toJson());
      expect(restored.groupSize, original.groupSize);
      expect(restored.rawCountPerFrame, isEmpty);
    });
  });

  group('labeled project images', () {
    late Directory fixtures;
    late Map<String, Object?> manifest;

    setUpAll(() {
      fixtures = Directory('test/fixtures/environment');
      manifest = jsonDecode(
        File('${fixtures.path}/manifest.json').readAsStringSync(),
      ) as Map<String, Object?>;
    });

    test('the manifest lists every image present', () {
      final listed = (manifest['fixtures']! as List<Object?>)
          .map((f) => (f! as Map<String, Object?>)['file'])
          .toSet();
      final onDisk = fixtures
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.toLowerCase().endsWith('.jpg'))
          .toSet();
      expect(
        listed,
        onDisk,
        reason: 'every labeled image must have ground truth in the manifest',
      );
    });

    test('every image is present and readable', () {
      for (final entry in manifest['fixtures']! as List<Object?>) {
        final fixture = entry! as Map<String, Object?>;
        final file = File('${fixtures.path}/${fixture['file']}');
        expect(file.existsSync(), isTrue, reason: '${fixture['file']}');
        expect(file.lengthSync(), greaterThan(1024));
      }
    });

    test('every ground-truth label names real enum values', () {
      // Guards against the labels drifting out of the vocabulary, and against
      // anyone "fixing" a failing fixture by inventing a category.
      for (final entry in manifest['fixtures']! as List<Object?>) {
        final fixture = entry! as Map<String, Object?>;
        final names = VenueCategory.values.map((v) => v.name).toSet();
        for (final accepted
            in fixture['acceptableVenueCategories']! as List<Object?>) {
          expect(names, contains(accepted), reason: '${fixture['file']}');
        }
        final tags = LocationTag.values.map((v) => v.name).toSet();
        expect(tags, contains(fixture['expectedLocationTag']));

        final group = fixture['expectedGroupSize'];
        if (group != null) {
          expect(
            GroupSize.values.map((g) => g.name),
            contains(group),
            reason: '${fixture['file']}',
          );
        }
      }
    });

    test('the expected venue always maps to the expected engine location', () {
      for (final entry in manifest['fixtures']! as List<Object?>) {
        final fixture = entry! as Map<String, Object?>;
        final category = VenueCategory.values.firstWhere(
          (v) => v.name == fixture['expectedVenueCategory'],
        );
        final acceptable = (fixture['acceptableLocationTags']! as List<Object?>)
            .map((t) => LocationTag.values.firstWhere((l) => l.name == t))
            .toSet();
        expect(
          acceptable,
          contains(category.toLocationTag()),
          reason: '${fixture['file']}: ${category.name} maps to '
              '${category.toLocationTag()?.name}',
        );
      }
    });

    test('each analyzer fixture exists and declares its provenance', () {
      // These are hand-authored reconstructions, not recorded model output.
      // The note is load-bearing: without it someone will later read them as
      // evidence that ML Kit was run, which it has not been.
      for (final entry in manifest['fixtures']! as List<Object?>) {
        final fixture = entry! as Map<String, Object?>;
        final file = File(
          '${fixtures.path}/analyzer_output/${fixture['analyzerFixture']}',
        );
        expect(file.existsSync(), isTrue, reason: '${fixture['file']}');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(json['_note'].toString(), contains('NOT produced by running'));
      }
    });

    test('person detections in the fixtures produce valid coarse answers', () {
      for (final entry in manifest['fixtures']! as List<Object?>) {
        final fixture = entry! as Map<String, Object?>;
        final json = jsonDecode(
          File('${fixtures.path}/analyzer_output/'
                  '${fixture['analyzerFixture']}')
              .readAsStringSync(),
        ) as Map<String, Object?>;

        final frames = (json['personDetections']! as List<Object?>)
            .map(
              (frame) => (frame! as List<Object?>)
                  .map(
                    (c) => person(
                      (c! as num).toDouble(),
                      // Spread the boxes so they do not de-duplicate; the
                      // fixture records confidences, not geometry.
                      left: 0.02 +
                          0.09 *
                              (frame as List<Object?>).indexOf(c).toDouble(),
                      top: 0.3,
                      size: 0.08,
                    ),
                  )
                  .toList(),
            )
            .toList();

        final presence = PersonPresence.fromFrames(frames);
        expect(
          GroupSize.values,
          contains(presence.groupSize),
          reason: '${fixture['file']}',
        );

        final expected = fixture['expectedGroupSize'];
        if (expected != null) {
          expect(
            presence.groupSize.name,
            expected,
            reason: '${fixture['file']}: group size regression',
          );
        }
      }
    });
  });
}
