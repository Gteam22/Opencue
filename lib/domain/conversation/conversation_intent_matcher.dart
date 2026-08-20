import 'conversation_intent.dart';
import 'conversation_intent_catalog.dart';
import 'transcript_normalizer.dart';

class ConversationIntentMatcher {
  const ConversationIntentMatcher({
    List<ConversationIntentDefinition>? catalog,
    this.normalizer = const TranscriptNormalizer(),
  }) : _catalog = catalog;

  final List<ConversationIntentDefinition>? _catalog;
  List<ConversationIntentDefinition> get catalog =>
      _catalog ?? conversationIntentCatalog;
  final TranscriptNormalizer normalizer;

  List<ConversationIntentMatch> match(
    String transcript, {
    List<String> recentTranscripts = const <String>[],
    int limit = 3,
  }) {
    final text = normalizer.normalize(transcript);
    if (text.isEmpty) return const <ConversationIntentMatch>[];
    final history = normalizer.normalize(recentTranscripts.join(' '));
    final question = _looksLikeQuestion(transcript, text);
    final matches = <ConversationIntentMatch>[];

    for (final definition in catalog) {
      final exclusions = definition.exclusions
          .map(normalizer.normalize)
          .where((term) => term.isNotEmpty);
      if (exclusions.any(text.contains)) continue;

      var confidence = 0.0;
      final reasons = <String>[];
      for (final rawExample in definition.examples) {
        final example = normalizer.normalize(rawExample);
        if (example.isEmpty) continue;
        if (text == example) {
          confidence = 0.99;
          reasons.add('exactExample');
          break;
        }
        if (example.length >= 4 &&
            (text.contains(example) || example.contains(text))) {
          confidence = confidence < 0.9 ? 0.9 : confidence;
          reasons.add('phrase');
        }
        final similarity = _dice(text, example);
        if (similarity >= 0.55) {
          final semantic = 0.38 + similarity * 0.56;
          if (semantic > confidence) confidence = semantic;
          reasons.add('normalizedSimilarity');
        }
      }

      var keywordHits = 0;
      var strongKeywordHits = 0;
      for (final rawKeyword in definition.keywords) {
        final keyword = normalizer.normalize(rawKeyword);
        if (keyword.isNotEmpty && text.contains(keyword)) {
          keywordHits++;
          if (keyword.runes.length >= 3) strongKeywordHits++;
        }
      }
      if (keywordHits >= 2) {
        final keywordScore =
            (0.56 + keywordHits * 0.09).clamp(0.0, 0.92).toDouble();
        if (keywordScore > confidence) confidence = keywordScore;
        reasons.add('keywordCombination');
      } else if (strongKeywordHits == 1 && definition.keywords.length <= 3) {
        if (confidence < 0.62) confidence = 0.62;
        reasons.add('strongKeyword');
      }

      if (question && definition.function == ConversationFunction.question) {
        confidence = (confidence + 0.06).clamp(0.0, 0.99).toDouble();
        reasons.add('questionShape');
      }
      if (history.isNotEmpty &&
          definition.contextTags.any(history.contains)) {
        confidence = (confidence + 0.03).clamp(0.0, 0.99).toDouble();
        reasons.add('recentContext');
      }
      if (confidence >= definition.confidenceThreshold) {
        matches.add(ConversationIntentMatch(
          definition: definition,
          confidence: confidence,
          reasons: reasons.toSet().toList(growable: false),
        ));
      }
    }

    matches.sort((a, b) {
      final questionAdvantage = question
          ? _questionPriority(b.function) - _questionPriority(a.function)
          : 0;
      if (questionAdvantage != 0) return questionAdvantage;
      final scoreOrder = b.confidence.compareTo(a.confidence);
      if (scoreOrder != 0) return scoreOrder;
      return b.definition.priority.compareTo(a.definition.priority);
    });
    return matches.take(limit).toList(growable: false);
  }

  bool _looksLikeQuestion(String raw, String normalized) =>
      raw.contains('?') ||
      raw.contains('？') ||
      <String>['ですか', 'ますか', 'なの', 'what', 'where', 'when', 'why', 'how',
        'do you', 'are you', '뭐', '어디', '왜', '언제', '할래']
          .map(normalizer.normalize)
          .any(normalized.contains);

  int _questionPriority(ConversationFunction function) =>
      function == ConversationFunction.question ? 2 : 0;

  double _dice(String left, String right) {
    final a = normalizer.bigrams(left);
    final b = normalizer.bigrams(right);
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    return (2 * intersection) / (a.length + b.length);
  }
}
