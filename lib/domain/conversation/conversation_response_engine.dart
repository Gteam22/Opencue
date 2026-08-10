import '../enums/enums.dart';
import '../models/opener_line.dart';
import 'conversation_intent.dart';
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
    String? semanticIntentId,
    double? semanticConfidence,
    String? lockedIntentId,
    Set<String> excludedLineIds = const <String>{},
    bool moreGeneration = false,
    ConversationInterpretation? activeInterpretation,
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
    String? semanticIntentId,
    double? semanticConfidence,
    String? lockedIntentId,
    Set<String> excludedLineIds = const <String>{},
    bool moreGeneration = false,
    ConversationInterpretation? activeInterpretation,
  }) {
    var interpretation = activeInterpretation ??
        interpreter.interpret(
          transcript,
          history: history,
          semanticIntentId: semanticIntentId,
          semanticConfidence: semanticConfidence,
        );
    if (lockedIntentId != null) {
      interpretation = _lockIntent(interpretation, lockedIntentId);
    }

    final family = _responseFamily(
      library,
      interpretation,
      preferences,
      excludedLineIds,
    );
    final ranked = <ConversationSuggestion>[];
    for (final line in family) {
      final scored = _score(line, interpretation, preferences);
      final precise = line.topics.contains(interpretation.primaryIntentId);
      final shared = _isSharedFamily(line, interpretation);
      final relevanceBonus = precise ? 200.0 : (shared ? 60.0 : 30.0);
      ranked.add(scored.copyWith(
        score: scored.score + relevanceBonus,
        reasons: <String>[
          ...scored.reasons,
          if (precise)
            'preciseIntent'
          else if (shared)
            'sharedResponseFamily'
          else
            'legacyIntentFamily',
        ],
      ));
    }
    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0 ? scoreOrder : a.line.id.compareTo(b.line.id);
    });

    final selected = _buildResponseReel(ranked, limit);
    var usedFallback = false;
    final lowRecognitionConfidence = transcriptionConfidence != null &&
        // speech_to_text uses 0 when a platform supplies no confidence.
        // Treat only a real, positive score as confidence evidence.
        transcriptionConfidence > 0 &&
        transcriptionConfidence < 0.45;
    final uncertainIntent = interpretation.primaryIntent == null &&
        interpretation.confidence < 0.5;
    if (uncertainIntent || lowRecognitionConfidence) {
      selected.clear();
    }
    if (selected.isEmpty &&
        (uncertainIntent || lowRecognitionConfidence)) {
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
      candidateCount:
          ranked.length > selected.length ? ranked.length : selected.length,
      reelIntentId: interpretation.primaryIntentId,
      excludedAlreadyShown: excludedLineIds.length,
      moreGeneration: moreGeneration,
    );
  }

  ConversationInterpretation _lockIntent(
    ConversationInterpretation interpretation,
    String intentId,
  ) {
    ConversationIntentMatch? locked;
    for (final match in interpretation.intentMatches) {
      if (match.id == intentId) {
        locked = ConversationIntentMatch(
          definition: match.definition,
          confidence: match.confidence,
          reasons: <String>{...match.reasons, 'activeIntent'}.toList(),
        );
        break;
      }
    }
    if (locked == null) {
      for (final definition in interpreter.intentMatcher.catalog) {
        if (definition.id != intentId) continue;
        locked = ConversationIntentMatch(
          definition: definition,
          confidence: interpretation.intentConfidence,
          reasons: const <String>['activeIntent'],
        );
        break;
      }
    }
    if (locked == null) return interpretation;
    return ConversationInterpretation(
      language: interpretation.language,
      intents: interpretation.intents,
      topics: interpretation.topics,
      tokens: interpretation.tokens,
      isQuestion: interpretation.isQuestion,
      confidence: locked.confidence,
      intentMatches: <ConversationIntentMatch>[
        locked,
        ...interpretation.intentMatches.where((match) => match.id != intentId),
      ],
    );
  }

  List<OpenerLine> _responseFamily(
    List<OpenerLine> library,
    ConversationInterpretation interpretation,
    ConversationPreferences preferences,
    Set<String> excludedLineIds,
  ) {
    final intent = interpretation.primaryIntent;
    if (intent == null) return const <OpenerLine>[];
    final allowed = library
        .where((line) => _allowed(line, preferences))
        .toList(growable: false);
    final hasPreciseFamily = allowed.any(
      (line) => line.topics.contains(intent.id),
    );
    final available = allowed.where(
      (line) => !excludedLineIds.contains(line.id),
    );
    if (hasPreciseFamily) {
      return available
          .where((line) => line.topics.contains(intent.id))
          .toList(growable: false);
    }
    return available
        .where((line) => _hintMatchCount(line, intent) > 0)
        .toList(growable: false);
  }

  static const Set<String> _sharedResponseFamilies = <String>{
    'ask_back',
    'playful_question_reversal',
    'interest_probe',
    'conversation_hook',
    'future_hook',
    'contact_hook',
  };

  bool _isSharedFamily(
    OpenerLine line,
    ConversationInterpretation interpretation,
  ) {
    final intent = interpretation.primaryIntent;
    if (intent == null) return false;
    return line.topics.any(
      (topic) =>
          _sharedResponseFamilies.contains(topic) &&
          intent.definition.responseHints.contains(topic),
    );
  }

  int _hintMatchCount(OpenerLine line, ConversationIntentMatch intent) {
    final lineText = <String>[
      line.japaneseText,
      line.englishMeaning ?? '',
      line.koreanText ?? '',
      ...line.topics,
    ].join(' ').toLowerCase();
    return intent.definition.responseHints.where((hint) {
      if (hint == 'statement' || hint == 'comeback') return false;
      final normalized = hint.toLowerCase();
      return lineText.contains(normalized) || line.topics.contains(normalized);
    }).length;
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
    final primaryIntent = input.primaryIntent;
    if (primaryIntent != null) {
      var hintMatches = 0;
      for (final hint in primaryIntent.definition.responseHints) {
        final normalizedHint = hint.toLowerCase();
        if (lineText.contains(normalizedHint) ||
            line.topics.contains(normalizedHint)) {
          hintMatches++;
        }
      }
      if (hintMatches > 0) {
        score += (hintMatches * 15).clamp(0, 60).toDouble();
        reasons.add('intentFamily');
      }
      if (primaryIntent.function == ConversationFunction.softRejection &&
          line.tones.contains(Tone.safe)) {
        score += 18;
        reasons.add('nonPushy');
      }
    }
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
    if (line.displayLength <= 24) {
      score += 5;
      reasons.add('short');
    } else if (line.displayLength > 40) {
      score -= 10;
    }
    score -= (line.boldness?.index ?? 0) * 0.5;
    return ConversationSuggestion(line: line, score: score, reasons: reasons);
  }

  List<ConversationSuggestion> _buildResponseReel(
    List<ConversationSuggestion> ranked,
    int limit,
  ) {
    final selected = <ConversationSuggestion>[];
    for (final slot in ConversationReelSlot.values.take(limit)) {
      final available = ranked.where((candidate) {
        if (selected.any((item) => item.line.id == candidate.line.id)) {
          return false;
        }
        return !selected.any(
          (item) => _effectivelySame(item.line, candidate.line),
        );
      }).toList();
      if (available.isEmpty) break;
      available.sort((a, b) {
        final aScore = a.score + _slotAffinity(a.line, slot);
        final bScore = b.score + _slotAffinity(b.line, slot);
        final scoreOrder = bScore.compareTo(aScore);
        return scoreOrder != 0 ? scoreOrder : a.line.id.compareTo(b.line.id);
      });
      selected.add(available.first.copyWith(slot: slot));
    }
    return selected;
  }

  double _slotAffinity(OpenerLine line, ConversationReelSlot slot) {
    final preferred = switch (slot) {
      ConversationReelSlot.standard =>
        <Tone>{Tone.safe, Tone.friendly, Tone.situational},
      ConversationReelSlot.funny =>
        <Tone>{Tone.humorous, Tone.witty, Tone.playful, Tone.teasing},
      ConversationReelSlot.flirty =>
        <Tone>{Tone.flirty, Tone.confident, Tone.romantic, Tone.teasing},
    };
    final matches = line.tones.intersection(preferred).length;
    var affinity = matches * 45.0;
    if (slot == ConversationReelSlot.standard &&
        line.usageType == ConversationUsageType.statement) {
      affinity += 15;
    }
    if (slot != ConversationReelSlot.standard &&
        line.usageType == ConversationUsageType.comeback) {
      affinity += 10;
    }
    return affinity;
  }

  bool _effectivelySame(OpenerLine left, OpenerLine right) {
    return _responseSignature(left.japaneseText) ==
        _responseSignature(right.japaneseText);
  }

  String _responseSignature(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[（(]\s*(?:笑|爆笑|苦笑|w+)\s*[）)]'), '')
        .replaceAll(
          RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+'),
          '',
        );
    normalized = normalized.replaceFirst(RegExp(r'いません$'), 'いない');
    normalized = normalized.replaceFirst(
      RegExp(r'(?:です|ます|ですよ|ですね|ません|だよ|だね|よ|ね)$'),
      '',
    );
    return normalized;
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
