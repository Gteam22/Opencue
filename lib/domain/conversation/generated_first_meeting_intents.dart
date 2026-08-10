// GENERATED FILE. See tool/import_first_meeting_library.py and
// tool/build_conversation_library.py.
import 'conversation_intent.dart';

const int generatedFirstMeetingSourceQuestionCount = 129;
const int generatedFirstMeetingIntentCount = 128;

const List<ConversationIntentDefinition> generatedFirstMeetingIntents =
    <ConversationIntentDefinition>[
  ConversationIntentDefinition(
    id: 'ask_origin',
    description:
      'Responds to the first-meeting utterance: どちらのご出身'
      'ですか？',
    examples: <String>[
      'どちらのご出身ですか？',
      'どちらのご出身ですか',
      'どちらのご出身',
      'どこの国ですか',
      '出身どこですか',
      'どこ出身',
      'お国はどこですか',
    ],
    keywords: <String>[
      '出身',
      'どこ',
      '国',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'origin',
      'country',
    },
    responseHints: <String>[
      'ask_origin',
      'origin',
      'country',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'origin_region',
    description:
      'Responds to the first-meeting utterance: アメリカのどこ'
      'ですか？',
    examples: <String>[
      'アメリカのどこですか？',
      'アメリカのどこですか',
      'アメリカのどこ',
      'アメリカのどの辺ですか',
      '何州の出身ですか',
      'アメリカのどちら',
    ],
    keywords: <String>[
      'アメリカ',
      'どこ',
      'どの辺',
      '州',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'origin',
      'region',
      'america',
    },
    responseHints: <String>[
      'origin_region',
      'origin',
      'region',
      'america',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'time_in_japan',
    description:
      'Responds to the first-meeting utterance: 日本に来てどの'
      'くらいですか？',
    examples: <String>[
      '日本に来てどのくらいですか？',
      '日本に来てどのくらいですか',
      '日本に来てどのくらい',
      '日本に来て何年ですか',
      '日本何年目ですか',
      'いつから日本にいるんですか',
      'こっち長いんですか',
      '日本長い',
      'いつから日本いるの',
    ],
    keywords: <String>[
      '日本',
      'どのくらい',
      '何年目',
      '長い',
      'いつから',
    ],
    exclusions: <String>[
      'どうして',
      'なんで',
      'きっかけ',
      '将来',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'travel',
    },
    responseHints: <String>[
      'time_in_japan',
      'japanese',
      'travel',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'arrival_time_japan',
    description:
      'Responds to the first-meeting utterance: いつ日本に来た'
      'んですか？',
    examples: <String>[
      'いつ日本に来たんですか？',
      'いつ日本に来たんですか',
      'いつ日本に来たの',
      'いつ日本に来たん',
    ],
    keywords: <String>[
      'いつ',
      '日本',
      '来た',
      '何年前',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'travel',
    },
    responseHints: <String>[
      'arrival_time_japan',
      'japanese',
      'travel',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_reason_japan',
    description:
      'Responds to the first-meeting utterance: どうして日本に'
      '来たんですか？',
    examples: <String>[
      'どうして日本に来たんですか？',
      'どうして日本に来たんですか',
      'どうして日本に来たの',
      'どうして日本に来たん',
      'なんで日本に来たんですか',
      'なんで日本に来たの',
      '日本に来たきっかけは',
      'どうして日本に住もうと思ったんですか',
      'なぜ日本に来たの',
    ],
    keywords: <String>[
      '日本',
      'どうして',
      'なんで',
      'きっかけ',
      '理由',
    ],
    exclusions: <String>[
      'どのくらい',
      '何年目',
      'いつから',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'travel',
    },
    responseHints: <String>[
      'ask_reason_japan',
      'japanese',
      'travel',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'reason_fukuoka',
    description:
      'Responds to the first-meeting utterance: なんで福岡に住'
      'んでるんですか？',
    examples: <String>[
      'なんで福岡に住んでるんですか？',
      'なんで福岡に住んでるんですか',
      'なんで福岡に住んでるの',
      'なんで福岡に住んでるん',
    ],
    keywords: <String>[
      '福岡',
      'なんで',
      'どうして',
      '住んでる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'fukuoka',
      'location',
    },
    responseHints: <String>[
      'reason_fukuoka',
      'fukuoka',
      'location',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'opinion_fukuoka',
    description:
      'Responds to the first-meeting utterance: 福岡好きですか'
      '？',
    examples: <String>[
      '福岡好きですか？',
      '福岡好きですか',
      '福岡好き',
    ],
    keywords: <String>[
      '福岡',
      '好き',
      'どう',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'fukuoka',
      'location',
    },
    responseHints: <String>[
      'opinion_fukuoka',
      'fukuoka',
      'location',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_japanese',
    description:
      'Responds to the first-meeting utterance: 日本語上手です'
      'ね！',
    examples: <String>[
      '日本語上手ですね！',
      '日本語上手ですね',
      '日本語うまいね',
      '日本語ペラペラですね',
      '日本語ペラペラですね。',
      '日本語ペラペラだね',
    ],
    keywords: <String>[
      '日本語',
      '上手',
      'うまい',
      'ペラペラ',
    ],
    exclusions: <String>[
      'どこで',
      'どうやって',
      '勉強',
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'japanese',
      'compliments',
    },
    responseHints: <String>[
      'compliment_japanese',
      'japanese',
      'compliments',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'japanese_study_method',
    description:
      'Responds to the first-meeting utterance: 日本語どこで勉'
      '強したんですか？',
    examples: <String>[
      '日本語どこで勉強したんですか？',
      '日本語どこで勉強したんですか',
      '日本語どこで勉強したの',
      '日本語どこで勉強したん',
      'どこで日本語勉強したんですか',
      '日本語どうやって覚えたの',
      '日本語は独学ですか',
      '日本語どこで習った',
    ],
    keywords: <String>[
      '日本語',
      'どこで',
      '勉強',
      '覚えた',
      'どうやって',
    ],
    exclusions: <String>[
      '上手',
      'ペラペラ',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'study',
    },
    responseHints: <String>[
      'japanese_study_method',
      'japanese',
      'study',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'read_kanji',
    description:
      'Responds to the first-meeting utterance: 漢字も読めます'
      'か？',
    examples: <String>[
      '漢字も読めますか？',
      '漢字も読めますか',
      '漢字も読めます',
    ],
    keywords: <String>[
      '漢字',
      '読める',
      '読めます',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'kanji',
    },
    responseHints: <String>[
      'read_kanji',
      'japanese',
      'kanji',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'use_keigo',
    description:
      'Responds to the first-meeting utterance: 敬語も使えるん'
      'ですか？',
    examples: <String>[
      '敬語も使えるんですか？',
      '敬語も使えるんですか',
      '敬語も使えるの',
      '敬語も使えるん',
    ],
    keywords: <String>[
      '敬語',
      '使える',
      '話せる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'keigo',
    },
    responseHints: <String>[
      'use_keigo',
      'japanese',
      'keigo',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'easier_language',
    description:
      'Responds to the first-meeting utterance: 英語と日本語、'
      'どっちが楽ですか？',
    examples: <String>[
      '英語と日本語、どっちが楽ですか？',
      '英語と日本語、どっちが楽ですか',
      '英語と日本語、どっちが楽',
    ],
    keywords: <String>[
      '英語',
      '日本語',
      'どっち',
      '楽',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'languages',
      'preferences',
    },
    responseHints: <String>[
      'easier_language',
      'languages',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'dream_language',
    description:
      'Responds to the first-meeting utterance: 日本語で夢を見'
      'るんですか？',
    examples: <String>[
      '日本語で夢を見るんですか？',
      '日本語で夢を見るんですか',
      '日本語で夢を見るの',
      '日本語で夢を見るん',
    ],
    keywords: <String>[
      '日本語',
      '夢',
      '見る',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'languages',
      'japanese',
    },
    responseHints: <String>[
      'dream_language',
      'languages',
      'japanese',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'likes_japanese_food',
    description:
      'Responds to the first-meeting utterance: 日本食好きです'
      'か？',
    examples: <String>[
      '日本食好きですか？',
      '日本食好きですか',
      '日本食好き',
      '和食好き',
      '日本の食べ物好きですか',
    ],
    keywords: <String>[
      '日本食',
      '好き',
      '食べる',
    ],
    exclusions: <String>[
      '何が一番',
      '何の日本食',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'japanese_food',
    },
    responseHints: <String>[
      'likes_japanese_food',
      'food',
      'japanese_food',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'favorite_japanese_food',
    description:
      'Responds to the first-meeting utterance: 日本食で何が一'
      '番好きですか？',
    examples: <String>[
      '日本食で何が一番好きですか？',
      '日本食で何が一番好きですか',
      '日本食で何が一番好き',
      '何の日本食が好き',
      '好きな和食は何',
    ],
    keywords: <String>[
      '日本食',
      '何',
      '一番',
      '好き',
    ],
    exclusions: <String>[
      '日本食好きですか',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'japanese_food',
      'preferences',
    },
    responseHints: <String>[
      'favorite_japanese_food',
      'food',
      'japanese_food',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'likes_sushi',
    description:
      'Responds to the first-meeting utterance: 寿司好きですか'
      '？',
    examples: <String>[
      '寿司好きですか？',
      '寿司好きですか',
      '寿司好き',
    ],
    keywords: <String>[
      '寿司',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'sushi',
    },
    responseHints: <String>[
      'likes_sushi',
      'food',
      'sushi',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'can_eat_sashimi',
    description:
      'Responds to the first-meeting utterance: 刺身食べられま'
      'すか？',
    examples: <String>[
      '刺身食べられますか？',
      '刺身食べられますか',
      '刺身食べられます',
      '刺身大丈夫',
      '生魚食べれる',
    ],
    keywords: <String>[
      '刺身',
      '食べられる',
      '大丈夫',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'sashimi',
    },
    responseHints: <String>[
      'can_eat_sashimi',
      'food',
      'sashimi',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'can_eat_natto',
    description:
      'Responds to the first-meeting utterance: 納豆食べられま'
      'すか？',
    examples: <String>[
      '納豆食べられますか？',
      '納豆食べられますか',
      '納豆食べられます',
      '納豆食べれる',
      '納豆大丈夫',
      '納豆いける',
    ],
    keywords: <String>[
      '納豆',
      '食べられる',
      '大丈夫',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'natto',
    },
    responseHints: <String>[
      'can_eat_natto',
      'food',
      'natto',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'can_eat_umeboshi',
    description:
      'Responds to the first-meeting utterance: 梅干し食べられ'
      'ますか？',
    examples: <String>[
      '梅干し食べられますか？',
      '梅干し食べられますか',
      '梅干し食べられます',
    ],
    keywords: <String>[
      '梅干し',
      '食べられる',
      '大丈夫',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'umeboshi',
    },
    responseHints: <String>[
      'can_eat_umeboshi',
      'food',
      'umeboshi',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'can_eat_wasabi',
    description:
      'Responds to the first-meeting utterance: わさび大丈夫で'
      'すか？',
    examples: <String>[
      'わさび大丈夫ですか？',
      'わさび大丈夫ですか',
      'わさび大丈夫',
    ],
    keywords: <String>[
      'わさび',
      '大丈夫',
      '食べられる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'wasabi',
    },
    responseHints: <String>[
      'can_eat_wasabi',
      'food',
      'wasabi',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'can_use_chopsticks',
    description: 'Responds to the first-meeting utterance: 箸使えますか？',
    examples: <String>[
      '箸使えますか？',
      '箸使えますか',
      '箸使えます',
      '箸使える',
      'お箸使える',
      '箸持てる',
    ],
    keywords: <String>[
      '箸',
      '使える',
      '持てる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'chopsticks',
    },
    responseHints: <String>[
      'can_use_chopsticks',
      'food',
      'chopsticks',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_spicy_food',
    description:
      'Responds to the first-meeting utterance: 辛いもの大丈夫'
      'ですか？',
    examples: <String>[
      '辛いもの大丈夫ですか？',
      '辛いもの大丈夫ですか',
      '辛いもの大丈夫',
    ],
    keywords: <String>[
      '辛い',
      '大丈夫',
      '食べられる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'spicy',
    },
    responseHints: <String>[
      'ask_spicy_food',
      'food',
      'spicy',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'cook_home_food',
    description:
      'Responds to the first-meeting utterance: 母国の料理作れ'
      'ますか？',
    examples: <String>[
      '母国の料理作れますか？',
      '母国の料理作れますか',
      '母国の料理作れます',
    ],
    keywords: <String>[
      '母国',
      '料理',
      '作れる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'cooking',
      'origin',
    },
    responseHints: <String>[
      'cook_home_food',
      'food',
      'cooking',
      'origin',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'american_hamburger_stereotype',
    description:
      'Responds to the first-meeting utterance: アメリカでは毎'
      '日ハンバーガー食べるんですか？',
    examples: <String>[
      'アメリカでは毎日ハンバーガー食べるんですか？',
      'アメリカでは毎日ハンバーガー食べるんですか',
      'アメリカでは毎日ハンバーガー食べるの',
      'アメリカでは毎日ハンバーガー食べるん',
    ],
    keywords: <String>[
      'アメリカ',
      '毎日',
      'ハンバーガー',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'america',
      'food',
      'stereotype',
    },
    responseHints: <String>[
      'american_hamburger_stereotype',
      'america',
      'food',
      'stereotype',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'adjusted_to_japan',
    description:
      'Responds to the first-meeting utterance: 日本の生活には'
      '慣れましたか？',
    examples: <String>[
      '日本の生活には慣れましたか？',
      '日本の生活には慣れましたか',
    ],
    keywords: <String>[
      '日本',
      '生活',
      '慣れた',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'living',
    },
    responseHints: <String>[
      'adjusted_to_japan',
      'japanese',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'difficulties_in_japan',
    description:
      'Responds to the first-meeting utterance: 日本で困ること'
      'ありますか？',
    examples: <String>[
      '日本で困ることありますか？',
      '日本で困ることありますか',
      '日本で困ることあります',
    ],
    keywords: <String>[
      '日本',
      '困る',
      '大変',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'living',
    },
    responseHints: <String>[
      'difficulties_in_japan',
      'japanese',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'japan_america_living',
    description:
      'Responds to the first-meeting utterance: 日本とアメリカ'
      '、どっちが住みやすいですか？',
    examples: <String>[
      '日本とアメリカ、どっちが住みやすいですか？',
      '日本とアメリカ、どっちが住みやすいですか',
      '日本とアメリカ、どっちが住みやすい',
    ],
    keywords: <String>[
      '日本',
      'アメリカ',
      'どっち',
      '住みやすい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'america',
      'living',
    },
    responseHints: <String>[
      'japan_america_living',
      'japanese',
      'america',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'future_in_japan',
    description:
      'Responds to the first-meeting utterance: これからも日本'
      'に住む予定ですか？',
    examples: <String>[
      'これからも日本に住む予定ですか？',
      'これからも日本に住む予定ですか',
      'これからも日本に住む予定',
    ],
    keywords: <String>[
      'これから',
      '日本',
      '住む',
      '予定',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'future',
      'living',
    },
    responseHints: <String>[
      'future_in_japan',
      'japanese',
      'future',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'permanent_residence_japan',
    description:
      'Responds to the first-meeting utterance: 永住するんです'
      'か？',
    examples: <String>[
      '永住するんですか？',
      '永住するんですか',
      '永住するの',
      '永住するん',
    ],
    keywords: <String>[
      '永住',
      '日本',
      'ずっと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'future',
      'living',
    },
    responseHints: <String>[
      'permanent_residence_japan',
      'japanese',
      'future',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'family_in_japan',
    description:
      'Responds to the first-meeting utterance: 日本で家族はい'
      'るんですか？',
    examples: <String>[
      '日本で家族はいるんですか？',
      '日本で家族はいるんですか',
      '日本で家族はいるの',
      '日本で家族はいるん',
    ],
    keywords: <String>[
      '日本',
      '家族',
      'いる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'family',
      'japanese',
    },
    responseHints: <String>[
      'family_in_japan',
      'family',
      'japanese',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'homesick',
    description:
      'Responds to the first-meeting utterance: ホームシックに'
      'ならないですか？',
    examples: <String>[
      'ホームシックにならないですか？',
      'ホームシックにならないですか',
      'ホームシックにならない',
    ],
    keywords: <String>[
      'ホームシック',
      '寂しい',
      '母国',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'family',
      'living',
    },
    responseHints: <String>[
      'homesick',
      'family',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_job',
    description:
      'Responds to the first-meeting utterance: 日本では何の仕'
      '事をしてるんですか？',
    examples: <String>[
      '日本では何の仕事をしてるんですか？',
      '日本では何の仕事をしてるんですか',
      '日本では何の仕事をしてるの',
      '日本では何の仕事をしてるん',
      '何の仕事してるんですか',
      '何の仕事してるの',
      '仕事何してるの',
      'どんな仕事してますか',
      '職業は何ですか',
    ],
    keywords: <String>[
      '仕事',
      '何',
      'してる',
    ],
    exclusions: <String>[
      '明日',
      '忙しい',
      '楽しい',
      '日本語',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'work',
    },
    responseHints: <String>[
      'ask_job',
      'work',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'english_teacher_assumption',
    description:
      'Responds to the first-meeting utterance: 英語の先生です'
      'か？',
    examples: <String>[
      '英語の先生ですか？',
      '英語の先生ですか',
      '英語の先生',
      '英語教師ですか',
      '英会話の先生',
    ],
    keywords: <String>[
      '英語',
      '先生',
      '教師',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'work',
      'english',
    },
    responseHints: <String>[
      'english_teacher_assumption',
      'work',
      'english',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'japanese_at_work',
    description:
      'Responds to the first-meeting utterance: 仕事で日本語使'
      'うんですか？',
    examples: <String>[
      '仕事で日本語使うんですか？',
      '仕事で日本語使うんですか',
      '仕事で日本語使うの',
      '仕事で日本語使うん',
    ],
    keywords: <String>[
      '仕事',
      '日本語',
      '使う',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'work',
      'japanese',
    },
    responseHints: <String>[
      'japanese_at_work',
      'work',
      'japanese',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_busy_work',
    description:
      'Responds to the first-meeting utterance: 仕事忙しいです'
      'か？',
    examples: <String>[
      '仕事忙しいですか？',
      '仕事忙しいですか',
      '仕事忙しい',
    ],
    keywords: <String>[
      '仕事',
      '忙しい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'work',
    },
    responseHints: <String>[
      'ask_busy_work',
      'work',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'days_off_schedule',
    description:
      'Responds to the first-meeting utterance: 休みは土日です'
      'か？',
    examples: <String>[
      '休みは土日ですか？',
      '休みは土日ですか',
      '休みは土日',
    ],
    keywords: <String>[
      '休み',
      '土日',
      '何曜日',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'work',
      'days_off',
    },
    responseHints: <String>[
      'days_off_schedule',
      'work',
      'days_off',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'days_off',
    description:
      'Responds to the first-meeting utterance: 休みの日は何し'
      'てるんですか？',
    examples: <String>[
      '休みの日は何してるんですか？',
      '休みの日は何してるんですか',
      '休みの日は何してるの',
      '休みの日は何してるん',
      '休みの日何してる',
      '休日はどう過ごす',
    ],
    keywords: <String>[
      '休みの日',
      '何してる',
      '過ごす',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'days_off',
      'hobbies',
    },
    responseHints: <String>[
      'days_off',
      'hobbies',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_hobbies',
    description:
      'Responds to the first-meeting utterance: 趣味は何ですか'
      '？',
    examples: <String>[
      '趣味は何ですか？',
      '趣味は何ですか',
      '趣味は何',
      '趣味何',
      '何するのが好き',
      '普段何して遊ぶの',
    ],
    keywords: <String>[
      '趣味',
      '何',
      '好きなこと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
    },
    responseHints: <String>[
      'ask_hobbies',
      'hobbies',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_sports',
    description:
      'Responds to the first-meeting utterance: スポーツしてま'
      'すか？',
    examples: <String>[
      'スポーツしてますか？',
      'スポーツしてますか',
      'スポーツしてます',
    ],
    keywords: <String>[
      'スポーツ',
      '運動',
      'してる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'sports',
    },
    responseHints: <String>[
      'ask_sports',
      'hobbies',
      'sports',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_drink',
    description:
      'Responds to the first-meeting utterance: お酒飲みますか'
      '？',
    examples: <String>[
      'お酒飲みますか？',
      'お酒飲みますか',
      'お酒飲みます',
    ],
    keywords: <String>[
      'お酒',
      '飲む',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'drinks',
    },
    responseHints: <String>[
      'ask_drink',
      'drinks',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'drinking_frequency',
    description:
      'Responds to the first-meeting utterance: よく飲みに行く'
      'んですか？',
    examples: <String>[
      'よく飲みに行くんですか？',
      'よく飲みに行くんですか',
      'よく飲みに行くの',
      'よく飲みに行くん',
    ],
    keywords: <String>[
      'よく',
      '飲みに行く',
      '頻繁',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'drinks',
    },
    responseHints: <String>[
      'drinking_frequency',
      'drinks',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_karaoke',
    description:
      'Responds to the first-meeting utterance: カラオケ行きま'
      'すか？',
    examples: <String>[
      'カラオケ行きますか？',
      'カラオケ行きますか',
      'カラオケ行きます',
    ],
    keywords: <String>[
      'カラオケ',
      '行く',
      '歌う',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'karaoke',
    },
    responseHints: <String>[
      'ask_karaoke',
      'hobbies',
      'karaoke',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_anime',
    description:
      'Responds to the first-meeting utterance: アニメ見ますか'
      '？',
    examples: <String>[
      'アニメ見ますか？',
      'アニメ見ますか',
      'アニメ見ます',
    ],
    keywords: <String>[
      'アニメ',
      '見る',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'anime',
    },
    responseHints: <String>[
      'ask_anime',
      'hobbies',
      'anime',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_games',
    description:
      'Responds to the first-meeting utterance: ゲームしますか'
      '？',
    examples: <String>[
      'ゲームしますか？',
      'ゲームしますか',
      'ゲームします',
    ],
    keywords: <String>[
      'ゲーム',
      'する',
      'やる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'games',
    },
    responseHints: <String>[
      'ask_games',
      'hobbies',
      'games',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'places_visited_japan',
    description:
      'Responds to the first-meeting utterance: 日本のどこに行'
      'ったことがありますか？',
    examples: <String>[
      '日本のどこに行ったことがありますか？',
      '日本のどこに行ったことがありますか',
      '日本のどこに行ったことがあります',
    ],
    keywords: <String>[
      '日本',
      'どこ',
      '行ったこと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'travel',
      'japanese',
    },
    responseHints: <String>[
      'places_visited_japan',
      'travel',
      'japanese',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'favorite_place_japan',
    description:
      'Responds to the first-meeting utterance: 日本でどこが一'
      '番好きですか？',
    examples: <String>[
      '日本でどこが一番好きですか？',
      '日本でどこが一番好きですか',
      '日本でどこが一番好き',
    ],
    keywords: <String>[
      '日本',
      'どこ',
      '一番',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'travel',
      'japanese',
      'preferences',
    },
    responseHints: <String>[
      'favorite_place_japan',
      'travel',
      'japanese',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'travel_wishlist',
    description:
      'Responds to the first-meeting utterance: 行ってみたいと'
      'ころありますか？',
    examples: <String>[
      '行ってみたいところありますか？',
      '行ってみたいところありますか',
      '行ってみたいところあります',
    ],
    keywords: <String>[
      '行ってみたい',
      'ところ',
      '場所',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'travel',
    },
    responseHints: <String>[
      'travel_wishlist',
      'travel',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'likes_onsen',
    description:
      'Responds to the first-meeting utterance: 温泉好きですか'
      '？',
    examples: <String>[
      '温泉好きですか？',
      '温泉好きですか',
      '温泉好き',
    ],
    keywords: <String>[
      '温泉',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'travel',
      'onsen',
    },
    responseHints: <String>[
      'likes_onsen',
      'travel',
      'onsen',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'visited_kyoto',
    description:
      'Responds to the first-meeting utterance: 京都行ったこと'
      'ありますか？',
    examples: <String>[
      '京都行ったことありますか？',
      '京都行ったことありますか',
      '京都行ったことあります',
    ],
    keywords: <String>[
      '京都',
      '行ったこと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'travel',
      'kyoto',
    },
    responseHints: <String>[
      'visited_kyoto',
      'travel',
      'kyoto',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'america_fact_question',
    description:
      'Responds to the first-meeting utterance: アメリカって本'
      '当に〇〇なんですか？',
    examples: <String>[
      'アメリカって本当に〇〇なんですか？',
      'アメリカって本当に〇〇なんですか',
      'アメリカって本当に〇〇なの',
      'アメリカって本当に〇〇なん',
    ],
    keywords: <String>[
      'アメリカ',
      '本当',
      'ほんと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'america',
      'stereotype',
    },
    responseHints: <String>[
      'america_fact_question',
      'america',
      'stereotype',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'americans_party_stereotype',
    description:
      'Responds to the first-meeting utterance: アメリカ人って'
      'みんなパーティー好きですか？',
    examples: <String>[
      'アメリカ人ってみんなパーティー好きですか？',
      'アメリカ人ってみんなパーティー好きですか',
      'アメリカ人ってみんなパーティー好き',
    ],
    keywords: <String>[
      'アメリカ人',
      'みんな',
      'パーティー',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'america',
      'stereotype',
      'party',
    },
    responseHints: <String>[
      'americans_party_stereotype',
      'america',
      'stereotype',
      'party',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'american_confession_culture',
    description:
      'Responds to the first-meeting utterance: アメリカ人って'
      '告白しないんですよね？',
    examples: <String>[
      'アメリカ人って告白しないんですよね？',
      'アメリカ人って告白しないんですよね',
    ],
    keywords: <String>[
      'アメリカ人',
      '告白',
      'しない',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'america',
      'dating',
      'culture',
    },
    responseHints: <String>[
      'american_confession_culture',
      'america',
      'dating',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'american_dating_culture',
    description:
      'Responds to the first-meeting utterance: アメリカではデ'
      'ートってどんな感じですか？',
    examples: <String>[
      'アメリカではデートってどんな感じですか？',
      'アメリカではデートってどんな感じですか',
      'アメリカではデートってどんな感じ',
    ],
    keywords: <String>[
      'アメリカ',
      'デート',
      'どんな',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'america',
      'dating',
      'culture',
    },
    responseHints: <String>[
      'american_dating_culture',
      'america',
      'dating',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_age',
    description: 'Responds to the first-meeting utterance: 何歳ですか？',
    examples: <String>[
      '何歳ですか？',
      '何歳ですか',
      '何歳',
    ],
    keywords: <String>[
      '何歳',
      '年齢',
      'いくつ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'personal',
      'age',
    },
    responseHints: <String>[
      'ask_age',
      'personal',
      'age',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_young',
    description:
      'Responds to the first-meeting utterance: 若く見えますね'
      '！',
    examples: <String>[
      '若く見えますね！',
    ],
    keywords: <String>[
      '若く見える',
      '若い',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'age',
    },
    responseHints: <String>[
      'compliment_young',
      'compliments',
      'age',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_height',
    description:
      'Responds to the first-meeting utterance: 身長何センチで'
      'すか？',
    examples: <String>[
      '身長何センチですか？',
      '身長何センチですか',
      '身長何センチ',
    ],
    keywords: <String>[
      '身長',
      '何センチ',
      'どのくらい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'personal',
      'height',
    },
    responseHints: <String>[
      'ask_height',
      'personal',
      'height',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_family',
    description: 'Responds to the first-meeting utterance: 兄弟いますか？',
    examples: <String>[
      '兄弟いますか？',
      '兄弟いますか',
      '兄弟います',
    ],
    keywords: <String>[
      '兄弟',
      '姉妹',
      'いる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'family',
      'siblings',
    },
    responseHints: <String>[
      'ask_family',
      'family',
      'siblings',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_pets',
    description:
      'Responds to the first-meeting utterance: ペット飼ってま'
      'すか？',
    examples: <String>[
      'ペット飼ってますか？',
      'ペット飼ってますか',
      'ペット飼ってます',
    ],
    keywords: <String>[
      'ペット',
      '飼ってる',
      '動物',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'pets',
    },
    responseHints: <String>[
      'ask_pets',
      'hobbies',
      'pets',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'living_alone',
    description:
      'Responds to the first-meeting utterance: 一人暮らしです'
      'か？',
    examples: <String>[
      '一人暮らしですか？',
      '一人暮らしですか',
      '一人暮らし',
      '誰かと住んでる',
      '一人で住んでるんですか',
    ],
    keywords: <String>[
      '一人暮らし',
      '誰と',
      '住んでる',
    ],
    exclusions: <String>[
      '今日は一人',
      '家族',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'living',
      'home',
    },
    responseHints: <String>[
      'living_alone',
      'living',
      'home',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_residence',
    description:
      'Responds to the first-meeting utterance: どこに住んでる'
      'んですか？',
    examples: <String>[
      'どこに住んでるんですか？',
      'どこに住んでるんですか',
      'どこに住んでるの',
      'どこに住んでるん',
      'どの辺に住んでますか',
      '家どこ',
    ],
    keywords: <String>[
      'どこ',
      '住んでる',
      '住まい',
    ],
    exclusions: <String>[
      '将来',
      '誰と',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'location',
      'living',
    },
    responseHints: <String>[
      'ask_residence',
      'location',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_neighborhood',
    description:
      'Responds to the first-meeting utterance: この辺よく来る'
      'んですか？',
    examples: <String>[
      'この辺よく来るんですか？',
      'この辺よく来るんですか',
      'この辺よく来るの',
      'この辺よく来るん',
    ],
    keywords: <String>[
      'この辺',
      'よく来る',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'location',
      'availability',
    },
    responseHints: <String>[
      'ask_neighborhood',
      'location',
      'availability',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'relationship_status',
    description:
      'Responds to the first-meeting utterance: 彼女いるんです'
      'か？',
    examples: <String>[
      '彼女いるんですか？',
      '彼女いるんですか',
      '彼女いるの',
      '彼女いるん',
      '彼女いますか',
      '彼女いる',
      '今彼女いる',
      '彼女とかいるんですか',
      '付き合ってる人いる',
      '恋人いる',
      '恋人いるの',
    ],
    keywords: <String>[
      '彼女',
      '恋人',
      '付き合ってる',
      'いる',
    ],
    exclusions: <String>[
      '日本人の彼女',
      '昔',
      'いたこと',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'relationship_status',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_married',
    description:
      'Responds to the first-meeting utterance: 結婚してますか'
      '？',
    examples: <String>[
      '結婚してますか？',
      '結婚してますか',
      '結婚してます',
      '既婚ですか',
      '結婚してるの',
    ],
    keywords: <String>[
      '結婚',
      '既婚',
      'してる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'marriage',
    },
    responseHints: <String>[
      'ask_married',
      'relationships',
      'marriage',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'single_status',
    description: 'Responds to the first-meeting utterance: 独身ですか？',
    examples: <String>[
      '独身ですか？',
      '独身ですか',
      '独身',
      '今フリー',
      'シングルですか',
      '今誰とも付き合ってない',
    ],
    keywords: <String>[
      '独身',
      'フリー',
      'シングル',
    ],
    exclusions: <String>[
      '一人暮らし',
      '一人ですか',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'single_status',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'has_romantic_interest',
    description:
      'Responds to the first-meeting utterance: 好きな人います'
      'か？',
    examples: <String>[
      '好きな人いますか？',
      '好きな人いますか',
      '好きな人います',
    ],
    keywords: <String>[
      '好きな人',
      '気になる人',
      'いる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'has_romantic_interest',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_type',
    description:
      'Responds to the first-meeting utterance: どんな女性がタ'
      'イプですか？',
    examples: <String>[
      'どんな女性がタイプですか？',
      'どんな女性がタイプですか',
      'どんな女性がタイプ',
      '好きなタイプは',
      'どんな人が好き',
    ],
    keywords: <String>[
      'どんな女性',
      'タイプ',
      '好きなタイプ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'preferences',
    },
    responseHints: <String>[
      'ask_type',
      'relationships',
      'dating',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'age_preference',
    description:
      'Responds to the first-meeting utterance: 年上と年下どっ'
      'ちが好きですか？',
    examples: <String>[
      '年上と年下どっちが好きですか？',
      '年上と年下どっちが好きですか',
      '年上と年下どっちが好き',
      '年上派年下派',
      '年上と年下どっち',
    ],
    keywords: <String>[
      '年上',
      '年下',
      'どっち',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'preferences',
    },
    responseHints: <String>[
      'age_preference',
      'relationships',
      'dating',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'likes_japanese_women',
    description:
      'Responds to the first-meeting utterance: 日本人女性は好'
      'きですか？',
    examples: <String>[
      '日本人女性は好きですか？',
      '日本人女性は好きですか',
      '日本人女性は好き',
    ],
    keywords: <String>[
      '日本人女性',
      '日本の女性',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'japanese',
    },
    responseHints: <String>[
      'likes_japanese_women',
      'relationships',
      'dating',
      'japanese',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'relationship_history_japanese_partner',
    description:
      'Responds to the first-meeting utterance: 今まで日本人の'
      '彼女いたことありますか？',
    examples: <String>[
      '今まで日本人の彼女いたことありますか？',
      '今まで日本人の彼女いたことありますか',
      '今まで日本人の彼女いたことあります',
    ],
    keywords: <String>[
      '日本人',
      '彼女',
      '付き合ったこと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'history',
    },
    responseHints: <String>[
      'relationship_history_japanese_partner',
      'relationships',
      'dating',
      'history',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_dated_foreigner',
    description:
      'Responds to the first-meeting utterance: 外国人と付き合'
      'ったことありますか？',
    examples: <String>[
      '外国人と付き合ったことありますか？',
      '外国人と付き合ったことありますか',
      '外国人と付き合ったことあります',
    ],
    keywords: <String>[
      '外国人',
      '付き合ったこと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'history',
    },
    responseHints: <String>[
      'ask_dated_foreigner',
      'relationships',
      'dating',
      'history',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_long_distance',
    description:
      'Responds to the first-meeting utterance: 遠距離恋愛でき'
      'ますか？',
    examples: <String>[
      '遠距離恋愛できますか？',
      '遠距離恋愛できますか',
      '遠距離恋愛できます',
    ],
    keywords: <String>[
      '遠距離',
      '恋愛',
      'できる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'ask_long_distance',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_want_marriage',
    description:
      'Responds to the first-meeting utterance: 結婚したいです'
      'か？',
    examples: <String>[
      '結婚したいですか？',
      '結婚したいですか',
      '結婚したい',
    ],
    keywords: <String>[
      '結婚',
      'したい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'marriage',
      'future',
    },
    responseHints: <String>[
      'ask_want_marriage',
      'relationships',
      'marriage',
      'future',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'wants_children',
    description:
      'Responds to the first-meeting utterance: 子ども欲しいで'
      'すか？',
    examples: <String>[
      '子ども欲しいですか？',
      '子ども欲しいですか',
      '子ども欲しい',
    ],
    keywords: <String>[
      '子ども',
      '欲しい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'family',
      'future',
    },
    responseHints: <String>[
      'wants_children',
      'relationships',
      'family',
      'future',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'foreigner_assertive_stereotype',
    description:
      'Responds to the first-meeting utterance: 外国人って積極'
      '的ですよね？',
    examples: <String>[
      '外国人って積極的ですよね？',
      '外国人って積極的ですよね',
    ],
    keywords: <String>[
      '外国人',
      '積極的',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'dating',
      'stereotype',
    },
    responseHints: <String>[
      'foreigner_assertive_stereotype',
      'dating',
      'stereotype',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'tease_pickup',
    description:
      'Responds to the first-meeting utterance: ナンパするんで'
      'すか？',
    examples: <String>[
      'ナンパするんですか？',
      'ナンパするんですか',
      'ナンパするの',
      'ナンパするん',
    ],
    keywords: <String>[
      'ナンパ',
      'する',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.tease,
    contextTags: <String>{
      'dating',
      'teasing',
    },
    responseHints: <String>[
      'tease_pickup',
      'dating',
      'teasing',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_are_popular',
    description: 'Responds to the first-meeting utterance: モテますよね？',
    examples: <String>[
      'モテますよね？',
      'モテますよね',
    ],
    keywords: <String>[
      'モテる',
      'モテます',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'dating',
      'teasing',
    },
    responseHints: <String>[
      'ask_are_popular',
      'dating',
      'teasing',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'tease_popular',
    description:
      'Responds to the first-meeting utterance: 日本人にモテそ'
      'う。',
    examples: <String>[
      '日本人にモテそう。',
      '日本人にモテそう',
    ],
    keywords: <String>[
      '日本人',
      'モテそう',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.tease,
    contextTags: <String>{
      'dating',
      'teasing',
    },
    responseHints: <String>[
      'tease_popular',
      'dating',
      'teasing',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'foreigner_popularity_comment',
    description:
      'Responds to the first-meeting utterance: 外国人好きな女'
      'の子多いですよ。',
    examples: <String>[
      '外国人好きな女の子多いですよ。',
      '外国人好きな女の子多いですよ',
    ],
    keywords: <String>[
      '外国人好き',
      '女の子',
      '多い',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.sharedInformation,
    contextTags: <String>{
      'dating',
      'foreigners',
    },
    responseHints: <String>[
      'foreigner_popularity_comment',
      'dating',
      'foreigners',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'wants_date_foreigner',
    description:
      'Responds to the first-meeting utterance: 外国人と付き合'
      'ってみたい。',
    examples: <String>[
      '外国人と付き合ってみたい。',
      '外国人と付き合ってみたい',
    ],
    keywords: <String>[
      '外国人',
      '付き合ってみたい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.sharedInformation,
    contextTags: <String>{
      'dating',
      'foreigners',
    },
    responseHints: <String>[
      'wants_date_foreigner',
      'dating',
      'foreigners',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_height',
    description: 'Responds to the first-meeting utterance: 背高いですね。',
    examples: <String>[
      '背高いですね。',
      '背高いですね',
      '背高いだね',
    ],
    keywords: <String>[
      '背',
      '高い',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'height',
    },
    responseHints: <String>[
      'compliment_height',
      'compliments',
      'height',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_eyes',
    description:
      'Responds to the first-meeting utterance: 目の色きれいで'
      'すね。',
    examples: <String>[
      '目の色きれいですね。',
      '目の色きれいですね',
      '目の色きれいだね',
    ],
    keywords: <String>[
      '目',
      '目の色',
      '綺麗',
      'きれい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'eyes',
    },
    responseHints: <String>[
      'compliment_eyes',
      'compliments',
      'eyes',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_nose',
    description: 'Responds to the first-meeting utterance: 鼻高いですね。',
    examples: <String>[
      '鼻高いですね。',
      '鼻高いですね',
      '鼻高いだね',
    ],
    keywords: <String>[
      '鼻',
      '高い',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'appearance',
    },
    responseHints: <String>[
      'compliment_nose',
      'compliments',
      'appearance',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_face_size',
    description:
      'Responds to the first-meeting utterance: 顔小さいですね'
      '。',
    examples: <String>[
      '顔小さいですね。',
      '顔小さいですね',
      '顔小さいだね',
    ],
    keywords: <String>[
      '顔',
      '小さい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'appearance',
    },
    responseHints: <String>[
      'compliment_face_size',
      'compliments',
      'appearance',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_cool',
    description:
      'Responds to the first-meeting utterance: かっこいいです'
      'ね。',
    examples: <String>[
      'かっこいいですね。',
      'かっこいいですね',
      'かっこいいだね',
    ],
    keywords: <String>[
      'かっこいい',
      '格好いい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'appearance',
    },
    responseHints: <String>[
      'compliment_cool',
      'compliments',
      'appearance',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'tease_past_popular',
    description:
      'Responds to the first-meeting utterance: 若い頃モテたで'
      'しょ？',
    examples: <String>[
      '若い頃モテたでしょ？',
      '若い頃モテたでしょ',
    ],
    keywords: <String>[
      '若い頃',
      'モテた',
      '過去',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.tease,
    contextTags: <String>{
      'dating',
      'teasing',
    },
    responseHints: <String>[
      'tease_past_popular',
      'dating',
      'teasing',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_personality',
    description:
      'Responds to the first-meeting utterance: どんな性格です'
      'か？',
    examples: <String>[
      'どんな性格ですか？',
      'どんな性格ですか',
      'どんな性格',
    ],
    keywords: <String>[
      'どんな性格',
      '性格',
      'どんな人',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'personal',
      'personality',
    },
    responseHints: <String>[
      'ask_personality',
      'personal',
      'personality',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'shy_personality',
    description:
      'Responds to the first-meeting utterance: 人見知りします'
      'か？',
    examples: <String>[
      '人見知りしますか？',
      '人見知りしますか',
      '人見知りします',
    ],
    keywords: <String>[
      '人見知り',
      'する',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'personal',
      'personality',
    },
    responseHints: <String>[
      'shy_personality',
      'personal',
      'personality',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'compliment_outgoing',
    description: 'Responds to the first-meeting utterance: 明るいですね。',
    examples: <String>[
      '明るいですね。',
      '明るいですね',
      '明るいだね',
    ],
    keywords: <String>[
      '明るい',
      '元気',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.compliment,
    contextTags: <String>{
      'compliments',
      'personality',
    },
    responseHints: <String>[
      'compliment_outgoing',
      'compliments',
      'personality',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'sociable_with_everyone',
    description:
      'Responds to the first-meeting utterance: 誰とでも話せる'
      'んですか？',
    examples: <String>[
      '誰とでも話せるんですか？',
      '誰とでも話せるんですか',
      '誰とでも話せるの',
      '誰とでも話せるん',
    ],
    keywords: <String>[
      '誰とでも',
      '話せる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'personal',
      'personality',
    },
    responseHints: <String>[
      'sociable_with_everyone',
      'personal',
      'personality',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'frequent_this_shop',
    description:
      'Responds to the first-meeting utterance: よくこの店来る'
      'んですか？',
    examples: <String>[
      'よくこの店来るんですか？',
      'よくこの店来るんですか',
      'よくこの店来るの',
      'よくこの店来るん',
    ],
    keywords: <String>[
      'この店',
      'よく来る',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'location',
      'venue',
    },
    responseHints: <String>[
      'frequent_this_shop',
      'location',
      'venue',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'alone_today',
    description:
      'Responds to the first-meeting utterance: 今日は一人です'
      'か？',
    examples: <String>[
      '今日は一人ですか？',
      '今日は一人ですか',
      '今日は一人',
    ],
    keywords: <String>[
      '今日',
      '一人',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'availability',
      'companions',
    },
    responseHints: <String>[
      'alone_today',
      'availability',
      'companions',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'waiting_for_friend',
    description:
      'Responds to the first-meeting utterance: 友達待ってるん'
      'ですか？',
    examples: <String>[
      '友達待ってるんですか？',
      '友達待ってるんですか',
      '友達待ってるの',
      '友達待ってるん',
    ],
    keywords: <String>[
      '友達',
      '待ってる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'availability',
      'companions',
    },
    responseHints: <String>[
      'waiting_for_friend',
      'availability',
      'companions',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'plans_after_this',
    description:
      'Responds to the first-meeting utterance: このあとどうす'
      'るんですか？',
    examples: <String>[
      'このあとどうするんですか？',
      'このあとどうするんですか',
      'このあとどうするの',
      'このあとどうするん',
      'このあと予定ある',
      'このあと何する',
      'これからどうするの',
    ],
    keywords: <String>[
      'このあと',
      'どうする',
      '予定',
    ],
    exclusions: <String>[
      '何時まで',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'availability',
      'plans',
    },
    responseHints: <String>[
      'plans_after_this',
      'availability',
      'plans',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_tomorrow_work',
    description:
      'Responds to the first-meeting utterance: 明日仕事ですか'
      '？',
    examples: <String>[
      '明日仕事ですか？',
      '明日仕事ですか',
      '明日仕事',
    ],
    keywords: <String>[
      '明日',
      '仕事',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'work',
      'availability',
    },
    responseHints: <String>[
      'ask_tomorrow_work',
      'work',
      'availability',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'how_late_staying',
    description:
      'Responds to the first-meeting utterance: 何時まで飲むん'
      'ですか？',
    examples: <String>[
      '何時まで飲むんですか？',
      '何時まで飲むんですか',
      '何時まで飲むの',
      '何時まで飲むん',
      '何時までいるの',
      'いつまでいる',
      '今日は何時まで',
    ],
    keywords: <String>[
      '何時まで',
      'いつまで',
      '飲む',
      'いる',
    ],
    exclusions: <String>[
      'このあと何する',
      '予定ある',
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'availability',
      'drinks',
    },
    responseHints: <String>[
      'how_late_staying',
      'availability',
      'drinks',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'uses_line',
    description:
      'Responds to the first-meeting utterance: LINEやって'
      'ますか？',
    examples: <String>[
      'LINEやってますか？',
      'LINEやってますか',
      'LINEやってます',
    ],
    keywords: <String>[
      'LINE',
      'ライン',
      'やってる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'social_media',
      'contact',
    },
    responseHints: <String>[
      'uses_line',
      'social_media',
      'contact',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'uses_instagram',
    description:
      'Responds to the first-meeting utterance: インスタやって'
      'ますか？',
    examples: <String>[
      'インスタやってますか？',
      'インスタやってますか',
      'インスタやってます',
    ],
    keywords: <String>[
      'インスタ',
      'Instagram',
      'やってる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'social_media',
      'contact',
    },
    responseHints: <String>[
      'uses_instagram',
      'social_media',
      'contact',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'next_time_here',
    description:
      'Responds to the first-meeting utterance: 今度いつこの辺'
      '来ますか？',
    examples: <String>[
      '今度いつこの辺来ますか？',
      '今度いつこの辺来ますか',
      '今度いつこの辺来ます',
      '次いつ来る',
      'またこの辺来る',
    ],
    keywords: <String>[
      '今度',
      'いつ',
      'この辺',
      '来る',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'availability',
      'future',
      'location',
    },
    responseHints: <String>[
      'next_time_here',
      'availability',
      'future',
      'location',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'invite_drink_again',
    description:
      'Responds to the first-meeting utterance: また飲みましょ'
      'う。',
    examples: <String>[
      'また飲みましょう。',
      'また飲みましょう',
    ],
    keywords: <String>[
      'また',
      '飲みましょう',
      '飲もう',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.invitation,
    contextTags: <String>{
      'invitation',
      'drinks',
    },
    responseHints: <String>[
      'invite_drink_again',
      'invitation',
      'drinks',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'invite_food',
    description:
      'Responds to the first-meeting utterance: 今度ご飯行きま'
      'せん？',
    examples: <String>[
      '今度ご飯行きません？',
      '今度ご飯行きません',
    ],
    keywords: <String>[
      '今度',
      'ご飯',
      '行かない',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.invitation,
    contextTags: <String>{
      'invitation',
      'food',
    },
    responseHints: <String>[
      'invite_food',
      'invitation',
      'food',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'invite_go_next_time',
    description:
      'Responds to the first-meeting utterance: 今度〇〇行きま'
      'しょうよ。',
    examples: <String>[
      '今度〇〇行きましょうよ。',
      '今度〇〇行きましょうよ',
    ],
    keywords: <String>[
      '今度',
      '行きましょう',
      '行こう',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.invitation,
    contextTags: <String>{
      'invitation',
      'future',
    },
    responseHints: <String>[
      'invite_go_next_time',
      'invitation',
      'future',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_food',
    description:
      'Responds to the first-meeting utterance: どんな食べ物好'
      'きですか？',
    examples: <String>[
      'どんな食べ物好きですか？',
      'どんな食べ物好きですか',
      'どんな食べ物好き',
    ],
    keywords: <String>[
      'どんな食べ物',
      '好き',
      '何食べる',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'preferences',
    },
    responseHints: <String>[
      'ask_food',
      'food',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ask_sweets',
    description:
      'Responds to the first-meeting utterance: 甘いもの好きで'
      'すか？',
    examples: <String>[
      '甘いもの好きですか？',
      '甘いもの好きですか',
      '甘いもの好き',
    ],
    keywords: <String>[
      '甘いもの',
      '好き',
      '甘党',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'food',
      'sweets',
    },
    responseHints: <String>[
      'ask_sweets',
      'food',
      'sweets',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'pet_preference',
    description: 'Responds to the first-meeting utterance: 犬派？猫派？',
    examples: <String>[
      '犬派？猫派？',
      '犬派？猫派',
    ],
    keywords: <String>[
      '犬派',
      '猫派',
      'どっち',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'pets',
      'preferences',
    },
    responseHints: <String>[
      'pet_preference',
      'hobbies',
      'pets',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'sea_or_mountain',
    description:
      'Responds to the first-meeting utterance: 海と山どっちが'
      '好き？',
    examples: <String>[
      '海と山どっちが好き？',
      '海と山どっちが好き',
    ],
    keywords: <String>[
      '海',
      '山',
      'どっち',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'travel',
      'preferences',
    },
    responseHints: <String>[
      'sea_or_mountain',
      'hobbies',
      'travel',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'indoor_outdoor',
    description:
      'Responds to the first-meeting utterance: インドア？アウ'
      'トドア？',
    examples: <String>[
      'インドア？アウトドア？',
      'インドア？アウトドア',
    ],
    keywords: <String>[
      'インドア',
      'アウトドア',
      'どっち',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'hobbies',
      'preferences',
    },
    responseHints: <String>[
      'indoor_outdoor',
      'hobbies',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'preferred_date',
    description:
      'Responds to the first-meeting utterance: どんなデートが'
      '好きですか？',
    examples: <String>[
      'どんなデートが好きですか？',
      'どんなデートが好きですか',
      'どんなデートが好き',
    ],
    keywords: <String>[
      'どんなデート',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'preferences',
    },
    responseHints: <String>[
      'preferred_date',
      'relationships',
      'dating',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'ideal_date',
    description:
      'Responds to the first-meeting utterance: 理想のデートは'
      '？',
    examples: <String>[
      '理想のデートは？',
      '理想のデートは',
    ],
    keywords: <String>[
      '理想',
      'デート',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
      'preferences',
    },
    responseHints: <String>[
      'ideal_date',
      'relationships',
      'dating',
      'preferences',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'attentive_partner',
    description:
      'Responds to the first-meeting utterance: 付き合ったらマ'
      'メですか？',
    examples: <String>[
      '付き合ったらマメですか？',
      '付き合ったらマメですか',
      '付き合ったらマメ',
    ],
    keywords: <String>[
      '付き合ったら',
      'マメ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'attentive_partner',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'jealousy',
    description: 'Responds to the first-meeting utterance: 嫉妬しますか？',
    examples: <String>[
      '嫉妬しますか？',
      '嫉妬しますか',
      '嫉妬します',
    ],
    keywords: <String>[
      '嫉妬',
      'する',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'jealousy',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'contact_frequency',
    description:
      'Responds to the first-meeting utterance: 連絡は毎日した'
      'いタイプ？',
    examples: <String>[
      '連絡は毎日したいタイプ？',
      '連絡は毎日したいタイプ',
    ],
    keywords: <String>[
      '連絡',
      '毎日',
      'タイプ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'contact',
    },
    responseHints: <String>[
      'contact_frequency',
      'relationships',
      'contact',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'phone_calls',
    description:
      'Responds to the first-meeting utterance: 電話好きですか'
      '？',
    examples: <String>[
      '電話好きですか？',
      '電話好きですか',
      '電話好き',
    ],
    keywords: <String>[
      '電話',
      '好き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'contact',
    },
    responseHints: <String>[
      'phone_calls',
      'relationships',
      'contact',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'affectionate_style',
    description:
      'Responds to the first-meeting utterance: 甘えるタイプで'
      'すか？',
    examples: <String>[
      '甘えるタイプですか？',
      '甘えるタイプですか',
      '甘えるタイプ',
    ],
    keywords: <String>[
      '甘える',
      'タイプ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'affectionate_style',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'physical_affection',
    description:
      'Responds to the first-meeting utterance: スキンシップ多'
      'いですか？',
    examples: <String>[
      'スキンシップ多いですか？',
      'スキンシップ多いですか',
      'スキンシップ多い',
    ],
    keywords: <String>[
      'スキンシップ',
      '多い',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'dating',
    },
    responseHints: <String>[
      'physical_affection',
      'relationships',
      'dating',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
      'interest_probe',
      'playful_question_reversal',
    ],
    priority: 90,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'marriage_japanese_partner',
    description:
      'Responds to the first-meeting utterance: 日本人と結婚す'
      'る可能性ありますか？',
    examples: <String>[
      '日本人と結婚する可能性ありますか？',
      '日本人と結婚する可能性ありますか',
      '日本人と結婚する可能性あります',
    ],
    keywords: <String>[
      '日本人',
      '結婚',
      '可能性',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'relationships',
      'marriage',
      'japanese',
    },
    responseHints: <String>[
      'marriage_japanese_partner',
      'relationships',
      'marriage',
      'japanese',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'future_residence',
    description:
      'Responds to the first-meeting utterance: 将来どこに住み'
      'たいですか？',
    examples: <String>[
      '将来どこに住みたいですか？',
      '将来どこに住みたいですか',
      '将来どこに住みたい',
    ],
    keywords: <String>[
      '将来',
      'どこ',
      '住みたい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'future',
      'living',
    },
    responseHints: <String>[
      'future_residence',
      'future',
      'living',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'return_to_america',
    description:
      'Responds to the first-meeting utterance: アメリカに帰る'
      '予定ありますか？',
    examples: <String>[
      'アメリカに帰る予定ありますか？',
      'アメリカに帰る予定ありますか',
      'アメリカに帰る予定あります',
    ],
    keywords: <String>[
      'アメリカ',
      '帰る',
      '予定',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'future',
      'america',
    },
    responseHints: <String>[
      'return_to_america',
      'future',
      'america',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'opinion_japanese_women',
    description:
      'Responds to the first-meeting utterance: 日本の女性はど'
      'うですか？',
    examples: <String>[
      '日本の女性はどうですか？',
      '日本の女性はどうですか',
      '日本の女性はどう',
    ],
    keywords: <String>[
      '日本の女性',
      'どう',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'relationships',
    },
    responseHints: <String>[
      'opinion_japanese_women',
      'japanese',
      'relationships',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'opinion_japanese_people',
    description:
      'Responds to the first-meeting utterance: 日本人ってどう'
      '思います？',
    examples: <String>[
      '日本人ってどう思います？',
      '日本人ってどう思います',
    ],
    keywords: <String>[
      '日本人',
      'どう思う',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'culture',
    },
    responseHints: <String>[
      'opinion_japanese_people',
      'japanese',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'dislikes_japan',
    description:
      'Responds to the first-meeting utterance: 日本の嫌いなと'
      'ころありますか？',
    examples: <String>[
      '日本の嫌いなところありますか？',
      '日本の嫌いなところありますか',
      '日本の嫌いなところあります',
    ],
    keywords: <String>[
      '日本',
      '嫌いなところ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'culture',
    },
    responseHints: <String>[
      'dislikes_japan',
      'japanese',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'america_better',
    description:
      'Responds to the first-meeting utterance: アメリカのほう'
      'がいいと思うことあります？',
    examples: <String>[
      'アメリカのほうがいいと思うことあります？',
      'アメリカのほうがいいと思うことあります',
    ],
    keywords: <String>[
      'アメリカ',
      'ほうがいい',
      '日本',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'america',
      'japanese',
      'culture',
    },
    responseHints: <String>[
      'america_better',
      'america',
      'japanese',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'surprise_in_japan',
    description:
      'Responds to the first-meeting utterance: 日本来て驚いた'
      'ことは？',
    examples: <String>[
      '日本来て驚いたことは？',
      '日本来て驚いたことは',
    ],
    keywords: <String>[
      '日本',
      '驚いたこと',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'culture',
    },
    responseHints: <String>[
      'surprise_in_japan',
      'japanese',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'culture_shock_japan',
    description:
      'Responds to the first-meeting utterance: 日本で一番カル'
      'チャーショックだったことは？',
    examples: <String>[
      '日本で一番カルチャーショックだったことは？',
      '日本で一番カルチャーショックだったことは',
    ],
    keywords: <String>[
      '日本',
      'カルチャーショック',
      '一番',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.question,
    contextTags: <String>{
      'japanese',
      'culture',
    },
    responseHints: <String>[
      'culture_shock_japan',
      'japanese',
      'culture',
      'statement',
      'comeback',
      'ask_back',
      'conversation_hook',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'continue_then',
    description: 'Responds to the first-meeting utterance: それで？',
    examples: <String>[
      'それで？',
      'それで',
    ],
    keywords: <String>[
      'それで',
      '続き',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.interest,
    contextTags: <String>{
      'continuation',
      'interest',
    },
    responseHints: <String>[
      'continue_then',
      'continuation',
      'interest',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'continue_why',
    description: 'Responds to the first-meeting utterance: なんで？',
    examples: <String>[
      'なんで？',
      'なんで',
    ],
    keywords: <String>[
      'なんで',
      'どうして',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.interest,
    contextTags: <String>{
      'continuation',
      'interest',
    },
    responseHints: <String>[
      'continue_why',
      'continuation',
      'interest',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'continue_example',
    description: 'Responds to the first-meeting utterance: 例えば？',
    examples: <String>[
      '例えば？',
      '例えば',
    ],
    keywords: <String>[
      '例えば',
      '例',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.interest,
    contextTags: <String>{
      'continuation',
      'interest',
    },
    responseHints: <String>[
      'continue_example',
      'continuation',
      'interest',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'continue_curious',
    description: 'Responds to the first-meeting utterance: それ気になる。',
    examples: <String>[
      'それ気になる。',
      'それ気になる',
    ],
    keywords: <String>[
      '気になる',
      'それ',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.interest,
    contextTags: <String>{
      'continuation',
      'interest',
    },
    responseHints: <String>[
      'continue_curious',
      'continuation',
      'interest',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
  ConversationIntentDefinition(
    id: 'continue_more',
    description:
      'Responds to the first-meeting utterance: もっと聞きたい'
      '。',
    examples: <String>[
      'もっと聞きたい。',
      'もっと聞きたい',
    ],
    keywords: <String>[
      'もっと',
      '聞きたい',
    ],
    exclusions: <String>[
    ],
    function: ConversationFunction.interest,
    contextTags: <String>{
      'continuation',
      'interest',
    },
    responseHints: <String>[
      'continue_more',
      'continuation',
      'interest',
    ],
    priority: 82,
    confidenceThreshold: 0.58,
  ),
];
