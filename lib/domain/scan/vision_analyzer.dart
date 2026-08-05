import 'environmental_observation.dart';

/// Turns captured frames into a structured description of a place.
///
/// The pipeline depends on this interface, never on a concrete model. The
/// on-device implementation ships now; a remote one could implement the same
/// contract later without touching anything downstream, but is deliberately
/// not required for this release and is not the default path.
///
/// Implementations must not attempt to describe people. See
/// ScanHeuristics.neverInferred for the cues that are blocked outright.
abstract interface class EnvironmentalVisionAnalyzer {
  /// A short name plus model version, shown on the diagnostics screen.
  String get modelInformation;

  /// Whether this analyzer can run right now.
  Future<bool> isAvailable();

  /// Analyses frames and returns the normalised observation.
  ///
  /// Must not retain the frames, write them anywhere, or transmit them.
  /// Deleting any temporary files is the caller's job, not the analyzer's, so
  /// that cleanup happens on the failure path too.
  Future<EnvironmentalObservation> analyze(CapturedFrameSet frames);

  /// Releases any model resources held.
  Future<void> dispose();
}

/// Why a scan could not be completed.
enum ScanFailureReason {
  permissionDenied,
  permissionPermanentlyDenied,
  cameraUnavailable,
  cameraInUse,
  captureFailed,
  analysisFailed,
  cancelled,
}

/// The outcome of one scan attempt.
///
/// A sealed-style result rather than an exception: a scan failing is an
/// ordinary thing that the screen has to render, not an error condition.
class ScanResult {
  const ScanResult.success(
    EnvironmentalObservation this.observation, {
    this.temporaryFilesDeleted = 0,
    this.temporaryFilesRemaining = 0,
  }) : failure = null;

  const ScanResult.failure(
    ScanFailureReason this.failure, {
    this.temporaryFilesDeleted = 0,
    this.temporaryFilesRemaining = 0,
  }) : observation = null;

  final EnvironmentalObservation? observation;
  final ScanFailureReason? failure;

  /// Diagnostics: how many temporary files the service removed.
  final int temporaryFilesDeleted;

  /// Diagnostics: how many it could not remove. Should always be zero.
  final int temporaryFilesRemaining;

  bool get isSuccess => observation != null;

  /// True when every temporary file was cleaned up, on either path.
  bool get isClean => temporaryFilesRemaining == 0;

  /// The localisation key describing a failure.
  String get messageKey {
    switch (failure) {
      case ScanFailureReason.permissionDenied:
        return 'scan.permission.denied';
      case ScanFailureReason.permissionPermanentlyDenied:
        return 'scan.permission.deniedForever';
      case ScanFailureReason.cameraUnavailable:
        return 'scan.error.unavailable';
      case ScanFailureReason.cameraInUse:
        return 'scan.error.inUse';
      case ScanFailureReason.captureFailed:
      case ScanFailureReason.analysisFailed:
        return 'scan.error.failed';
      case ScanFailureReason.cancelled:
      case null:
        return 'scan.error.failed';
    }
  }
}
