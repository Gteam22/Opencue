import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/data/scan/environmental_scan_service.dart';
import 'package:opencue/data/scan/fake_scan_sources.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/scan/context_snapshot_mapper.dart';
import 'package:opencue/data/transfer/transfer_service.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/scan/vision_analyzer.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('opencue-scan');
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  group('temporary images are deleted', () {
    test('after a successful scan', () async {
      final source = await FakeFrameSource.withRealTempFiles(temp);
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{'cafe': 0.9, 'coffee': 0.85},
        ),
      );

      for (final path in source.temporaryPaths) {
        expect(File(path).existsSync(), isTrue, reason: 'fixture missing');
      }

      final result = await service.scan();

      expect(result.isSuccess, isTrue);
      for (final path in source.temporaryPaths) {
        expect(
          File(path).existsSync(),
          isFalse,
          reason: '$path survived a successful scan',
        );
      }
      expect(result.temporaryFilesRemaining, 0);
      expect(result.isClean, isTrue);
    });

    test('after analysis throws', () async {
      // The important one. A guarantee that only holds on the happy path is
      // not a guarantee, and analysis is the step most likely to blow up.
      final source = await FakeFrameSource.withRealTempFiles(temp);
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: FakeVisionAnalyzer(throwOnAnalyze: true),
      );

      final result = await service.scan();

      expect(result.isSuccess, isFalse);
      expect(result.failure, ScanFailureReason.analysisFailed);
      for (final path in source.temporaryPaths) {
        expect(
          File(path).existsSync(),
          isFalse,
          reason: '$path survived a failed analysis',
        );
      }
      expect(result.isClean, isTrue);
    });

    test('when capture itself throws', () async {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(throwOnCapture: true),
        analyzer: FakeVisionAnalyzer(),
      );
      final result = await service.scan();
      expect(result.isSuccess, isFalse);
      expect(result.isClean, isTrue);
    });

    test('when the camera is unavailable', () async {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(available: false),
        analyzer: FakeVisionAnalyzer(),
      );
      final result = await service.scan();
      expect(result.failure, ScanFailureReason.cameraUnavailable);
      expect(result.isClean, isTrue);
    });

    test('when no frames come back', () async {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(frameCount: 0),
        analyzer: FakeVisionAnalyzer(),
      );
      final result = await service.scan();
      expect(result.failure, ScanFailureReason.captureFailed);
    });

    test('the count of deleted files is reported', () async {
      final source = await FakeFrameSource.withRealTempFiles(temp);
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{'cafe': 0.9},
        ),
      );
      final result = await service.scan();
      expect(result.temporaryFilesDeleted, source.temporaryPaths.length);
    });

    test('a scan leaves nothing behind in the directory at all', () async {
      final source = await FakeFrameSource.withRealTempFiles(temp);
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{'bar': 0.9, 'beer': 0.88},
        ),
      );
      await service.scan();
      expect(
        temp.listSync(),
        isEmpty,
        reason: 'the scan directory should be empty afterwards',
      );
    });
  });

  group('debug image retention', () {
    test('is off by default', () {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(),
        analyzer: FakeVisionAnalyzer(),
      );
      expect(service.retainImagesForDebugging, isFalse);
    });

    test('keeps files only when explicitly switched on', () async {
      final source = await FakeFrameSource.withRealTempFiles(temp);
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{'cafe': 0.9},
        ),
        retainImagesForDebugging: true,
      );

      final result = await service.scan();

      for (final path in source.temporaryPaths) {
        expect(File(path).existsSync(), isTrue);
      }
      // Reported as remaining, not silently as clean.
      expect(result.temporaryFilesRemaining, source.temporaryPaths.length);
      expect(result.isClean, isFalse);
    });
  });

  group('the observation carries no image data', () {
    test('nothing image-like survives into the result', () async {
      final source = await FakeFrameSource.withRealTempFiles(temp);
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{'cafe': 0.9, 'coffee': 0.85},
        ),
      );
      final result = await service.scan();
      final json = result.observation!.toJson().toString().toLowerCase();

      for (final forbidden in <String>[
        'jpg',
        'jpeg',
        'png',
        '.tmp',
        'bytes',
        'base64',
      ]) {
        expect(
          json.contains(forbidden),
          isFalse,
          reason: 'observation JSON mentions "$forbidden"',
        );
      }
      // And no path from the temporary directory leaked into it.
      for (final path in source.temporaryPaths) {
        expect(json.contains(path.toLowerCase()), isFalse);
      }
    });
  });

  group('scan to recommendation', () {
    test('a scan produces a snapshot the engine treats as any other', () async {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(),
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{
            'cafe': 0.9,
            'coffee': 0.86,
            'mug': 0.74,
          },
        ),
      );
      final result = await service.scan();
      expect(result.observation!.location.value, LocationTag.cafe);

      const mapper = ContextSnapshotMapper();
      final confirmed = mapper.initialFrom(result.observation!);
      final snapshot = mapper.toSnapshot(confirmed);

      expect(snapshot.source, ContextSource.cameraScan);
      expect(snapshot.location, LocationTag.cafe);
      // Never inferred, so still unknown until the user says.
      expect(snapshot.groupSize, GroupSize.unknown);
    });

    test('multi-frame merging runs through the service', () async {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(frameCount: 3),
        analyzer: FakeVisionAnalyzer(
          perFrameLabels: const <Map<String, double>>[
            <String, double>{'bookstore': 0.88, 'bookshelf': 0.85},
            <String, double>{'bookstore': 0.87, 'book': 0.84},
            <String, double>{'nightclub': 0.95},
          ],
        ),
      );
      final result = await service.scan();
      expect(result.observation!.location.value, LocationTag.bookstore);
      expect(result.observation!.frameCount, 3);
    });

    test('records how long analysis took, for diagnostics', () async {
      final service = EnvironmentalScanService(
        frameSource: FakeFrameSource(),
        analyzer: FakeVisionAnalyzer(
          labels: const <String, double>{'cafe': 0.9},
        ),
      );
      final result = await service.scan();
      expect(
        result.observation!.processingDuration,
        greaterThanOrEqualTo(Duration.zero),
      );
      expect(result.observation!.modelInformation, 'fake-analyzer/1');
    });
  });

  group('disposal', () {
    test('releases both the camera and the model', () async {
      final source = FakeFrameSource();
      final analyzer = FakeVisionAnalyzer();
      final service = EnvironmentalScanService(
        frameSource: source,
        analyzer: analyzer,
      );
      await service.dispose();
      expect(source.disposed, isTrue);
      expect(analyzer.disposed, isTrue);
    });
  });

  group('exports never carry images', () {
    test('an export containing scan settings has no image data', () {
      final service = TransferService();
      final raw = service.buildExportJson(
        lines: const <OpenerLine>[],
        settings: const AppSettings(
          developerMode: true,
          retainScanImages: true,
        ),
        includeAllLines: true,
      );
      final lower = raw.toLowerCase();
      for (final forbidden in <String>[
        '.jpg',
        '.jpeg',
        '.png',
        'base64',
        'opencue-scan',
        'scan-frame',
      ]) {
        expect(
          lower.contains(forbidden),
          isFalse,
          reason: 'export mentions "$forbidden"',
        );
      }
      // The settings themselves round-trip as plain booleans.
      expect(lower.contains('retainscanimages'), isTrue);
    });
  });
}
