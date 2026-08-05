import 'dart:io';

import '../../domain/scan/environmental_observation.dart';
import '../../domain/scan/observation_normalizer.dart';
import '../../domain/scan/vision_analyzer.dart';

/// A frame source that returns fixture bytes.
///
/// Every unit and widget test uses this, which is the whole reason
/// [ImageFrameSource] is an interface: the scan pipeline is fully testable
/// with no camera, no emulator and no model.
class FakeFrameSource implements ImageFrameSource {
  FakeFrameSource({
    this.frameCount = 3,
    this.available = true,
    this.throwOnCapture = false,
    this.temporaryPaths = const <String>[],
    DateTime? capturedAt,
  }) : _capturedAt = capturedAt ?? DateTime.utc(2026, 5, 1, 20, 30);

  final int frameCount;
  final bool available;
  final bool throwOnCapture;

  /// Real paths on disk, so cleanup can be asserted against the filesystem.
  final List<String> temporaryPaths;

  final DateTime _capturedAt;

  int captureCount = 0;
  bool disposed = false;

  @override
  String get id => 'fake';

  @override
  FrameSourceKind get kind => FrameSourceKind.fake;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<CapturedFrameSet> captureFrames() async {
    captureCount++;
    if (throwOnCapture) {
      throw StateError('capture failed');
    }
    return CapturedFrameSet(
      frames: <CapturedFrame>[
        for (var i = 0; i < frameCount; i++)
          CapturedFrame(
            bytes: const <int>[0xFF, 0xD8, 0xFF],
            temporaryPath:
                i < temporaryPaths.length ? temporaryPaths[i] : null,
            width: 1280,
            height: 720,
          ),
      ],
      source: FrameSourceKind.fake,
      capturedAt: _capturedAt,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  /// Creates real temporary files so a test can assert they get deleted.
  static Future<FakeFrameSource> withRealTempFiles(
    Directory directory, {
    int frameCount = 3,
  }) async {
    final paths = <String>[];
    for (var i = 0; i < frameCount; i++) {
      final file = File('${directory.path}/scan-frame-$i.jpg');
      await file.writeAsBytes(const <int>[0xFF, 0xD8, 0xFF]);
      paths.add(file.path);
    }
    return FakeFrameSource(frameCount: frameCount, temporaryPaths: paths);
  }
}

/// An analyzer that returns labels supplied by the test.
///
/// It runs the real [ObservationNormalizer], so the heuristics under test are
/// the ones that ship; only the model is replaced.
class FakeVisionAnalyzer implements EnvironmentalVisionAnalyzer {
  FakeVisionAnalyzer({
    this.labels = const <String, double>{},
    this.perFrameLabels,
    this.available = true,
    this.throwOnAnalyze = false,
  });

  /// Labels returned for a single-frame analysis.
  final Map<String, double> labels;

  /// Labels per frame, when testing the merge path.
  final List<Map<String, double>>? perFrameLabels;

  final bool available;
  final bool throwOnAnalyze;

  bool disposed = false;
  int analyzeCount = 0;

  static const ObservationNormalizer _normalizer = ObservationNormalizer();

  @override
  String get modelInformation => 'fake-analyzer/1';

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<EnvironmentalObservation> analyze(CapturedFrameSet frames) async {
    analyzeCount++;
    if (throwOnAnalyze) {
      throw StateError('analysis failed');
    }
    final perFrame = perFrameLabels;
    if (perFrame != null) {
      return _normalizer.mergeFrames(
        id: 'fake',
        perFrameLabels: perFrame
            .map(
              (m) => m.entries
                  .map((e) => ScoredLabel(e.key, e.value))
                  .toList(),
            )
            .toList(),
        source: frames.source,
        capturedAt: frames.capturedAt,
        modelInformation: modelInformation,
      );
    }
    return _normalizer.normalize(
      id: 'fake',
      labels:
          labels.entries.map((e) => ScoredLabel(e.key, e.value)).toList(),
      source: frames.source,
      capturedAt: frames.capturedAt,
      frameCount: frames.frames.length,
      modelInformation: modelInformation,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
