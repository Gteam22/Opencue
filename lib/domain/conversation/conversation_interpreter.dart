import 'conversation_models.dart';
import 'language_detector.dart';

/// Small, deterministic multilingual intent layer. It is intentionally behind
/// one class so a local model can replace it later without changing ranking.
class ConversationInterpreter {
  const ConversationInterpreter({
    this.languageDetector = const ConversationLanguageDetector(),
  });

  final ConversationLanguageDetector languageDetector;

  ConversationInterpretation interpret(
    String transcript, {
    List<ConversationTurn> history = const <ConversationTurn>[],
  }) {
    final normalized = transcript.toLowerCase().trim();
    final context = <String>[
      for (final turn in history.take(5)) turn.transcript.toLowerCase(),
      normalized,
    ].join(' ');
    final intents = <ConversationIntent>{};
    final topics = <ConversationTopic>{};

    void intent(ConversationIntent value, List<String> terms) {
      if (_hasAny(context, terms)) intents.add(value);
    }

    void topic(ConversationTopic value, List<String> terms) {
      if (_hasAny(context, terms)) topics.add(value);
    }

    intent(ConversationIntent.greeting,
        const ['hello', 'hi ', 'hey', 'こんにちは', 'こんばんは', '안녕']);
    intent(ConversationIntent.thank,
        const ['thank', 'thanks', 'ありがとう', '감사', '고마워']);
    intent(ConversationIntent.apologize,
        const ['sorry', 'apolog', 'ごめん', 'すみません', '미안', '죄송']);
    intent(ConversationIntent.compliment, const [
      'cute', 'pretty', 'beautiful', 'handsome', '素敵', 'かわいい',
      '綺麗', '멋', '예쁘', '귀엽',
    ]);
    intent(ConversationIntent.invite, const [
      'want to', 'shall we', 'let us', '一緒に', '行かない', '같이', '갈래',
    ]);
    intent(ConversationIntent.agree,
        const ['i agree', 'exactly', 'そうだね', '確かに', '맞아', '그러게']);
    intent(ConversationIntent.disagree,
        const ["don't think", 'not really', '違う', 'そうかな', '아니', '별로']);
    intent(ConversationIntent.flirt, const [
      'date', 'kiss', 'attracted', 'デート', 'キス', '好き',
      '데이트', '키스', '좋아',
    ]);
    intent(ConversationIntent.tease,
        const ['joking', 'kidding', '冗談', 'いじ', '장난', '농담']);

    final question = transcript.contains('?') ||
        transcript.contains('？') ||
        _hasAny(normalized, const [
          'what ', 'where ', 'when ', 'why ', 'how ', 'do you', 'are you',
          'ですか', 'ますか', 'なの', 'どう', '何', '어때', '뭐', '왜', '언제',
          '어디', '할래',
        ]);
    if (question) intents.add(ConversationIntent.answerQuestion);
    if (!question && intents.isEmpty) {
      intents.add(ConversationIntent.acknowledge);
    }

    topic(ConversationTopic.weekend,
        const ['weekend', '土日', '週末', '주말']);
    topic(ConversationTopic.work, const [
      'work', 'job', 'office', '仕事', '会社', '職業', '일', '직장', '회사',
    ]);
    topic(ConversationTopic.hobbies,
        const ['hobby', 'free time', '趣味', '休み', '취미', '여가']);
    topic(ConversationTopic.food, const [
      'food', 'eat', 'restaurant', '料理', '食べ', 'ご飯', '음식', '먹', '맛집',
    ]);
    topic(ConversationTopic.drinks, const [
      'drink', 'beer', 'wine', 'bar', '飲み', 'お酒', 'ビール',
      '술', '맥주', '와인',
    ]);
    topic(ConversationTopic.music, const [
      'music', 'song', 'concert', '音楽', '曲', 'ライブ',
      '음악', '노래', '콘서트',
    ]);
    topic(ConversationTopic.travel,
        const ['travel', 'trip', 'country', '旅行', '旅', '海外', '여행', '나라']);
    topic(ConversationTopic.relationships, const [
      'relationship', 'boyfriend', 'girlfriend', '恋愛', '彼氏', '彼女',
      '연애', '남친', '여친',
    ]);
    topic(ConversationTopic.dating,
        const ['date', 'dating', 'デート', '데이트']);
    topic(ConversationTopic.kissing,
        const ['kiss', 'kissing', 'キス', '키스']);
    topic(ConversationTopic.compatibility,
        const ['compatible', 'compatibility', '相性', '궁합', '잘 맞']);
    topic(ConversationTopic.dominance, const [
      'dominant', 'submissive', 'lead', 's or m', '攻め', '受け',
      'sとm', '리드', 's야', 'm이야',
    ]);
    topic(ConversationTopic.compliments, const [
      'compliment', 'cute', 'pretty', '素敵', 'かわいい', '褒め',
      '예쁘', '귀엽', '칭찬',
    ]);

    if (topics.isEmpty) topics.add(ConversationTopic.general);
    final tokens = _tokens(normalized);
    final meaningfulIntents = intents
        .where((value) => value != ConversationIntent.acknowledge)
        .length;
    final meaningfulTopics = topics
        .where((value) => value != ConversationTopic.general)
        .length;
    final evidence = meaningfulIntents +
        meaningfulTopics +
        (question ? 1 : 0);
    return ConversationInterpretation(
      language: languageDetector.detect(transcript),
      intents: intents,
      topics: topics,
      tokens: tokens,
      isQuestion: question,
      confidence: (0.25 + evidence * 0.12).clamp(0.0, 1.0).toDouble(),
    );
  }

  bool _hasAny(String text, List<String> terms) =>
      terms.any((term) => text.contains(term));

  Set<String> _tokens(String text) => text
      .replaceAll(
        RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+'),
        ' ',
      )
      .split(' ')
      .where((token) => token.length >= 2)
      .toSet();
}
