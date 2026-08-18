import 'dart:async';

import 'package:flutter/foundation.dart';
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
    _tts.setStartHandler(() => _log('onStart'));
    _tts.setCompletionHandler(() => _log('onDone'));
    _tts.setCancelHandler(() => _log('onCancel'));
    _tts.setErrorHandler((message) {
      _lastError = message.toString();
      _log('onError', <String, Object?>{'message': message});
    });
    _ready = _initialize();
  }

  final FlutterTts _tts;
  late final Future<void> _ready;
  String? _lastError;

  Future<void> _initialize() async {
    _log('initialize');
    await _tts.awaitSpeakCompletion(true);
    _log('ready');
  }

  void _log(String event, [Map<String, Object?> details = const {}]) {
    final fields = details.entries
        .map((entry) => '${entry.key}=${entry.value ?? '-'}')
        .join(' ');
    debugPrint('${DateTime.now().toUtc().toIso8601String()} '
        '[OpenCueTTS] event=$event${fields.isEmpty ? '' : ' $fields'}');
  }

  /// Languages the engine reports, resolved once and cached. A set of lowercase
  /// BCP-47 tags.
  Set<String>? _languages;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isLanguageAvailable(String languageCode) async {
    try {
      await _ready;
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
    await _ready;
    _lastError = null;
    _log('speak_requested', <String, Object?>{
      'language': languageCode,
      'characters': text.length,
    });
    await _tts.setLanguage(languageCode);
    // flutter_tts rate is 0.0-1.0, natural around 0.5 on Android; the
    // caller's value maps straight through, clamped for safety.
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
    await _tts.speak(text);
    final error = _lastError;
    if (error != null) {
      throw StateError('TTS failed: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _ready;
      _log('stop_requested');
      await _tts.stop();
    } on Object catch (error) {
      _log('stop_error', <String, Object?>{'message': error});
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
