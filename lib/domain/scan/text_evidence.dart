import 'venue_category.dart';

/// One normalised piece of text read from the environment.
class TextToken {
  const TextToken(this.normalized, {this.raw = '', this.script = 'latin'});

  /// Lower-cased, punctuation-stripped, width-folded.
  final String normalized;

  /// The original form. Ephemeral: never persisted outside developer mode.
  final String raw;

  /// 'latin', 'japanese' or 'digits'.
  final String script;

  @override
  String toString() => normalized;
}

/// Turns OCR output into evidence about the kind of place.
///
/// This is the signal that was missing, and it is the strongest one available
/// in exactly the environment that failed. A subway is defined by its text:
/// 駅, 番線, 改札, 出口, the line name, the platform number. None of that is
/// visible to an image labeller, all of it is unambiguous to OCR.
///
/// The rules below are about *transit vocabulary*, not about reading signs in
/// general. A word appearing on an advertisement is weak; a word appearing
/// alongside two other transit words is strong. That is what stops the English
/// word "station" in an advert from claiming a station.
class TextEvidence {
  const TextEvidence._();

  /// Characters that carry no meaning for matching.
  static final RegExp _punctuation = RegExp(
    r'''[\s\u3000!-/:-@\[-`{-~。、．，・「」『』（）〔〕【】〜ー―–—…]+''',
  );

