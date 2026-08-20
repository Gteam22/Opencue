/// Produces speakable text without changing the stored or displayed cue.
class TtsTextSanitizer {
  const TtsTextSanitizer();

  String sanitize(String input) {
    var text = input.replaceAll(
      RegExp(
        r'[（(]\s*(?:笑|爆笑|苦笑|w+)\s*[）)]',
        caseSensitive: false,
      ),
      '',
    );
    final runes = text.runes.toList(growable: false);
    final output = <int>[];
    for (var index = 0; index < runes.length; index++) {
      final rune = runes[index];
      if (_isKeycapBase(rune)) {
        var next = index + 1;
        if (next < runes.length && _isVariationSelector(runes[next])) next++;
        if (next < runes.length && runes[next] == 0x20E3) {
          index = next;
          continue;
        }
      }
      if (_isEmojiRune(rune) ||
          _isVariationSelector(rune) ||
          _isEmojiModifier(rune) ||
          rune == 0x200D ||
          rune == 0x20E3 ||
          (rune >= 0xE0020 && rune <= 0xE007F)) {
        continue;
      }
      output.add(rune);
    }
    text = String.fromCharCodes(output)
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' +([、。！？!?])'), r'$1')
        .trim();
    return text;
  }

  bool _isKeycapBase(int rune) =>
      rune == 0x23 || rune == 0x2A || (rune >= 0x30 && rune <= 0x39);

  bool _isVariationSelector(int rune) =>
      (rune >= 0xFE00 && rune <= 0xFE0F) ||
      (rune >= 0xE0100 && rune <= 0xE01EF);

  bool _isEmojiModifier(int rune) => rune >= 0x1F3FB && rune <= 0x1F3FF;

  bool _isEmojiRune(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x1FC00 && rune <= 0x1FFFF) ||
      (rune >= 0x1F1E6 && rune <= 0x1F1FF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2300 && rune <= 0x23FF) ||
      (rune >= 0x2B00 && rune <= 0x2BFF) ||
      rune == 0x00A9 ||
      rune == 0x00AE ||
      rune == 0x2122 ||
      rune == 0x3030 ||
      rune == 0x303D ||
      rune == 0x3297 ||
      rune == 0x3299;
}
