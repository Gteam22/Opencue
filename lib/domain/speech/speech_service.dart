library;

/// A spoken-language controller, kept free of any TTS plugin so the domain and
/// the widgets depend on this interface and never on a platform package.
///
/// Why an interface at all: the concrete implementation wraps a Flutter plugin
/// whose Windows support is C++ that has broken the desktop build once already
/// (permission_handler). Isolating it here means the Windows build can inject a
/// no-op implementation and never compile the plugin, while Android injects the
/// real one — the same seam the context signal providers use.
///
/// It is deliberately small: speak one string in one language, stop, and report
/// whether a language can be spoken. Everything about *which* line is playing
/// and how the button looks lives in the widget layer, not here.
abstract interface class SpeechService {
  /// Whether this platform has any speech support at all. False on the no-op
  /// implementation, so the UI can hide speech controls wholesale on Windows.
  bool get isSupported;

  /// Whether a voice for [languageCode] (a BCP-47 tag such as 'ko-KR') is
  /// installed and usable. Checked before showing a speak button, so a missing
  /// Korean voice produces guidance rather than a silent failure.
  Future<bool> isLanguageAvailable(String languageCode);

  /// Speaks [text] in [languageCode] at [rate] (0.0–1.0, where 0.5 is a
  /// normal pace). Completes when the utterance finishes or is stopped.
  ///
  /// Speaks the string it is given verbatim. Callers pass the Korean Hangul,
  /// never the romanization: the Roman text is a reading aid for the user's
  /// eyes and would be mispronounced by a Korean voice.
  ///
  /// Must never throw. A device with no matching voice returns without
  /// speaking rather than crashing.
  Future<void> speak(
    String text, {
    required String languageCode,
    double rate = 0.5,
    int? turnId,
    int? utteranceId,
  });

  /// Stops any current utterance immediately. Safe to call when nothing is
  /// playing.
  Future<void> stop();

  /// Releases platform resources. Safe to call more than once.
  Future<void> dispose();
}

/// A [SpeechService] that does nothing, for platforms without speech and for
/// tests.
///
/// [isSupported] is false, so a UI that checks it shows no speech controls at
/// all. Every method is safe and silent. This is what the Windows build binds,
/// so the Windows target never references the TTS plugin.
class NullSpeechService implements SpeechService {
  const NullSpeechService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => false;

  @override
  Future<void> speak(
    String text, {
    required String languageCode,
    double rate = 0.5,
    int? turnId,
    int? utteranceId,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
