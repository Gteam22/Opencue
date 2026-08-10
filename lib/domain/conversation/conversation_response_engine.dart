import '../enums/enums.dart';
import '../models/opener_line.dart';
import 'conversation_interpreter.dart';
import 'conversation_models.dart';

/// Boundary for a future local/remote generation model. Implementations must
/// apply the same preferences and return library-backed suggestions.
abstract interface class ConversationSuggestionProvider {
  ConversationSuggestionResult suggest({
    required String transcript,
    required List<OpenerLine> library,
    ConversationPreferences preferences = const ConversationPreferences(),
    List<ConversationTurn> history = const <ConversationTurn>[],
    int limit = 3,
    double? transcriptionConfidence,
  });
}

/// Ranks the existing curated library against what was actually said.
/// No network model is involved and adult lines are filtered before scoring.
class ConversationResponseEngine implements ConversationSuggestionProvider {
  const ConversationResponseEngine({
    this.interpreter = const ConversationInterpreter(),
  });

  final ConversationInterpreter interpreter;

  @override
  ConversationSuggestionResult suggest({
    required String transcript,
    required List<OpenerLine> library,
    ConversationPreferences preferences = const ConversationPreferences(),
    List<ConversationTurn> history = const <ConversationTurn>[],
    int limit = 3,
    double? transcriptionConfidence,
  }) {
    final interpretation = interpreter.interpret(transcript, history: history);
    final ranked = <ConversationSuggestion>[];
    for (final line in library) {
      if (!_allowed(line, preferences)) continue;
      final scored = _score(line, interpretation, preferences);
      if (scored.score > 8) ranked.add(scored);
    }
    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0 ? scoreOrder : a.line.id.compareTo(b.line.id);
    });

    final selected = ranked.take(limit).toList();
    var usedFallback = false;
    final lowRecognitionConfidence = transcriptionConfidence != null &&
        transcriptionConfidence >= 0 &&
        transcriptionConfidence < 0.45;
    if (interpretation.confidence < 0.38 || lowRecognitionConfidence) {
      selected.clear();
    }
    if (selected.length < limit) {
      usedFallback = true;
      for (final line in _safeFallbacks(library, preferences)) {
        if (selected.any((item) => item.line.id == line.id)) continue;
        selected.add(ConversationSuggestion(
          line: line,
          score: 5,
          reasons: const <String>['safeFallback'],
        ));
        if (selected.length == limit) break;
      }
    }

    return ConversationSuggestionResult(
      transcript: transcript.trim(),
      interpretation: interpretation,
      suggestions: selected.take(limit).toList(growable: false),
      usedSafeFallback: usedFallback,
      lowRecognitionConfidence: lowRecognitionConfidence,
    );
  }

  bool _allowed(OpenerLine line, ConversationPreferences preferences) {
    if (line.isExitLine) return false;
    final boldness = line.boldness ?? ConversationBoldness.light;
    if (boldness.index > preferences.maxBoldness.index) return false;
    if (!preferences.adultContentEnabled &&
        (boldness.index >= ConversationBoldness.naughty.index ||
            line.category == LineCategory.naughty ||
            line.category == LineCategory.intimate)) {
      return false;
    }
    return true;
  }

  ConversationSuggestion _score(
    OpenerLine line,
    ConversationInterpretation input,
    ConversationPreferences preferences,
  ) {
    var score = 0.0;
    final reasons = <String>[];
    final lineTopics = _topicsFor(line);
    final topicMatches = input.topics.intersection(lineTopics).length;
    if (topicMatches > 0 && !input.topics.contains(ConversationTopic.general)) {
      score += topicMatches * 34;
      reasons.add('topic');
    }

    final lineText = <String>[
      line.japaneseText,
      line.englishMeaning ?? '',
      line.koreanText ?? '',
      line.koreanRomanization ?? '',
      ...line.topics,
    ].join(' ').toLowerCase();
    final overlap = input.tokens.where(lineText.contains).length;
    if (overlap > 0) {
      score += overlap * 6;
      reasons.add('wording');
    }

    // Incoming questions generally need a statement or comeback, while a
    // conversational statement benefits from a natural follow-up question.
    if (input.isQuestion) {
      if (line.usageType == ConversationUsageType.statement) score += 22;
      if (line.usageType == ConversationUsageType.comeback) score += 20;
      if (line.usageType == ConversationUsageType.question) score -= 12;
    } else if (line.usageType == ConversationUsageType.question) {
      score += 10;
    }
    if (line.usageType == ConversationUsageType.game) score -= 4;

    final desiredTones = _tonesFor(preferences.tone);
    if (line.tones.intersection(desiredTones).isNotEmpty) {
      score += 16;
      reasons.add('tone');
    }
    if (preferences.tone == ConversationToneBias.natural &&
        (line.tones.contains(Tone.friendly) ||
            line.tones.contains(Tone.safe))) {
      score += 8;
    }
    if (input.intents.contains(ConversationIntent.compliment) &&
        (line.tones.contains(Tone.witty) || line.tones.contains(Tone.flirty))) {
      score += 9;
    }
    if (input.intents.contains(ConversationIntent.apologize) &&
        line.tones.contains(Tone.safe)) {
      score += 10;
    }
    if (input.intents.contains(ConversationIntent.flirt) &&
        line.tones.contains(Tone.flirty)) {
      score += 12;
    }

    if (preferences.recentLineIds.contains(line.id)) {
      score -= 45;
      reasons.add('recentPenalty');
    }
    final personal = line.personalSignal;
    if (personal != null) score += personal * 6;
    score -= (line.boldness?.index ?? 0) * 0.5;
    return ConversationSuggestion(line: line, score: score, reasons: reasons);
  }

  Set<Tone> _tonesFor(ConversationToneBias bias) => switch (bias) {
        ConversationToneBias.natural => <Tone>{Tone.safe, Tone.friendly},
        ConversationToneBias.funny =>
          <Tone>{Tone.witty, Tone.humorous, Tone.playful},
        ConversationToneBias.flirty =>
          <Tone>{Tone.flirty, Tone.romantic, Tone.teasing},
        ConversationToneBias.gentleman =>
          <Tone>{Tone.classy, Tone.safe, Tone.confident},
        ConversationToneBias.bold =>
          <Tone>{Tone.direct, Tone.confident, Tone.suggestive},
      };

  Set<ConversationTopic> _topicsFor(OpenerLine line) {
    final source = '${line.category.name} ${line.topics.join(' ')} '
        '${line.englishMeaning ?? ''}'.toLowerCase();
    final out = <ConversationTopic>{};
    const terms = <ConversationTopic, List<String>>{
      ConversationTopic.weekend: <String>['weekend'],
      ConversationTopic.work: <String>['work', 'job', 'career'],
      ConversationTopic.hobbies: <String>['hobby', 'free time'],
      ConversationTopic.food: <String>['food', 'eat', 'restaurant'],
      ConversationTopic.drinks: <String>['drink', 'beer', 'wine'],
      ConversationTopic.music: <String>['music', 'concert', 'song'],
      ConversationTopic.travel: <String>['travel', 'trip'],
      ConversationTopic.relationships: <String>['relationship'],
      ConversationTopic.dating: <String>['date', 'dating'],
      ConversationTopic.kissing: <String>['kiss', 'kissing'],
      ConversationTopic.compatibility: <String>['compatibility', 'compatible'],
      ConversationTopic.dominance: <String>[
        'dominance', 'dominant', 'submissive',
      ],
      ConversationTopic.compliments: <String>[
        'compliment', 'beautiful', 'cute',
      ],
    };
    for (final entry in terms.entries) {
      if (entry.value.any(source.contains)) out.add(entry.key);
    }
    if (out.isEmpty) out.add(ConversationTopic.general);
    return out;
  }

  Iterable<OpenerLine> _safeFallbacks(
    List<OpenerLine> library,
    ConversationPreferences preferences,
  ) sync* {
    // Prefer known, broadly useful curated lines, then any safe friendly item.
    const ids = <String>[
      'seed-universal-10',
      'seed-universal-05',
      'seed-meetup-or-language-exchange-01',
      'seed-universal-02',
    ];
    for (final id in ids) {
      for (final line in library) {
        if (line.id == id && _allowed(line, preferences)) yield line;
      }
    }
    for (final line in library) {
      if (_allowed(line, preferences) &&
          !line.manualOnly &&
          (line.tones.contains(Tone.safe) ||
              line.tones.contains(Tone.friendly))) {
        yield line;
      }
    }
  }
}
