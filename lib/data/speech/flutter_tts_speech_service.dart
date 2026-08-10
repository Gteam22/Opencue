import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/speech/speech_service.dart';

/// A [SpeechService] backed by the platform's own TTS engine via flutter_tts.
///
/// Constructed only where [SpeechCapability.hasImplementation] is true — today
/// that is Android, which uses the device's built-in TTS (typically Google
/// or Samsung), so no voice data ships in the APK and the user's own installed
/// Korean voice is used. The Windows build never constructs this class and so
/// never compiles against the plugin's desktop code, which is the arrangement
/// that keeps a TTS plugin from breaking the desktop build the way an earlier
/// permission plugin did.
///
/// Every method is guarded so a device without a matching voice degrades to
/// silence rather than throwing.
class FlutterTtsSpeechService implements SpeechService {
  FlutterTtsSpeechService() : _tts = FlutterTts() {
    // Await each utterance: speak() should complete when the audio finishes,
    // so the controller can clear the speaking state at the right moment.
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;

  /// Languages the engine reports, resolved once and cached. A set of lowercase
  /// BCP-47 tags.
  Set<String>? _languages;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isLanguageAvailable(String languageCode) async {
    try {
      // flutter_tts exposes both a direct check and a language list; the direct
      // check is more reliable across engines, and the list is a fallback for
      // engines that answer the direct check conservatively.
      final direct = await _tts.isLanguageAvailable(languageCode);
      if (direct == true) return true;

      final languages = await _cachedLanguages();
      final wanted = languageCode.toLowerCase();
      final base = wanted.split('-').first;
      return languages.any(
        (lang) => lang == wanted || lang.startsWith('$base-') || lang == base,
      );
    } on Object {
      // A platform exception here means we genuinely cannot tell; report
      // unavailable so the UI offers guidance rather than a broken button.
      return false;
    }
  }

  Future<Set<String>> _cachedLanguages() async {
    final cached = _languages;
    if (cached != null) return cached;
    try {
      final raw = await _tts.getLanguages;
      final languages = <String>{};
      if (raw is List) {
        for (final entry in raw) {
          if (entry != null) languages.add(entry.toString().toLowerCase());
        }
      }
      _languages = languages;
      return languages;
    } on Object {
      _languages = const <String>{};
      return const <String>{};
    }
  }

  @override
  Future<void> speak(
    String text, {
    required String languageCode,
    double rate = 0.5,
  }) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.setLanguage(languageCode);
      // flutter_tts rate is 0.0-1.0, natural around 0.5 on Android; the
      // caller's value maps straight through, clamped for safety.
      await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
      await _tts.speak(text);
    } on Object {
      // Swallow: a missing voice or a busy engine must not crash the app. The
      // availability check upstream is what prevents this being hit normally.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Nothing to stop, or the engine is gone. Either way there is no error
      // worth surfacing.
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
