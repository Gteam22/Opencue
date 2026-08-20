import 'conversation_models.dart';

/// Fast script-based detection for the three supported conversation inputs.
/// It does not read the output-language setting and works for mixed text.
class ConversationLanguageDetector {
  const ConversationLanguageDetector();

  DetectedLanguage detect(String text) {
    var hangul = 0;
    var kana = 0;
    var cjk = 0;
    var latin = 0;
    for (final rune in text.runes) {
      if ((rune >= 0xAC00 && rune <= 0xD7AF) ||
          (rune >= 0x1100 && rune <= 0x11FF)) {
        hangul++;
      } else if ((rune >= 0x3040 && rune <= 0x30FF) ||
          (rune >= 0x31F0 && rune <= 0x31FF)) {
        kana++;
      } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        cjk++;
      } else if ((rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A)) {
        latin++;
      }
    }
    if (hangul > kana && hangul >= latin / 2) return DetectedLanguage.korean;
    if (kana > 0 || cjk > latin) return DetectedLanguage.japanese;
    if (latin > 0) return DetectedLanguage.english;
    return DetectedLanguage.unknown;
  }
}

