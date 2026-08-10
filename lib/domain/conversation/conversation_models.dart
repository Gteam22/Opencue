import '../enums/enums.dart';
import '../models/opener_line.dart';
import 'conversation_intent.dart';

/// Recognition language is deliberately separate from the display language.
enum ConversationInputLanguage { automatic, japanese, korean, english }

enum DetectedLanguage { japanese, korean, english, unknown }

enum ConversationIntent {
  greeting,
  answerQuestion,
  askBack,
  acknowledge,
  compliment,
  flirt,
  tease,
  apologize,
  thank,
  invite,
  agree,
  disagree,
}

enum ConversationTopic {
  general,
  weekend,
  work,
  hobbies,
  food,
  drinks,
  music,
  travel,
  relationships,
  dating,
  kissing,
  compatibility,
  dominance,
  compliments,
}

/// A compact tone control for the assist screen.
enum ConversationToneBias { natural, funny, flirty, gentleman, bold }

enum SuggestionFeedbackKind { shown, accepted, dismissed }

enum ConversationSpeaker { other, user }

enum FinalizedUtteranceSource { speech, manual }

enum ConversationMatcherKind { local, semantic, none }

enum CueUpdateAction {
  updated,
  preservedIrrelevant,
  preservedDuplicate,
  preservedEmpty,
}

class ConversationInterpretation {
  const ConversationInterpretation({
    required this.language,
    required this.intents,
    required this.topics,
    required this.tokens,
    required this.isQuestion,
    required this.confidence,
    this.intentMatches = const <ConversationIntentMatch>[],
  });

  final DetectedLanguage language;
  final Set<ConversationIntent> intents;
  final Set<ConversationTopic> topics;
  final Set<String> tokens;
  final bool isQuestion;
  final double confidence;
  final List<ConversationIntentMatch> intentMatches;

  ConversationIntentMatch? get primaryIntent =>
      intentMatches.isEmpty ? null : intentMatches.first;
  String? get primaryIntentId => primaryIntent?.id;
  double get intentConfidence => primaryIntent?.confidence ?? confidence;
}

class ConversationPreferences {
  const ConversationPreferences({
    this.tone = ConversationToneBias.natural,
    this.maxBoldness = ConversationBoldness.flirty,
    this.adultContentEnabled = false,
    this.recentLineIds = const <String>{},
  });

  final ConversationToneBias tone;
  final ConversationBoldness maxBoldness;
  final bool adultContentEnabled;
  final Set<String> recentLineIds;

  ConversationPreferences copyWith({
    ConversationToneBias? tone,
    ConversationBoldness? maxBoldness,
    bool? adultContentEnabled,
    Set<String>? recentLineIds,
  }) {
    return ConversationPreferences(
      tone: tone ?? this.tone,
      maxBoldness: maxBoldness ?? this.maxBoldness,
      adultContentEnabled:
          adultContentEnabled ?? this.adultContentEnabled,
      recentLineIds: recentLineIds ?? this.recentLineIds,
    );
  }
}

class ConversationSuggestion {
  const ConversationSuggestion({
    required this.line,
    required this.score,
    required this.reasons,
  });

  final OpenerLine line;
  final double score;
  final List<String> reasons;
}

class ConversationSuggestionResult {
  const ConversationSuggestionResult({
    required this.transcript,
    required this.interpretation,
    required this.suggestions,
    this.usedSafeFallback = false,
    this.lowRecognitionConfidence = false,
    this.candidateCount = 0,
  });

  final String transcript;
  final ConversationInterpretation interpretation;
  final List<ConversationSuggestion> suggestions;
  final bool usedSafeFallback;
  final bool lowRecognitionConfidence;
  final int candidateCount;
}

class ConversationTurn {
  const ConversationTurn({
    required this.transcript,
    required this.language,
    required this.createdAt,
    this.id,
    this.speaker = ConversationSpeaker.other,
    this.detectedIntent,
    this.confidence,
  });

  final String? id;
  final String transcript;
  final DetectedLanguage language;
  final DateTime createdAt;
  final ConversationSpeaker speaker;
  final String? detectedIntent;
  final double? confidence;
}

class ConversationPipelineDiagnostics {
  const ConversationPipelineDiagnostics({
    required this.rawTranscript,
    required this.normalizedTranscript,
    required this.finalized,
    required this.intentId,
    required this.confidence,
    required this.matcher,
    required this.responsesFound,
    required this.responsesDisplayed,
    required this.action,
    required this.source,
    required this.createdAt,
    this.matcherReasons = const <String>[],
    this.responseHints = const <String>[],
    this.topResponseScores = const <String, double>{},
  });

  final String rawTranscript;
  final String normalizedTranscript;
  final bool finalized;
  final String intentId;
  final double confidence;
  final ConversationMatcherKind matcher;
  final int responsesFound;
  final int responsesDisplayed;
  final CueUpdateAction action;
  final FinalizedUtteranceSource source;
  final DateTime createdAt;
  final List<String> matcherReasons;
  final List<String> responseHints;
  final Map<String, double> topResponseScores;
}

class ConversationSuggestionFeedback {
  const ConversationSuggestionFeedback({
    required this.transcript,
    required this.intentId,
    required this.lineId,
    required this.kind,
    required this.createdAt,
  });

  final String transcript;
  final String? intentId;
  final String lineId;
  final SuggestionFeedbackKind kind;
  final DateTime createdAt;
}
