import '../../domain/speech/speech_service.dart';

// Conditional import: the io variant knows about dart:io and flutter_tts; the
// stub is web-safe and pulls in neither. Whichever resolves provides both
// `platformHasSpeechImplementation` and `createPlatformSpeechService`, so this
// file - and everything above it - stays free of any platform import.
import 'speech_service_factory_stub.dart'
    if (dart.library.io) 'speech_service_factory_io.dart';

/// Whether this build can speak.
///
/// Capability, not platform name, matching ScanCapability. The app asks this
/// rather than `Platform.isAndroid`, so adding iOS or a working desktop engine
/// later is a change in the factory and nowhere else.
class SpeechCapability {
  const SpeechCapability._();

  /// True when a real TTS implementation exists for this platform. Android
  /// only for now; see the io factory for why Windows is deliberately off.
  static bool get hasImplementation => platformHasSpeechImplementation;
}

/// Builds the right [SpeechService] for this platform.
///
/// A real engine where [SpeechCapability.hasImplementation] is true, and a
/// [NullSpeechService] everywhere else, so callers construct unconditionally
/// and let the UI hide controls when [SpeechService.isSupported] is false.
SpeechService createSpeechService() {
  if (!SpeechCapability.hasImplementation) return const NullSpeechService();
  return createPlatformSpeechService();
}
