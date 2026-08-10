library;

import 'package:flutter/foundation.dart';

import 'speech_service.dart';

/// Owns "which line is speaking", so no cue widget carries playback logic.
///
/// One controller is shared through the app. A speak button asks it to play a
/// line's Japanese or Korean and watches [speakingLineId] to show the
/// speaking state. Because the state lives here and not in each button, the
/// rules the brief asks for fall out naturally: only one line plays at a time
/// (starting a new one stops the old), the playing line can be stopped, and the
/// visual indicator is just whichever button matches [speakingLineId].
class SpeechController extends ChangeNotifier {
  SpeechController(this._service);

  final SpeechService _service;

  String? _speakingLineId;
  String? _speakingKey;
  bool _japaneseAvailable = false;
  bool _checkedJapanese = false;
  bool _koreanAvailable = false;
  bool _checkedKorean = false;

  /// A monotonic token so a slow availability check or a completed utterance
  /// from a previous request cannot clear the state of a newer one.
  int _generation = 0;

  /// Whether the platform can speak at all. False on Windows' no-op service, so
  /// the UI hides speech controls entirely.
  bool get isSupported => _service.isSupported;

  /// The line currently speaking, or null. A button compares its own line id
  /// to this to decide whether to show the speaking indicator.
  String? get speakingLineId => _speakingLineId;

  bool isSpeaking(String lineId) => _speakingLineId == lineId;

  bool isSpeakingLanguage(String lineId, String languageCode) =>
      _speakingKey == '$languageCode:$lineId';

  bool? get japaneseAvailable =>
      _checkedJapanese ? _japaneseAvailable : null;

  /// Whether a Korean voice is installed, once checked. Null before the first
  /// check completes, so the UI can wait rather than flash a warning.
  bool? get koreanAvailable => _checkedKorean ? _koreanAvailable : null;

  Future<bool> ensureJapaneseChecked() async {
    if (_checkedJapanese) return _japaneseAvailable;
    if (!_service.isSupported) {
      _japaneseAvailable = false;
      _checkedJapanese = true;
      return false;
    }
    _japaneseAvailable = await _service.isLanguageAvailable(japaneseLocale);
    _checkedJapanese = true;
    notifyListeners();
    return _japaneseAvailable;
  }

  /// Checks once whether Korean can be spoken, caching the result. Cheap to
  /// call repeatedly; the platform query runs only the first time.
  Future<bool> ensureKoreanChecked() async {
    if (_checkedKorean) return _koreanAvailable;
    if (!_service.isSupported) {
      _koreanAvailable = false;
      _checkedKorean = true;
      return false;
    }
    _koreanAvailable = await _service.isLanguageAvailable(koreanLocale);
    _checkedKorean = true;
    notifyListeners();
    return _koreanAvailable;
  }

  /// Speaks a line's Korean, stopping whatever was playing.
  ///
  /// Tapping the speaking line's own button stops it — the same button toggles.
  /// Tapping a different line's button stops the first and starts the second.
  Future<void> toggleKorean({
    required String lineId,
    required String koreanText,
    double rate = 0.5,
  }) =>
      _toggle(
        lineId: lineId,
        text: koreanText,
        languageCode: koreanLocale,
        rate: rate,
      );

  /// Speaks exactly the Japanese field supplied by the line.
  Future<void> toggleJapanese({
    required String lineId,
    required String japaneseText,
    double rate = 0.5,
  }) =>
      _toggle(
        lineId: lineId,
        text: japaneseText,
        languageCode: japaneseLocale,
        rate: rate,
      );

  Future<void> _toggle({
    required String lineId,
    required String text,
    required String languageCode,
    required double rate,
  }) async {
    if (!_service.isSupported || text.trim().isEmpty) return;

    final speakingKey = '$languageCode:$lineId';

    // Tapping the line that is already speaking stops it.
    if (_speakingKey == speakingKey) {
      await stop();
      return;
    }

    // Starting a new line supersedes any previous one.
    final generation = ++_generation;
    await _service.stop();

    _speakingLineId = lineId;
    _speakingKey = speakingKey;
    notifyListeners();

    await _service.speak(text, languageCode: languageCode, rate: rate);

    // Only clear if no newer request has come in while this one was speaking.
    if (generation == _generation && _speakingKey == speakingKey) {
      _speakingLineId = null;
      _speakingKey = null;
      notifyListeners();
    }
  }

  /// Stops any current utterance.
  Future<void> stop() async {
    _generation++;
    await _service.stop();
    if (_speakingLineId != null) {
      _speakingLineId = null;
      _speakingKey = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  /// The BCP-47 tag for Korean. One constant so a future language is a new
  /// method here rather than a string scattered through the widgets.
  static const String koreanLocale = 'ko-KR';
  static const String japaneseLocale = 'ja-JP';
}
