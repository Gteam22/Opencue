class TranscriptNormalizer {
  const TranscriptNormalizer();

  String normalize(String input) {
    final widthFolded = String.fromCharCodes(input.runes.map((rune) {
      if (rune >= 0xFF01 && rune <= 0xFF5E) return rune - 0xFEE0;
      return rune == 0x3000 ? 0x20 : rune;
    }));
    var value = widthFolded.toLowerCase();
    const safeVariants = <String, String>{
      'きれい': '綺麗',
      'キレイ': '綺麗',
      '可愛い': 'かわいい',
      'カワイイ': 'かわいい',
      'かっこいい': '格好いい',
      'カッコいい': '格好いい',
      'お仕事': '仕事',
      'ご出身': '出身',
      '何処': 'どこ',
      '何歳': '年齢',
    };
    for (final entry in safeVariants.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value
        .replaceAll(
          RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+'),
          '',
        )
        .trim();
  }

  Set<String> bigrams(String normalized) {
    if (normalized.length < 2) return <String>{normalized};
    final runes = normalized.runes.toList();
    return <String>{
      for (var i = 0; i < runes.length - 1; i++)
        String.fromCharCodes(<int>[runes[i], runes[i + 1]]),
    };
  }
}

