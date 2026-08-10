library;

import '../../scan/confidence.dart';

/// The contract every source of environmental evidence implements.
///
/// Flutter-free, platform-free, and deliberately narrow: a provider is handed
/// a request and returns one normalized signal. GPS APIs, the Places SDK, the
/// microphone and the audio model all live behind implementations of this
/// interface in `lib/data/`, so nothing below `lib/domain/` imports a platform
/// class and the fusion service and the recommendation engine can be tested
/// with fakes on any host.
abstract interface class ContextSignalProvider<T extends ContextSignal> {
  /// A stable identifier for diagnostics and for de-duplicating providers.
  String get id;

  /// Which kind of evidence this provider contributes.
  ContextSignalKind get kind;

  /// Whether this provider can run at all right now: the platform supports
  /// it, it is configured, and any permission it needs has been granted.
  ///
  /// Checked before every acquisition rather than cached, because a permission
  /// can be revoked while the app is running and a one-time grant expires.
  Future<SignalAvailability> checkAvailability();

  /// Acquires one signal, or returns an unavailable signal explaining why.
  ///
  /// Must complete within [ContextAcquisitionRequest.budget] and must honour
  /// cancellation. Must never throw: a failure is a signal carrying warnings,
  /// because one dead provider should degrade the result rather than take the
  /// whole startup down.
  Future<T> acquireSignal(ContextAcquisitionRequest request);

  /// Releases anything held — microphone, location subscription, model — and
  /// is safe to call repeatedly and when nothing was acquired.
  Future<void> release();
}

/// The kinds of evidence the fusion service knows how to weigh.
enum ContextSignalKind {
  deviceLocation,
  nearbyPlaces,
  ambientAudio,
  cameraScan,

  /// A context the user previously confirmed, replayed as evidence.
  recentConfirmedContext,
}

/// Why a provider cannot run, when it cannot.
enum SignalUnavailableReason {
  /// The platform has no implementation. Windows has no Places provider.
  notSupportedOnPlatform,

  /// The provider exists but has no configuration — a Places API key, say.
  notConfigured,

  /// The user has not been asked yet.
  permissionNotRequested,

  permissionDenied,

  /// Denied with "don't ask again". The app must not prompt; only Settings
  /// can change this.
  permissionPermanentlyDenied,

  /// Granted, but the underlying system service is switched off.
  serviceDisabled,

  /// Another app owns the microphone, or the camera is in use.
  resourceBusy,

  /// Reachable but the network is not, and this provider needs it.
  networkUnavailable,

  /// The user has switched this signal off in settings.
  disabledByUser,
}

/// Whether a provider can run, and if not, why.
class SignalAvailability {
  const SignalAvailability.available()
      : isAvailable = true,
        reason = null,
        isApproximateOnly = false;

  const SignalAvailability.unavailable(SignalUnavailableReason this.reason)
      : isAvailable = false,
        isApproximateOnly = false;

  /// Available, but coarsely: Android's approximate-location grant.
  const SignalAvailability.degraded()
      : isAvailable = true,
        reason = null,
        isApproximateOnly = true;

  final bool isAvailable;
  final SignalUnavailableReason? reason;

  /// True when the signal will arrive but at reduced precision, which the
  /// fusion service turns into reduced weight rather than a refusal.
  final bool isApproximateOnly;

  /// Whether the app may show a prompt. Permanent denial and a user's own
  /// "off" switch must never produce one.
  bool get mayPrompt =>
      reason == SignalUnavailableReason.permissionNotRequested ||
      reason == SignalUnavailableReason.permissionDenied;
}

/// What the coordinator asks a provider for.
class ContextAcquisitionRequest {
  const ContextAcquisitionRequest({
    required this.budget,
    this.audioSampleDuration = const Duration(seconds: 3),
    this.requirePreciseLocation = false,
    this.allowNetwork = true,
    this.retainPlaceNames = false,
    this.retainExactCoordinates = false,
    this.reason = ContextAcquisitionReason.appOpened,
  });

  /// How long this provider has. Exceeding it yields whatever partial
  /// evidence exists rather than nothing.
  final Duration budget;

  /// How long to sample ambient audio. Bounded by the presets in settings;
  /// no arbitrary value is exposed to the user.
  final Duration audioSampleDuration;

  final bool requirePreciseLocation;

  /// False when the device is offline or the user has asked to stay local.
  /// A provider that needs the network reports [SignalUnavailableReason
  /// .networkUnavailable] rather than hanging.
  final bool allowNetwork;

  /// Whether a resolved place *name* may travel beyond the fusion step. Off
  /// by default; only the category is kept.
  final bool retainPlaceNames;

  /// Whether latitude and longitude may survive fusion. Off by default, and
  /// intended only for the developer diagnostics screen.
  final bool retainExactCoordinates;

  final ContextAcquisitionReason reason;
}

/// Why detection is running, which the diagnostics screen reports and which
/// decides whether a cached context may be reused.
enum ContextAcquisitionReason {
  appOpened,
  appResumed,
  userRefreshed,
  userRequestedScan,
  contextWentStale,
}

/// Metadata every signal carries, whether it succeeded or not.
///
/// The brief asks each signal to report its source, timestamp, confidence,
/// reliability, warnings, processing duration and provider version. Holding
/// that on one shared object rather than repeating it per signal is what lets
/// the diagnostics screen and the fusion service treat all evidence uniformly.
class SignalMetadata {
  SignalMetadata({
    required this.kind,
    required this.providerId,
    required this.capturedAt,
    this.confidence = FieldConfidence.unknown,
    this.processingDuration = Duration.zero,
    this.providerVersion = 'unknown',
    this.warnings = const <String>[],
    this.unavailableReason,
    this.requiresUserConfirmation = false,
  });

  final ContextSignalKind kind;
  final String providerId;
  final DateTime capturedAt;
  final FieldConfidence confidence;
  final Duration processingDuration;

  /// Model or SDK version, so a change in behaviour can be traced to it.
  final String providerVersion;

  /// Message *keys*, never English prose: the data and domain layers return
  /// keys and the UI localizes them.
  final List<String> warnings;

  /// Set when the signal is an explanation rather than evidence.
  final SignalUnavailableReason? unavailableReason;

  /// Whether this evidence is too weak to act on without asking.
  final bool requiresUserConfirmation;

  bool get isUsable => unavailableReason == null;

  /// How stale the signal is relative to [now].
  Duration ageAt(DateTime now) => now.difference(capturedAt);
}

/// Base class for every normalized signal.
abstract class ContextSignal {
  const ContextSignal(this.metadata);

  final SignalMetadata metadata;

  bool get isUsable => metadata.isUsable;

  ContextSignalKind get kind => metadata.kind;
}
