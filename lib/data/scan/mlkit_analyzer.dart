import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../domain/scan/environmental_observation.dart';
import '../../domain/scan/observation_normalizer.dart';
import '../../domain/scan/vision_analyzer.dart';

/// The shipping analyzer: on-device ML Kit image labeling.
///
/// Image labeling only. No object detection, no text recognition, and
/// emphatically no face detection: labels answer "what kind of place is this",
/// which is the only question the scan asks.
///
/// Everything runs on the device. No image, and no derived data, leaves it.
/// A remote analyzer could implement [EnvironmentalVisionAnalyzer] instead,
/// but is deliberately not the default path and is not required for release.
class OnDeviceEnvironmentalVisionAnalyzer
    implements EnvironmentalVisionAnalyzer {
  OnDeviceEnvironmentalVisionAnalyzer({
    ObservationNormalizer normalizer = const ObservationNormalizer(),
    double minimumModelConfidence = 0.5,
  })  : _normalizer = normalizer,
        _labeler = ImageLabeler(
          options: ImageLabelerOptions(
            // The normalizer applies its own, higher floor. This one only
            // trims the long tail before it crosses the plugin boundary.
            confidenceThreshold: minimumModelConfidence,
          ),
        );

  final ObservationNormalizer _normalizer;
  final ImageLabeler _labeler;

  @override
  String get modelInformation => 'mlkit-image-labeling/base';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<EnvironmentalObservation> analyze(CapturedFrameSet frames) async {
    final stopwatch = Stopwatch()..start();
    final perFrame = <List<ScoredLabel>>[];

    for (var index = 0; index < frames.frames.length; index++) {
      final path = frames.frames[index].temporaryPath;
      if (path == null) continue;
      try {
        final labels = await _labeler.processImage(
          InputImage.fromFilePath(path),
        );
        perFrame.add(
          labels
              .map(
                (l) => ScoredLabel(
                  l.label.trim().toLowerCase(),
                  l.confidence,
                  frameIndex: index,
                ),
              )
              .toList(),
        );
      } on Object {
        // One unreadable frame should not lose the other two. An empty list
        // simply contributes nothing to the consensus.
        perFrame.add(const <ScoredLabel>[]);
      }
    }

    stopwatch.stop();

    return _normalizer.mergeFrames(
      id: 'pending',
      perFrameLabels: perFrame,
      source: frames.source,
      capturedAt: frames.capturedAt,
      processingDuration: stopwatch.elapsed,
      modelInformation: modelInformation,
    );
  }

  @override
  Future<void> dispose() => _labeler.close();
}
