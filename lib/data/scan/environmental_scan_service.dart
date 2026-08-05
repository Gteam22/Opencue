import 'dart:io';

import '../../core/id_generator.dart';
import '../../domain/scan/environmental_observation.dart';
import '../../domain/scan/vision_analyzer.dart';

/// Runs one scan: capture, analyse, then delete every image.
///
/// The cleanup contract is the reason this class exists rather than the screen
/// calling the analyzer directly. Deleting temporary files happens in a
/// `finally`, so it runs when analysis succeeds, when analysis throws, when
/// capture returns nothing, and when the user cancels midway. A privacy
/// guarantee that only holds on the happy path is not a guarantee.
///
/// Frames are never written anywhere by this service. If a frame source hands
/// over a file it created, it declares that path on the frame's
/// `temporaryPath`, and this service removes it.
class EnvironmentalScanService {
  EnvironmentalScanService({
    required ImageFrameSource frameSource,
    required EnvironmentalVisionAnalyzer analyzer,
    IdGenerator? ids,
    this.retainImagesForDebugging = false,
  })  : _frameSource = frameSource,
        _analyzer = analyzer,
        _ids = ids ?? IdGenerator();

  final ImageFrameSource _frameSource;
  final EnvironmentalVisionAnalyzer _analyzer;
  final IdGenerator _ids;

  /// Developer setting. Off by default and expected to stay off.
  ///
  /// When on, temporary files are left in app-private storage instead of being
  /// deleted. Nothing else changes: they are still never uploaded, never added
  /// to the gallery and never included in an export.
  final bool retainImagesForDebugging;

  /// The paths the last scan removed, for the diagnostics screen.
  List<String> get lastDeletedPaths => List.unmodifiable(_lastDeleted);
  final List<String> _lastDeleted = <String>[];

  /// Captures and analyses. Never throws; failures come back as a [ScanResult].
  ///
  /// Structured so that cleanup happens before the result is built, not in a
  /// `finally` after the return value is already fixed. That way the counts
  /// are part of the result and the privacy tests can assert on them.
  Future<ScanResult> scan() async {
    _lastDeleted.clear();
    final stopwatch = Stopwatch()..start();

    CapturedFrameSet? frames;
    EnvironmentalObservation? observation;
    ScanFailureReason? failure;

    try {
      if (!await _frameSource.isAvailable()) {
        failure = ScanFailureReason.cameraUnavailable;
      } else {
        frames = await _frameSource.captureFrames();
        if (frames.isEmpty) {
          failure = ScanFailureReason.captureFailed;
        } else {
          final analysed = await _analyzer.analyze(frames);
          stopwatch.stop();
          observation = EnvironmentalObservation(
            id: _ids.scanId(),
            capturedAt: frames.capturedAt,
            source: frames.source,
            detectedLabels: analysed.detectedLabels,
            location: analysed.location,
            activity: analysed.activity,
            noiseLevel: analysed.noiseLevel,
            observableCues: analysed.observableCues,
            warnings: analysed.warnings,
            processingDuration: stopwatch.elapsed,
            frameCount: frames.frames.length,
            modelInformation: _analyzer.modelInformation,
          );
        }
      }
    } on Object {
      failure = ScanFailureReason.analysisFailed;
    }

    // Unconditional, and before the result is constructed: this runs whether
    // analysis succeeded, threw, or was never reached. A privacy guarantee
    // that only holds on the happy path is not a guarantee.
    final cleanup = await _cleanUp(frames);

    if (observation != null) {
      return ScanResult.success(
        observation,
        temporaryFilesDeleted: cleanup.deleted,
        temporaryFilesRemaining: cleanup.remaining,
      );
    }
    return ScanResult.failure(
      failure ?? ScanFailureReason.analysisFailed,
      temporaryFilesDeleted: cleanup.deleted,
      temporaryFilesRemaining: cleanup.remaining,
    );
  }

  Future<({int deleted, int remaining})> _cleanUp(
    CapturedFrameSet? frames,
  ) async {
    if (frames == null) return (deleted: 0, remaining: 0);

    final paths = frames.temporaryPaths;
    if (retainImagesForDebugging) {
      // Deliberately kept. The setting carries its own warning, the files stay
      // in app-private storage, and they are excluded from exports.
      return (deleted: 0, remaining: paths.length);
    }

    var deleted = 0;
    var remaining = 0;
    for (final path in paths) {
      try {
        final file = File(path);
        // No exists() check first: the goal is that the file is not there, so
        // "already gone" is success, and checking first would leave a race
        // between the check and the delete. (existsSync is also what
        // avoid_slow_async_io wants over the async variant.)
        if (file.existsSync()) {
          await file.delete();
        }
        deleted++;
        _lastDeleted.add(path);
      } on PathNotFoundException {
        // Already gone. That is the desired end state.
        deleted++;
        _lastDeleted.add(path);
      } on Object {
        // A file that will not delete is worth surfacing rather than swallowing
        // silently, so it is counted and shown on the diagnostics screen.
        remaining++;
      }
    }
    return (deleted: deleted, remaining: remaining);
  }

  Future<void> dispose() async {
    await _frameSource.dispose();
    await _analyzer.dispose();
  }
}
