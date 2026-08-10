import 'conversation_models.dart';

class SemanticIntentClassification {
  const SemanticIntentClassification({
    required this.intentId,
    required this.confidence,
  });

  final String intentId;
  final double confidence;
}

/// Vendor-neutral fallback boundary for an optional local or remote model.
/// Implementations return only a catalog intent ID and confidence; widgets
/// never depend on a model SDK or parse free-form model prose.
abstract interface class ConversationSemanticIntentClassifier {
  Future<SemanticIntentClassification?> classify({
    required String transcript,
    required List<ConversationTurn> recentTurns,
  });
}

class NullConversationSemanticIntentClassifier
    implements ConversationSemanticIntentClassifier {
  const NullConversationSemanticIntentClassifier();

  @override
  Future<SemanticIntentClassification?> classify({
    required String transcript,
    required List<ConversationTurn> recentTurns,
  }) async =>
      null;
}
