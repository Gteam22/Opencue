library;

import '../../scan/confidence.dart';
import 'context_signal.dart';

/// Where a fix came from, which decides how much it is trusted.
enum LocationSignalSource {
  /// A cached fix the platform already had. Fast, possibly stale.
  lastKnown,

  /// A fix requested for this acquisition.
  freshFix,

  /// Derived from Wi-Fi or cell towers rather than satellites. Coarser, but
  /// usually available indoors, which is where this app is often used.
  networkAssisted,

  /// A fake, in tests.
  synthetic,
}

/// A device position, normalized.
///
/// **Coordinates are ephemeral.** [latitude] and [longitude] exist so the
/// nearby-place provider can resolve a category, and are dropped by
/// [withoutCoordinates] as soon as that has happened. Nothing persists them:
/// not history, not exports, not presets. What survives fusion is a venue
/// category, a confidence and a timestamp.
class LocationSignal extends ContextSignal {
  const LocationSignal({
    required SignalMetadata metadata,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.bearingDegrees,
    this.source = LocationSignalSource.freshFix,
    this.isApproximate = false,
    this.coordinatesDiscarded = false,
  }) : super(metadata);

  /// An explanation rather than a fix.
  LocationSignal.unavailable({
    required String providerId,
    required SignalUnavailableReason reason,
    required DateTime capturedAt,
    List<String> warnings = const <String>[],
  })  : latitude = null,
        longitude = null,
        accuracyMeters = null,
        speedMetersPerSecond = null,
        bearingDegrees = null,
        source = LocationSignalSource.freshFix,
        isApproximate = false,
        coordinatesDiscarded = false,
        super(SignalMetadata(
          kind: ContextSignalKind.deviceLocation,
          providerId: providerId,
          capturedAt: capturedAt,
          unavailableReason: reason,
          warnings: warnings,
        ));

  final double? latitude;
  final double? longitude;

  /// Radius the platform believes the fix is good to. Larger means the
  /// nearby-place lookup covers more candidates and must claim less.
  final double? accuracyMeters;

  /// Used to tell a platform from a moving train, and a stationary café
  /// customer from someone walking past one. Never used to infer anything
  /// about another person.
  final double? speedMetersPerSecond;

  final double? bearingDegrees;
  final LocationSignalSource source;

  /// True when the user granted only Android's approximate location. The
  /// signal stays usable; the fusion service lowers its weight and prefers
  /// broad categories.
  final bool isApproximate;

  /// True once [withoutCoordinates] has run, so diagnostics can state
  /// positively that the coordinates are gone rather than merely absent.
  final bool coordinatesDiscarded;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether the device appears to be standing still.
  ///
  /// A metre per second is a slow walk. Below it, treating the user as
  /// stationary is what separates "in this café" from "walking past it".
  bool get appearsStationary =>
      speedMetersPerSecond != null && speedMetersPerSecond! < 1.0;

  /// Whether the device is moving at a speed only a vehicle reaches.
  ///
  /// Eight metres per second is roughly 29 km/h — faster than running, so it
  /// implies a train, bus or car, which is what distinguishes a train interior
  /// from a platform.
  bool get appearsInVehicle =>
      speedMetersPerSecond != null && speedMetersPerSecond! > 8.0;

  /// Whether the fix is precise enough to name a single venue.
  ///
  /// Thirty metres is about the width of a small building frontage. Beyond it,
  /// a "nearest place" result is a guess among neighbours.
  bool get isVenuePrecise =>
      !isApproximate && accuracyMeters != null && accuracyMeters! <= 30;

  /// The signal with its coordinates removed.
  ///
  /// Called by the fusion service the moment place resolution is done. Keeping
  /// this on the model rather than in the caller means the privacy guarantee is
  /// one testable method, not a discipline spread across call sites.
  LocationSignal withoutCoordinates() {
    if (!hasCoordinates && coordinatesDiscarded) return this;
    return LocationSignal(
      metadata: metadata,
      accuracyMeters: accuracyMeters,
      speedMetersPerSecond: speedMetersPerSecond,
      bearingDegrees: bearingDegrees,
      source: source,
      isApproximate: isApproximate,
      coordinatesDiscarded: true,
    );
  }

  /// Confidence derived from accuracy, staleness and grant precision.
  ///
  /// A fix is only as good as its worst property, so this takes the lowest of
  /// the three rather than averaging: a very precise fix from four minutes ago
  /// is still a four-minute-old fix.
  static FieldConfidence confidenceFor({
    required double? accuracyMeters,
    required Duration age,
    required bool isApproximate,
  }) {
    if (accuracyMeters == null) {
      return const FieldConfidence(ConfidenceLevel.unknown);
    }
    var level = ConfidenceLevel.high;

    void demoteTo(ConfidenceLevel candidate) {
      if (candidate.index > level.index) level = candidate;
    }

    if (accuracyMeters > 30) demoteTo(ConfidenceLevel.medium);
    if (accuracyMeters > 100) demoteTo(ConfidenceLevel.low);
    if (accuracyMeters > 500) demoteTo(ConfidenceLevel.unknown);

    if (age > const Duration(minutes: 2)) demoteTo(ConfidenceLevel.medium);
    if (age > const Duration(minutes: 10)) demoteTo(ConfidenceLevel.low);
    if (age > const Duration(hours: 1)) demoteTo(ConfidenceLevel.unknown);

    // An approximate grant is a coarse area by construction, so it can never
    // be venue-precise however good the reported accuracy looks.
    if (isApproximate) demoteTo(ConfidenceLevel.medium);

    return FieldConfidence(level);
  }

  @override
  String toString() => 'LocationSignal(${source.name}, '
      'accuracy: $accuracyMeters m, approximate: $isApproximate, '
      'coordinates: ${coordinatesDiscarded ? "discarded" : hasCoordinates}';
}
