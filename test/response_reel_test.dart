import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/data/seed/conversation_seed_loader.dart';
import 'package:opencue/domain/conversation/conversation_intent.dart';
import 'package:opencue/domain/conversation/conversation_intent_matcher.dart';
import 'package:opencue/domain/conversation/conversation_interpreter.dart';
import 'package:opencue/domain/conversation/conversation_models.dart';
import 'package:opencue/domain/conversation/conversation_response_engine.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/opener_line.dart';

import '../lib/domain/conversation/conversation_assist_controller.dart';
import '../lib/domain/conversation/conversation_recognition_service.dart';

void main() {
  final library = const ConversationSeedLoader().load(
    createdAt: DateTime.utc(2026),
  );

  group('intent-locked response reel', () {
    test('relationship reel contains three relevant style slots', () {
      final result = const ConversationResponseEngine().suggest(
        transcript: '彼女いる？',
        library: library,
      );

      expect(result.reelIntentId, 'relationship_status');
      expect(result.suggestions, hasLength(3));
      expect(
        result.suggestions.every(
          (suggestion) =>
              suggestion.line.topics.contains('relationship_status'),
        ),
        isTrue,
      );
      expect(
        result.suggestions.map((suggestion) => suggestion.slot),
        <ConversationReelSlot>[
          ConversationReelSlot.standard,
          ConversationReelSlot.funny,
          ConversationReelSlot.flirty,
        ],
      );
      expect(
        result.suggestions[0].line.tones.intersection(<Tone>{
          Tone.safe,
          Tone.friendly,
          Tone.situational,
        }),
        isNotEmpty,
      );
      expect(
        result.suggestions[1].line.tones.intersection(<Tone>{
          Tone.humorous,
          Tone.witty,
          Tone.playful,
          Tone.teasing,
        }),
        isNotEmpty,
      );
      expect(
        result.suggestions[2].line.tones.intersection(<Tone>{
          Tone.flirty,
          Tone.confident,
          Tone.romantic,
          Tone.teasing,
        }),
        isNotEmpty,
      );
    });

    test('does not fill a missing slot from an unrelated family', () {
      const intent = ConversationIntentDefinition(
        id: 'two_variant',
        description: 'A family with only two relevant responses',
        examples: <String>['確認ですか？'],
        keywords: <String>['確認'],
        function: ConversationFunction.question,
        contextTags: <String>{'test'},
        responseHints: <String>['two_variant'],
      );
      const engine = ConversationResponseEngine(
        interpreter: ConversationInterpreter(
          intentMatcher: ConversationIntentMatcher(
            catalog: <ConversationIntentDefinition>[intent],
          ),
        ),
      );
      final result = engine.suggest(
        transcript: '確認ですか？',
        library: <OpenerLine>[
          _line('standard', '普通の答えです。', 'two_variant', <Tone>{Tone.safe}),
          _line('funny', '確認が厳しいですね（笑）', 'two_variant',
              <Tone>{Tone.witty}),
          _line('wrong', '納豆は苦手です。', 'can_eat_natto',
              <Tone>{Tone.flirty}),
        ],
      );

      expect(result.suggestions, hasLength(2));
      expect(
        result.suggestions.map((suggestion) => suggestion.line.id),
        isNot(contains('wrong')),
      );
    });

    test('collapses punctuation and politeness-only response variants', () {
      const intent = ConversationIntentDefinition(
        id: 'duplicate_family',
        description: 'Near-duplicate response family',
        examples: <String>['相手はいますか？'],
        keywords: <String>['相手'],
        function: ConversationFunction.question,
        contextTags: <String>{'test'},
        responseHints: <String>['duplicate_family'],
      );
      const engine = ConversationResponseEngine(
        interpreter: ConversationInterpreter(
          intentMatcher: ConversationIntentMatcher(
            catalog: <ConversationIntentDefinition>[intent],
          ),
        ),
      );
      final result = engine.suggest(
        transcript: '相手はいますか？',
        library: <OpenerLine>[
          _line('a', '今はいないですよ。', 'duplicate_family',
              <Tone>{Tone.safe}),
          _line('b', '今はいないですね。', 'duplicate_family',
              <Tone>{Tone.friendly}),
          _line('c', '今はいません。', 'duplicate_family',
              <Tone>{Tone.safe}),
          _line('d', '面接みたいですね（笑）', 'duplicate_family',
              <Tone>{Tone.witty}),
        ],
      );

      expect(result.suggestions, hasLength(2));
      expect(
        result.suggestions.map((suggestion) => suggestion.line.id),
        contains('d'),
      );
    });
  });

  group('More rotation and new utterances', () {
    test('More retains intent, excludes shown ids, and adds no turn', () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      await controller.onUtteranceFinalized(
        '日本に来てどのくらいですか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      final firstIds = controller.result!.suggestions
          .map((suggestion) => suggestion.line.id)
          .toSet();
      final turns = controller.history.length;

      controller.more();

      expect(controller.activeIntentId, 'time_in_japan');
      expect(controller.result!.reelIntentId, 'time_in_japan');
      expect(controller.history, hasLength(turns));
      expect(
        controller.result!.suggestions.every(
          (suggestion) => suggestion.line.topics.contains('time_in_japan'),
        ),
        isTrue,
      );
      expect(
        controller.result!.suggestions
            .map((suggestion) => suggestion.line.id)
            .toSet()
            .intersection(firstIds),
        isEmpty,
      );
      expect(controller.diagnostics!.moreGeneration, isTrue);
      expect(controller.diagnostics!.excludedAlreadyShown, firstIds.length);

      final secondIds = controller.result!.suggestions
          .map((suggestion) => suggestion.line.id)
          .toSet();
      final revision = controller.cueRevision;
      controller.more();
      expect(controller.cueRevision, revision);
      expect(
        controller.result!.suggestions
            .map((suggestion) => suggestion.line.id)
            .toSet(),
        secondIds,
      );
    });

    test('new finalized utterance resets shown ids and response family',
        () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      await controller.onUtteranceFinalized(
        '彼女いる？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      final firstShown = controller.shownResponseIds;
      final funny = controller.result!.suggestions.singleWhere(
        (suggestion) => suggestion.slot == ConversationReelSlot.funny,
      );
      expect(
        controller.diagnostics!.displayTexts[funny.line.id],
        contains('（笑）'),
      );
      expect(
        controller.diagnostics!.ttsTexts[funny.line.id],
        isNot(contains('笑')),
      );

      await controller.onUtteranceFinalized(
        '休みの日何してる？',
        library: library,
        preferences: const ConversationPreferences(),
      );

      final currentIds = controller.result!.suggestions
          .map((suggestion) => suggestion.line.id)
          .toSet();
      expect(controller.activeIntentId, 'days_off');
      expect(controller.shownResponseIds, currentIds);
      expect(controller.shownResponseIds.intersection(firstShown), isEmpty);
      expect(
        controller.result!.suggestions.every(
          (suggestion) => suggestion.line.topics.contains('days_off'),
        ),
        isTrue,
      );
    });
  });
}

OpenerLine _line(
  String id,
  String japanese,
  String topic,
  Set<Tone> tones,
) =>
    OpenerLine(
      id: id,
      japaneseText: japanese,
      tones: tones,
      boldness: ConversationBoldness.light,
      usageType: ConversationUsageType.statement,
      topics: <String>{topic},
      manualOnly: true,
    );
