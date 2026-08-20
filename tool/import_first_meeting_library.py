#!/usr/bin/env python3
"""Convert the supplied first-meeting Markdown library into OpenCue data.

This is an authoring-time importer. Its JSON output is the checked-in source
consumed by ``build_conversation_library.py``; runtime matching continues to
use ConversationIntentMatcher and ConversationResponseEngine.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "tool" / "data" / "first_meeting_library.json"


# number|intent id|function|context tags|discriminating Japanese keywords
_SPEC_TEXT = r"""
1|ask_origin|question|origin,country|出身,どこ,国
2|origin_region|question|origin,region,america|アメリカ,どこ,どの辺,州
3|time_in_japan|question|japanese,travel|日本,どのくらい,何年目,長い,いつから
4|arrival_time_japan|question|japanese,travel|いつ,日本,来た,何年前
5|ask_reason_japan|question|japanese,travel|日本,どうして,なんで,きっかけ,理由
6|reason_fukuoka|question|fukuoka,location|福岡,なんで,どうして,住んでる
7|opinion_fukuoka|question|fukuoka,location|福岡,好き,どう
8|compliment_japanese|compliment|japanese,compliments|日本語,上手,うまい
9|japanese_study_method|question|japanese,study|日本語,どこで,勉強,覚えた,どうやって
10|compliment_japanese|compliment|japanese,compliments|日本語,ペラペラ,上手
11|read_kanji|question|japanese,kanji|漢字,読める,読めます
12|use_keigo|question|japanese,keigo|敬語,使える,話せる
13|easier_language|question|languages,preferences|英語,日本語,どっち,楽
14|dream_language|question|languages,japanese|日本語,夢,見る
15|likes_japanese_food|question|food,japanese_food|日本食,好き,食べる
16|favorite_japanese_food|question|food,japanese_food,preferences|日本食,何,一番,好き
17|likes_sushi|question|food,sushi|寿司,好き
18|can_eat_sashimi|question|food,sashimi|刺身,食べられる,大丈夫
19|can_eat_natto|question|food,natto|納豆,食べられる,大丈夫
20|can_eat_umeboshi|question|food,umeboshi|梅干し,食べられる,大丈夫
21|can_eat_wasabi|question|food,wasabi|わさび,大丈夫,食べられる
22|can_use_chopsticks|question|food,chopsticks|箸,使える,持てる
23|ask_spicy_food|question|food,spicy|辛い,大丈夫,食べられる
24|cook_home_food|question|food,cooking,origin|母国,料理,作れる
25|american_hamburger_stereotype|question|america,food,stereotype|アメリカ,毎日,ハンバーガー
26|adjusted_to_japan|question|japanese,living|日本,生活,慣れた
27|difficulties_in_japan|question|japanese,living|日本,困る,大変
28|japan_america_living|question|japanese,america,living|日本,アメリカ,どっち,住みやすい
29|future_in_japan|question|japanese,future,living|これから,日本,住む,予定
30|permanent_residence_japan|question|japanese,future,living|永住,日本,ずっと
31|family_in_japan|question|family,japanese|日本,家族,いる
32|homesick|question|family,living|ホームシック,寂しい,母国
33|ask_job|question|work|仕事,何,してる
34|english_teacher_assumption|question|work,english|英語,先生,教師
35|japanese_at_work|question|work,japanese|仕事,日本語,使う
36|ask_busy_work|question|work|仕事,忙しい
37|days_off_schedule|question|work,days_off|休み,土日,何曜日
38|days_off|question|days_off,hobbies|休みの日,何してる,過ごす
39|ask_hobbies|question|hobbies|趣味,何,好きなこと
40|ask_sports|question|hobbies,sports|スポーツ,運動,してる
41|ask_drink|question|drinks|お酒,飲む
42|drinking_frequency|question|drinks|よく,飲みに行く,頻繁
43|ask_karaoke|question|hobbies,karaoke|カラオケ,行く,歌う
44|ask_anime|question|hobbies,anime|アニメ,見る,好き
45|ask_games|question|hobbies,games|ゲーム,する,やる
46|places_visited_japan|question|travel,japanese|日本,どこ,行ったこと
47|favorite_place_japan|question|travel,japanese,preferences|日本,どこ,一番,好き
48|travel_wishlist|question|travel|行ってみたい,ところ,場所
49|likes_onsen|question|travel,onsen|温泉,好き
50|visited_kyoto|question|travel,kyoto|京都,行ったこと
51|america_fact_question|question|america,stereotype|アメリカ,本当,ほんと
52|americans_party_stereotype|question|america,stereotype,party|アメリカ人,みんな,パーティー
53|american_confession_culture|question|america,dating,culture|アメリカ人,告白,しない
54|american_dating_culture|question|america,dating,culture|アメリカ,デート,どんな
55|ask_age|question|personal,age|何歳,年齢,いくつ
56|compliment_young|compliment|compliments,age|若く見える,若い
57|ask_height|question|personal,height|身長,何センチ,どのくらい
58|ask_family|question|family,siblings|兄弟,姉妹,いる
59|ask_pets|question|hobbies,pets|ペット,飼ってる,動物
60|living_alone|question|living,home|一人暮らし,誰と,住んでる
61|ask_residence|question|location,living|どこ,住んでる,住まい
62|ask_neighborhood|question|location,availability|この辺,よく来る
63|relationship_status|question|relationships,dating|彼女,恋人,付き合ってる,いる
64|ask_married|question|relationships,marriage|結婚,既婚,してる
65|single_status|question|relationships,dating|独身,フリー,シングル
66|has_romantic_interest|question|relationships,dating|好きな人,気になる人,いる
67|ask_type|question|relationships,dating,preferences|どんな女性,タイプ,好きなタイプ
68|age_preference|question|relationships,dating,preferences|年上,年下,どっち,好き
69|likes_japanese_women|question|relationships,dating,japanese|日本人女性,日本の女性,好き
70|relationship_history_japanese_partner|question|relationships,dating,history|日本人,彼女,付き合ったこと
71|ask_dated_foreigner|question|relationships,dating,history|外国人,付き合ったこと
72|ask_long_distance|question|relationships,dating|遠距離,恋愛,できる
73|ask_want_marriage|question|relationships,marriage,future|結婚,したい
74|wants_children|question|relationships,family,future|子ども,欲しい
75|foreigner_assertive_stereotype|question|dating,stereotype|外国人,積極的
76|tease_pickup|tease|dating,teasing|ナンパ,する
77|ask_are_popular|question|dating,teasing|モテる,モテます
78|tease_popular|tease|dating,teasing|日本人,モテそう
79|foreigner_popularity_comment|sharedInformation|dating,foreigners|外国人好き,女の子,多い
80|wants_date_foreigner|sharedInformation|dating,foreigners|外国人,付き合ってみたい
81|compliment_height|compliment|compliments,height|背,高い
82|compliment_eyes|compliment|compliments,eyes|目,目の色,綺麗,きれい
83|compliment_nose|compliment|compliments,appearance|鼻,高い
84|compliment_face_size|compliment|compliments,appearance|顔,小さい
85|compliment_cool|compliment|compliments,appearance|かっこいい,格好いい
86|tease_past_popular|tease|dating,teasing|若い頃,モテた,過去
87|ask_personality|question|personal,personality|どんな性格,性格,どんな人
88|shy_personality|question|personal,personality|人見知り,する
89|compliment_outgoing|compliment|compliments,personality|明るい,元気
90|sociable_with_everyone|question|personal,personality|誰とでも,話せる
91|frequent_this_shop|question|location,venue|この店,よく来る
92|alone_today|question|availability,companions|今日,一人
93|waiting_for_friend|question|availability,companions|友達,待ってる
94|plans_after_this|question|availability,plans|このあと,どうする,予定
95|ask_tomorrow_work|question|work,availability|明日,仕事
96|how_late_staying|question|availability,drinks|何時まで,いつまで,飲む,いる
97|uses_line|question|social_media,contact|LINE,ライン,やってる
98|uses_instagram|question|social_media,contact|インスタ,Instagram,やってる
99|next_time_here|question|availability,future,location|今度,いつ,この辺,来る
100|invite_drink_again|invitation|invitation,drinks|また,飲みましょう,飲もう
101|invite_food|invitation|invitation,food|今度,ご飯,行かない
102|invite_go_next_time|invitation|invitation,future|今度,行きましょう,行こう
103|ask_food|question|food,preferences|どんな食べ物,好き,何食べる
104|ask_sweets|question|food,sweets|甘いもの,好き,甘党
105|pet_preference|question|hobbies,pets,preferences|犬派,猫派,どっち
106|sea_or_mountain|question|hobbies,travel,preferences|海,山,どっち
107|indoor_outdoor|question|hobbies,preferences|インドア,アウトドア,どっち
108|preferred_date|question|relationships,dating,preferences|どんなデート,好き
109|ideal_date|question|relationships,dating,preferences|理想,デート
110|attentive_partner|question|relationships,dating|付き合ったら,マメ
111|jealousy|question|relationships,dating|嫉妬,する
112|contact_frequency|question|relationships,contact|連絡,毎日,タイプ
113|phone_calls|question|relationships,contact|電話,好き
114|affectionate_style|question|relationships,dating|甘える,タイプ
115|physical_affection|question|relationships,dating|スキンシップ,多い
116|marriage_japanese_partner|question|relationships,marriage,japanese|日本人,結婚,可能性
117|future_residence|question|future,living|将来,どこ,住みたい
118|return_to_america|question|future,america|アメリカ,帰る,予定
119|opinion_japanese_women|question|japanese,relationships|日本の女性,どう
120|opinion_japanese_people|question|japanese,culture|日本人,どう思う
121|dislikes_japan|question|japanese,culture|日本,嫌いなところ
122|america_better|question|america,japanese,culture|アメリカ,ほうがいい,日本
123|surprise_in_japan|question|japanese,culture|日本,驚いたこと
124|culture_shock_japan|question|japanese,culture|日本,カルチャーショック,一番
125|continue_then|interest|continuation,interest|それで,続き
126|continue_why|interest|continuation,interest|なんで,どうして
127|continue_example|interest|continuation,interest|例えば,例
128|continue_curious|interest|continuation,interest|気になる,それ
129|continue_more|interest|continuation,interest|もっと,聞きたい
"""


EXTRA_EXAMPLES = {
    "ask_origin": ["どこの国ですか", "出身どこですか", "どちらのご出身ですか", "どこ出身", "お国はどこですか"],
    "origin_region": ["アメリカのどこですか", "アメリカのどの辺ですか", "何州の出身ですか", "アメリカのどちら"],
    "time_in_japan": ["日本に来てどのくらいですか", "日本に来て何年ですか", "日本何年目ですか", "いつから日本にいるんですか", "こっち長いんですか", "日本長い", "いつから日本いるの"],
    "ask_reason_japan": ["なんで日本に来たんですか", "なんで日本に来たの", "日本に来たきっかけは", "どうして日本に住もうと思ったんですか", "なぜ日本に来たの"],
    "compliment_japanese": ["日本語上手ですね", "日本語うまいね", "日本語ペラペラですね"],
    "japanese_study_method": ["どこで日本語勉強したんですか", "日本語どうやって覚えたの", "日本語は独学ですか", "日本語どこで習った"],
    "likes_japanese_food": ["日本食好きですか", "和食好き", "日本の食べ物好きですか"],
    "favorite_japanese_food": ["何の日本食が好き", "日本食で何が一番好き", "好きな和食は何"],
    "can_eat_natto": ["納豆食べられますか", "納豆食べれる", "納豆大丈夫", "納豆いける"],
    "can_eat_sashimi": ["刺身食べられますか", "刺身大丈夫", "生魚食べれる"],
    "can_use_chopsticks": ["箸使えますか", "箸使える", "お箸使える", "箸持てる"],
    "ask_job": ["何の仕事してるんですか", "何の仕事してるの", "仕事何してるの", "どんな仕事してますか", "職業は何ですか"],
    "english_teacher_assumption": ["英語の先生ですか", "英語教師ですか", "英会話の先生"],
    "ask_hobbies": ["趣味は何ですか", "趣味何", "何するのが好き", "普段何して遊ぶの"],
    "days_off": ["休みの日何してる", "休日はどう過ごす", "休みの日は何してるんですか"],
    "relationship_status": ["彼女いますか", "彼女いる", "今彼女いる", "彼女とかいるんですか", "付き合ってる人いる", "恋人いる", "恋人いるの"],
    "single_status": ["独身ですか", "今フリー", "シングルですか", "今誰とも付き合ってない"],
    "ask_married": ["結婚してますか", "既婚ですか", "結婚してるの"],
    "ask_type": ["どんな女性がタイプ", "好きなタイプは", "どんな人が好き"],
    "age_preference": ["年上と年下どっちが好き", "年上派年下派", "年上と年下どっち"],
    "living_alone": ["一人暮らし", "誰かと住んでる", "一人で住んでるんですか"],
    "ask_residence": ["どこに住んでるの", "どの辺に住んでますか", "家どこ"],
    "plans_after_this": ["このあとどうするんですか", "このあと予定ある", "このあと何する", "これからどうするの"],
    "how_late_staying": ["何時までいるの", "何時まで飲むんですか", "いつまでいる", "今日は何時まで"],
    "next_time_here": ["次いつ来る", "今度いつこの辺来ますか", "またこの辺来る"],
}


EXCLUSIONS = {
    "relationship_status": ["日本人の彼女", "昔", "いたこと"],
    "single_status": ["一人暮らし", "一人ですか"],
    "ask_residence": ["将来", "誰と"],
    "living_alone": ["今日は一人", "家族"],
    "ask_job": ["明日", "忙しい", "楽しい", "日本語"],
    "time_in_japan": ["どうして", "なんで", "きっかけ", "将来"],
    "ask_reason_japan": ["どのくらい", "何年目", "いつから"],
    "likes_japanese_food": ["何が一番", "何の日本食"],
    "favorite_japanese_food": ["日本食好きですか"],
    "plans_after_this": ["何時まで"],
    "how_late_staying": ["このあと何する", "予定ある"],
    "compliment_japanese": ["どこで", "どうやって", "勉強"],
    "japanese_study_method": ["上手", "ペラペラ"],
}


OMIT_LABELS = {"Then", "Weak response"}


UNIVERSAL_RESPONSES = [
    ("How about you?", "〇〇さんは？", ["safe", "friendly"], "ask_back"),
    ("What about you?", "逆にどうですか？", ["safe", "friendly"], "ask_back"),
    ("I was about to ask you the same thing.", "僕も聞こうと思ってました。", ["friendly", "playful"], "ask_back"),
    ("Why were you curious about that?", "なんでそれ気になったんですか？（笑）", ["playful", "teasing"], "interest_probe"),
    ("That suddenly got deep.", "急に深い質問来ましたね（笑）", ["playful", "witty"], "playful_question_reversal"),
    ("Is this an interview?", "これは面接ですか？（笑）", ["playful", "humorous"], "playful_question_reversal"),
    ("Is there a correct answer?", "正解あります？（笑）", ["playful", "humorous"], "playful_question_reversal"),
    ("Are you grading my answer?", "この答え、採点されます？（笑）", ["playful", "humorous"], "playful_question_reversal"),
    ("You're easy to talk to.", "話しやすいですね。", ["safe", "friendly"], "conversation_hook"),
    ("You're pretty interesting.", "〇〇さん結構面白いですね。", ["friendly", "playful"], "conversation_hook"),
    ("We've ended up talking longer than I expected.", "思ったより話し込んじゃいましたね（笑）", ["friendly", "playful"], "conversation_hook"),
    ("I don't talk this much with everyone.", "誰とでもこんなに話すわけじゃないですよ。", ["friendly", "flirty"], "conversation_hook"),
    ("I'm glad we started talking today.", "今日話しかけてよかったです。", ["friendly"], "conversation_hook"),
    ("We should go there together sometime.", "それ、今度一緒に行きましょうよ。", ["friendly", "flirty"], "future_hook"),
    ("If you recommend it, you'll have to take me.", "おすすめなら連れてってください（笑）", ["playful", "flirty"], "future_hook"),
    ("Tell me next time we meet.", "じゃあ次会った時に教えてください。", ["friendly", "flirty"], "future_hook"),
    ("I'd like to hear the rest over dinner sometime.", "その話の続き、今度ご飯でも食べながら聞きたいです。", ["flirty", "confident"], "future_hook"),
    ("Want to exchange LINE?", "LINE交換しときます？", ["direct", "confident"], "contact_hook"),
]


def _specs():
    out = {}
    for raw in _SPEC_TEXT.strip().splitlines():
        number, intent_id, function, tags, keywords = raw.split("|", 4)
        out[int(number)] = {
            "id": intent_id,
            "function": function,
            "contextTags": tags.split(","),
            "keywords": keywords.split(","),
        }
    return out


def _clean_question(raw):
    value = raw.strip()
    if value.startswith("「") and value.endswith("」"):
        value = value[1:-1]
    return value.strip()


def _variants(question):
    value = question.rstrip("？?。 ")
    variants = [question, value]
    if value.endswith("んですか"):
        variants.append(value[:-4] + "の")
    if value.endswith("ですか"):
        variants.append(value[:-3])
    if value.endswith("ますか"):
        variants.append(value[:-1])
    if value.endswith("ですね"):
        variants.append(value[:-3] + "だね")
    return variants


def _response_style(label):
    low = label.lower()
    if any(term in low for term in ("flirtier", "stronger", "dangerous")):
        return ["flirty", "confident", "teasing"], "flirty"
    if any(term in low for term in ("flirty", "reciprocal")):
        return ["flirty", "playful"], "flirty"
    if any(term in low for term in ("humorous", "fun")):
        return ["humorous", "witty", "playful"], "light"
    if any(term in low for term in ("playful", "creative")):
        return ["playful", "witty"], "light"
    if any(term in low for term in ("confident", "direct")):
        return ["confident", "direct"], "flirty"
    if any(term in low for term in ("conversation hook", "interesting")):
        return ["friendly", "situational"], "light"
    return ["safe", "friendly"], "light"


def _english_after(segment, match_end):
    for line in segment[match_end:].splitlines():
        value = line.strip()
        if not value or value.startswith(("*", "---", "#")):
            continue
        return value if re.search(r"[A-Za-z]", value) else None
    return None


def _section_responses(body):
    results = []
    labels = list(re.finditer(r"^\*\*([^*\r\n]+?):\*\*\s*$", body, re.M))
    for index, label_match in enumerate(labels):
        label = label_match.group(1).strip()
        if label in OMIT_LABELS:
            continue
        stop = labels[index + 1].start() if index + 1 < len(labels) else len(body)
        segment = body[label_match.end():stop]
        japanese = re.search(r"^「(.+?)」\s*$", segment, re.M)
        if japanese is None:
            continue
        results.append({
            "label": label,
            "japaneseText": japanese.group(1).strip(),
            "englishMeaning": _english_after(segment, japanese.end()),
        })
    if results:
        return results
    for japanese in re.finditer(r"^「(.+?)」\s*$", body, re.M):
        results.append({
            "label": "Playful",
            "japaneseText": japanese.group(1).strip(),
            "englishMeaning": _english_after(body, japanese.end()),
        })
    return results


def _stable_line_id(japanese):
    digest = hashlib.sha1(japanese.encode("utf-8")).hexdigest()[:12]
    return f"first-meeting-{digest}"


def _future_interest_signal_ideas(text):
    start = text.find("# Interest-Signal")
    end = text.find("# Useful Universal Responses", start)
    if start < 0 or end < 0:
        return {}
    section = text[start:end]
    clusters = {}
    headings = list(re.finditer(r"^###\s+([^\r\n]+)$", section, re.M))
    for index, heading in enumerate(headings):
        stop = headings[index + 1].start() if index + 1 < len(headings) \
            else len(section)
        body = section[heading.end():stop]
        clusters[heading.group(1).strip()] = [
            match.group(1).strip()
            for match in re.finditer(r"^\*\s+(.+?)\s*$", body, re.M)
        ]
    return {
        "implemented": False,
        "note": "Source ideas retained for future cluster scoring only.",
        "interestSignalClusters": clusters,
    }


def parse_markdown(text):
    specs = _specs()
    headings = list(re.finditer(r"^###\s+(\d+)\.\s+([^\r\n]+?)\s*$", text, re.M))
    numbered = [match for match in headings if int(match.group(1)) <= 129]
    if len(numbered) != 129:
        raise SystemExit(f"Expected 129 numbered questions, found {len(numbered)}")

    intents_by_id = {}
    responses_by_text = {}
    omitted = []
    duplicate_response_count = 0
    for index, heading in enumerate(numbered):
        number = int(heading.group(1))
        spec = specs[number]
        end = numbered[index + 1].start() if index + 1 < len(numbered) else len(text)
        if number == 129:
            interest_section = text.find("\n# Interest-Signal", heading.end())
            if interest_section >= 0:
                end = interest_section
        body = text[heading.end():end]
        question = _clean_question(heading.group(2))
        intent_id = spec["id"]
        examples = _variants(question) + EXTRA_EXAMPLES.get(intent_id, [])
        hints = [intent_id, *spec["contextTags"]]
        if spec["function"] == "question":
            hints.extend(["statement", "comeback", "ask_back", "conversation_hook"])
        if "dating" in spec["contextTags"]:
            hints.extend(["interest_probe", "playful_question_reversal"])
        intent = intents_by_id.setdefault(intent_id, {
            "id": intent_id,
            "description": f"Responds to the first-meeting utterance: {question}",
            "examples": [],
            "keywords": [],
            "exclusions": [],
            "function": spec["function"],
            "contextTags": [],
            "responseHints": [],
            "priority": 90 if "dating" in spec["contextTags"] else 82,
            "confidenceThreshold": 0.58,
            "sourceQuestions": [],
        })
        for key, values in (
            ("examples", examples),
            ("keywords", spec["keywords"]),
            ("exclusions", EXCLUSIONS.get(intent_id, [])),
            ("contextTags", spec["contextTags"]),
            ("responseHints", hints),
            ("sourceQuestions", [number]),
        ):
            for value in values:
                if value not in intent[key]:
                    intent[key].append(value)

        section_responses = _section_responses(body)
        if not section_responses:
            omitted.append({"question": number, "reason": "no usable response"})
        for response in section_responses:
            tones, boldness = _response_style(response["label"])
            japanese = response["japaneseText"]
            line = responses_by_text.get(japanese)
            if line is None:
                line = {
                    "id": _stable_line_id(japanese),
                    "japaneseText": japanese,
                    "englishMeaning": response["englishMeaning"],
                    "category": "comebacks",
                    "tones": tones,
                    "directness": 3 if boldness == "flirty" else 2,
                    "boldness": boldness,
                    "usageType": "statement" if response["label"].lower() in {
                        "standard", "normal", "good", "thoughtful", "balanced",
                        "actual", "actual answer", "safe / smooth", "if yes", "if no",
                    } else "comeback",
                    "topics": [],
                    "manualOnly": True,
                    "tts": {"jp": True, "ko": False},
                    "notes": f"First-meeting source question {number}; style: {response['label']}",
                }
                responses_by_text[japanese] = line
            else:
                duplicate_response_count += 1
                if (line.get("englishMeaning") is None and
                        response["englishMeaning"]):
                    line["englishMeaning"] = response["englishMeaning"]
            for topic in [intent_id, *spec["contextTags"]]:
                if topic not in line["topics"]:
                    line["topics"].append(topic)
            for tone in tones:
                if tone not in line["tones"]:
                    line["tones"].append(tone)

    for english, japanese, tones, topic in UNIVERSAL_RESPONSES:
        responses_by_text.setdefault(japanese, {
            "id": _stable_line_id(japanese),
            "japaneseText": japanese,
            "englishMeaning": english,
            "category": "comebacks",
            "tones": tones,
            "directness": 2,
            "boldness": "flirty" if "flirty" in tones or "direct" in tones else "light",
            "usageType": "comeback",
            "topics": [topic],
            "manualOnly": True,
            "tts": {"jp": True, "ko": False},
            "notes": "Reusable first-meeting response",
        })

    return {
        "schemaVersion": 2,
        "app": "OpenCue",
        "kind": "firstMeetingIntentResponseLibrary",
        "sourceQuestionCount": 129,
        "futureScoringIdeas": _future_interest_signal_ideas(text),
        "importStats": {
            "duplicateResponsesMerged": duplicate_response_count,
            "deliberatelyOmittedLabels": {
                label: len(re.findall(
                    rf"^\*\*{re.escape(label)}:\*\*\s*$", text, re.M))
                for label in sorted(OMIT_LABELS)
            },
        },
        "intents": list(intents_by_id.values()),
        "lines": list(responses_by_text.values()),
        "omitted": omitted,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("markdown", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    payload = parse_markdown(args.markdown.read_text(encoding="utf-8"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"First-meeting library: {len(payload['intents'])} unique intents, "
        f"{len(payload['lines'])} unique responses, "
        f"{len(payload['omitted'])} question(s) without responses."
    )


if __name__ == "__main__":
    main()