  static final RegExp _japanese = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]',
  );

  static final RegExp _digits = RegExp(r'^\d+$');

  /// Full-width ASCII and full-width digits fold to half-width.
  static String _foldWidth(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // U+FF01..U+FF5E map onto U+0021..U+007E.
      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else if (rune == 0x3000) {
        buffer.write(' ');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Splits recognised text into normalised tokens.
  ///
  /// Japanese does not delimit words with spaces, so Japanese runs are kept
  /// whole and matched by substring below rather than by equality.
  static List<TextToken> tokenize(Iterable<String> lines) {
    final tokens = <TextToken>[];
    for (final line in lines) {
      final folded = _foldWidth(line).toLowerCase();
      for (final piece in folded.split(_punctuation)) {
        final trimmed = piece.trim();
        if (trimmed.isEmpty) continue;
        final script = _japanese.hasMatch(trimmed)
            ? 'japanese'
            : _digits.hasMatch(trimmed)
                ? 'digits'
                : 'latin';
        tokens.add(TextToken(trimmed, raw: line, script: script));
      }
    }
    return tokens;
  }

  /// Japanese transit terms, matched as substrings of a token.
  ///
  /// Weights are per distinct term, and the combination rules below matter
  /// more than any single weight: 駅 on its own is a suffix that appears in
  /// plenty of non-station text, while 番線 is almost only ever a platform.
  static const Map<String, int> japaneseTransit = <String, int>{
    '番線': 55, // platform number - very specific
    '改札': 55, // ticket gate
    'のりば': 45, // boarding point
    '乗換': 45, // transfer
    '地下鉄': 50, // subway
    '駅': 40, // station (also a common name suffix)
    '線': 20, // line - weak alone, meaningful with a line name
    '出口': 30, // exit
    '入口': 15, // entrance - generic
    '電車': 40,
    'ホーム': 35,
    '各駅停車': 50,
    '快速': 30,
    '普通': 10,
    '発車': 40,
    '時刻表': 45,
    '運賃': 40,
    '定期券': 45,
    '空港線': 55, // Fukuoka airport line
    '七隈線': 55, // Fukuoka Nanakuma line
    '福岡市地下鉄': 60,
  };

  /// Latin transit terms.
  ///
  /// Weaker than their Japanese counterparts on purpose: English signage in
  /// Japan is supplementary, and these words appear in advertising far more
  /// often than 番線 does.
  static const Map<String, int> latinTransit = <String, int>{
    'subway': 40,
    'metro': 40,
    'platform': 35,
    'station': 25, // the classic false friend - see the advert test
    'railway': 40,
    'jr': 35,
    'exit': 15,
    'gate': 10,
    'track': 20,
    'transfer': 25,
    'fare': 30,
    'timetable': 40,
    'bound': 20,
    'line': 8,
  };

  /// Terms that indicate the text belongs to an advertisement or a shopfront
  /// rather than to transit infrastructure.
  ///
  /// Presence of these damps a weak transit read, which is what keeps a poster
  /// containing the word "station" from being classified as a station.
  static const Set<String> commercialContext = <String>{
    'sale',
    'open',
    'coffee',
    'cafe',
    'menu',
    'shop',
    'store',
    'new',
    'campaign',
    'off',
    'limited',
    'セール',
    'カフェ',
    'メニュー',
    '営業中',
    '新発売',
  };

  /// Scores transit evidence from a set of tokens.
  ///
  /// Returns the accumulated weight and the terms that produced it, so the
  /// fusion layer can explain itself rather than emitting a bare number.
  static TextTransitEvidence scoreTransit(List<TextToken> tokens) {
    var score = 0;
    final matched = <String>{};
    var distinctStrongTerms = 0;
    var hasPlatformNumber = false;
    var hasCommercial = false;

    for (final token in tokens) {
      final text = token.normalized;

      if (commercialContext.contains(text)) {
        hasCommercial = true;
      }

      // Japanese: substring match, because there are no word boundaries.
      japaneseTransit.forEach((term, weight) {
        if (text.contains(term) && matched.add('ja:$term')) {
          score += weight;
          if (weight >= 40) distinctStrongTerms++;
          if (term == '番線' || term == 'のりば') hasPlatformNumber = true;
        }
      });

      // Latin: whole-token match, so 'station' does not fire inside
      // 'stationery' and 'gate' does not fire inside 'gateway'.
      final weight = latinTransit[text];
      if (weight != null && matched.add('en:$text')) {
        score += weight;
        if (weight >= 35) distinctStrongTerms++;
      }
    }

    // A bare number next to a platform term is a platform number.
    if (hasPlatformNumber &&
        tokens.any((t) => t.script == 'digits')) {
      score += 20;
      matched.add('platform-number');
    }

    // One transit-ish word on its own is not a station. Two or more distinct
    // strong terms corroborate each other; a single term is capped below the
    // level that could preselect anything, however heavy its own weight.
    if (distinctStrongTerms <= 1 && !hasPlatformNumber) {
      score = score > 30 ? 30 : score;
      matched.add('capped:single-term');
    }

    // Commercial context alongside weak transit evidence means the words were
    // probably on a poster.
    if (hasCommercial && distinctStrongTerms <= 1) {
      score = (score * 0.5).round();
      matched.add('damped:commercial-context');
    }

    return TextTransitEvidence(
      score: score,
      terms: matched.toList()..sort(),
      hasPlatformNumber: hasPlatformNumber,
      distinctStrongTerms: distinctStrongTerms,
    );
  }

  /// Extracts a station name when the text clearly supports one.
  ///
  /// Only from text actually read. Returns null rather than guessing, and the
  /// caller marks the result as requiring confirmation either way.
  static String? extractStationName(List<TextToken> tokens) {
    for (final token in tokens) {
      final text = token.normalized;
      // 〜駅 with something before it: 西新駅, 天神駅.
      final index = text.indexOf('駅');
      if (index > 0) {
        final name = token.raw.trim();
        if (name.isNotEmpty && name.length <= 24) return name;
      }
      // Latin "<name> station".
      if (text.endsWith(' station') && text.length > 8) {
        return token.raw.trim();
      }
    }
    return null;
  }

  /// The transit subtype the text points at, if any.
  static VenueCategory? subtypeFromText(TextTransitEvidence evidence) {
    if (evidence.score <= 0) return null;
    if (evidence.hasPlatformNumber) return VenueCategory.trainPlatform;
    if (evidence.terms.contains('ja:改札')) {
      return VenueCategory.ticketGateArea;
    }
    if (evidence.terms.contains('ja:出口') ||
        evidence.terms.contains('ja:乗換')) {
      return VenueCategory.stationConcourse;
    }
    return null;
  }
}

/// The outcome of scoring text for transit evidence.
class TextTransitEvidence {
  const TextTransitEvidence({
    required this.score,
    required this.terms,
    this.hasPlatformNumber = false,
    this.distinctStrongTerms = 0,
  });

  static const TextTransitEvidence none =
      TextTransitEvidence(score: 0, terms: <String>[]);

  final int score;
  final List<String> terms;
  final bool hasPlatformNumber;
  final int distinctStrongTerms;

  bool get isStrong => score >= 60;

  @override
  String toString() => 'text($score): ${terms.join(", ")}';
}
