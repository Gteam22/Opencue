#!/usr/bin/env python3
"""Builds the starter library.

Source material: LGData.txt, edited down. Lines that were backhanded,
presumptuous about what the other person thinks, or that pressed someone to
leave their friends were dropped rather than tagged, because no amount of
tagging makes them appropriate. See tool/README.md.

Outputs:
  assets/sample/starter_library.json   (readable reference copy)
  lib/data/seed/starter_library.dart   (embedded, parsed at first launch)

Run:  python3 tool/build_seed.py
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LINES = []


def L(cat, num, ja, en, *, locs, cues=(), groups=(), noise=("quiet", "normal"),
      tones=("friendly",), direct=2, conds=(), avoids=(), acts=(),
      follow=None, notes=None):
    """Registers one starter line."""
    LINES.append({
        "id": "seed-%s-%02d" % (cat_slug(cat), num),
        "japaneseText": ja,
        "englishMeaning": en,
        "category": cat,
        "locations": list(locs),
        "activities": list(acts),
        "observableCues": list(cues),
        "groupSizes": list(groups),
        "noiseLevels": list(noise),
        "tones": list(tones),
        "directness": direct,
        "conditions": list(conds),
        "avoidConditions": list(avoids),
        "followUpSuggestion": follow,
        "notes": notes,
        "isFavorite": False,
        "isUserCreated": False,
        "timesShown": 0,
        "timesUsed": 0,
        "positiveResults": 0,
        "neutralResults": 0,
        "negativeResults": 0,
    })


def cat_slug(cat):
    return re.sub(r'(?<!^)(?=[A-Z])', '-', cat).lower()


# Shared shorthand.
DAY = ("street", "shoppingArea")
SOLO_OR_PAIR = ("alone", "withOneFriend")
BASIC_AVOID = ("personOccupied", "headphonesOn", "movingQuickly")

# ---------------------------------------------------------------------------
# Universal situational comments
# ---------------------------------------------------------------------------
C = "universal"
L(C, 1, "その〇〇、すごく似合ってますね。",
  "That ___ really suits you.",
  locs=("street", "shoppingArea", "cafe", "bar", "party", "meetup"),
  cues=("distinctiveOutfit",), groups=SOLO_OR_PAIR, tones=("safe", "friendly"),
  direct=2, avoids=BASIC_AVOID,
  follow="Ask where she found it, then let the topic move on naturally.",
  notes="Replace 〇〇 with the actual item: clothing, an accessory, "
        "a hairstyle. The specificity is the whole point.")
L(C, 2, "すごくいい雰囲気ですね。", "You have a really nice vibe.",
  locs=("bar", "standingBar", "party", "festival", "meetup"),
  groups=SOLO_OR_PAIR, noise=("normal", "loud"),
  tones=("friendly", "situational"), direct=2, avoids=BASIC_AVOID,
  notes="Works in social spaces where strangers already talk to each other.")
L(C, 3, "おしゃれですね。思わず声かけちゃいました。",
  "You're stylish, so I ended up saying hello.",
  locs=("street", "shoppingArea", "cafe", "bookstore"),
  cues=("distinctiveOutfit",), groups=SOLO_OR_PAIR, tones=("friendly",),
  direct=3, conds=("personIsNotRushing",), avoids=BASIC_AVOID,
  notes="Says plainly why you approached, which is easier to answer than a "
        "line that hides its intent.")
L(C, 4, "なんか楽しそうですね。", "You look like you're having fun.",
  locs=("bar", "standingBar", "festival", "party", "club"),
  cues=("groupHavingFun",), groups=("withOneFriend", "smallGroup"),
  noise=("normal", "loud"), tones=("friendly", "situational"), direct=1,
  avoids=BASIC_AVOID)
L(C, 5, "なんか話しやすそうな雰囲気ですね。", "You seem easy to talk to.",
  locs=("bar", "standingBar", "meetup", "languageExchange", "party"),
  groups=SOLO_OR_PAIR, noise=("normal", "loud"), tones=("friendly",),
  direct=2, avoids=BASIC_AVOID)
L(C, 6, "ちょっと緊張してますけど、話しかけてみました。",
  "I'm a little nervous, but I wanted to say hello.",
  locs=("street", "shoppingArea", "cafe", "bookstore", "meetup"),
  groups=("alone",), tones=("safe", "friendly"), direct=3,
  avoids=BASIC_AVOID,
  notes="Honesty instead of performed confidence. Low pressure because it "
        "admits the awkwardness rather than papering over it.")
L(C, 7, "こんにちは。なんか気になったので、挨拶だけでもと思って。",
  "Hi. You caught my attention, so I wanted to at least say hello.",
  locs=("street", "shoppingArea", "park", "bookstore"),
  groups=("alone",), tones=("friendly", "direct"), direct=3,
  conds=("personIsNotRushing", "busyPublicSetting"), avoids=BASIC_AVOID,
  follow="If the answer is short, thank her and leave it there.",
  notes="Frames the whole thing as a greeting, not a request, so there is "
        "nothing she has to decline.")
L(C, 8, "一度話してみたい雰囲気だなと思いました。",
  "You seemed like someone I'd like to talk to.",
  locs=("meetup", "party", "bar", "cafe", "languageExchange"),
  groups=SOLO_OR_PAIR, tones=("friendly", "direct"), direct=3,
  avoids=BASIC_AVOID)
L(C, 9, "すごく自然に目に入りました。", "You naturally caught my attention.",
  locs=("street", "shoppingArea", "cafe", "bar"), groups=SOLO_OR_PAIR,
  tones=("friendly",), direct=3, avoids=BASIC_AVOID)
L(C, 10, "今日ここに来てよかったです。", "I'm glad I came here today.",
  locs=("bar", "festival", "party", "meetup", "concert"),
  noise=("normal", "loud"), tones=("friendly", "situational"), direct=2,
  conds=("conversationStarted",),
  notes="A warm mid-conversation remark rather than an opener.")

# ---------------------------------------------------------------------------
# Eye contact already established
# ---------------------------------------------------------------------------
C = "eyeContactEstablished"
L(C, 1, "今、目合いましたよね？笑", "We just made eye contact, didn't we?",
  locs=("bar", "standingBar", "party", "cafe", "club"),
  cues=("eyeContact",), groups=SOLO_OR_PAIR, noise=("normal", "loud"),
  tones=("playful", "friendly"), direct=3,
  conds=("eyeContactEstablished",), avoids=BASIC_AVOID,
  notes="Only when it clearly happened more than once. Otherwise it sounds "
        "like an accusation.")
L(C, 2, "さっきから何回か目が合ってる気がします。",
  "I think we've caught each other's eye a few times.",
  locs=("bar", "standingBar", "party", "concert", "meetup"),
  cues=("eyeContact",), groups=SOLO_OR_PAIR, noise=("normal", "loud"),
  tones=("friendly",), direct=3, conds=("eyeContactEstablished",),
  avoids=BASIC_AVOID)
L(C, 3, "目が合ったので、挨拶しようかなと思って。",
  "We caught each other's eye, so I thought I'd say hello.",
  locs=("bar", "cafe", "party", "bookstore", "meetup"),
  cues=("eyeContact",), groups=SOLO_OR_PAIR, tones=("safe", "friendly"),
  direct=2, conds=("eyeContactEstablished",), avoids=BASIC_AVOID)
L(C, 4, "笑ってくれたから、話しかけても大丈夫かなと思いました。",
  "You smiled, so I thought it might be all right to say hello.",
  locs=("bar", "cafe", "party", "festival", "meetup"),
  cues=("eyeContact", "smile"), groups=SOLO_OR_PAIR,
  noise=("quiet", "normal", "loud"), tones=("friendly",), direct=3,
  conds=("eyeContactEstablished",), avoids=BASIC_AVOID,
  notes="Needs an actual smile directed at you, not a general good mood.")
L(C, 5, "その笑顔で、話しかける勇気が出ました。",
  "Your smile gave me the courage to come over.",
  locs=("bar", "standingBar", "festival", "party"),
  cues=("smile", "eyeContact"), groups=SOLO_OR_PAIR,
  noise=("normal", "loud"), tones=("friendly", "flirty"), direct=4,
  conds=("eyeContactEstablished",), avoids=BASIC_AVOID)
L(C, 6, "さっき目が合ったとき、話しかけようか迷ってました。",
  "When we caught each other's eye earlier, I was debating whether to say "
  "something.",
  locs=("cafe", "bar", "bookstore", "concert", "meetup"),
  cues=("eyeContact",), groups=("alone",), tones=("friendly", "direct"),
  direct=3, conds=("eyeContactEstablished",), avoids=BASIC_AVOID)

# ---------------------------------------------------------------------------
# Café
# ---------------------------------------------------------------------------
C = "cafe"
L(C, 1, "それ、美味しそうですね。", "That looks good.",
  locs=("cafe", "restaurant"), cues=("drink", "food"), groups=SOLO_OR_PAIR,
  acts=("eating", "drinking"), tones=("safe", "situational"), direct=1,
  avoids=BASIC_AVOID,
  follow="Ask what it is, then order it yourself if the reply is warm.")
L(C, 2, "そのメニュー、僕も迷ってました。",
  "I was torn over that item on the menu too.",
  locs=("cafe", "restaurant"), cues=("food", "drink"), groups=SOLO_OR_PAIR,
  acts=("waiting",), tones=("safe", "situational"), direct=1,
  avoids=BASIC_AVOID, notes="Best while queueing or ordering nearby.")
L(C, 3, "ここ、雰囲気いいですよね。", "This place has a nice atmosphere.",
  locs=("cafe", "restaurant", "bar"), groups=SOLO_OR_PAIR,
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID,
  notes="For shared counters or communal tables. A café is not automatically "
        "a social space.")
L(C, 4, "この店、初めてなんですけど当たりですね。",
  "It's my first time here, and it was a good call.",
  locs=("cafe", "restaurant", "bar"), groups=SOLO_OR_PAIR,
  tones=("friendly", "situational"), direct=2, avoids=BASIC_AVOID)
L(C, 5, "その飲み物、見た目すごいですね。",
  "That drink looks spectacular.",
  locs=("cafe",), cues=("drink",), groups=SOLO_OR_PAIR, acts=("drinking",),
  tones=("friendly", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 6, "そのステッカー、〇〇ですよね。",
  "That sticker is ___, isn't it?",
  locs=("cafe", "bookstore"), cues=("characterMerchandise",),
  groups=("alone",), tones=("friendly",), direct=2,
  conds=("genuineKnowledgeOfSubject",), avoids=BASIC_AVOID,
  follow="Shared interest is the easiest thing in the world to keep talking "
         "about. Ask how she got into it.",
  notes="Only if you actually recognise it. Guessing wrong is worse than "
        "saying nothing.")
L(C, 7, "僕もそれ頼めばよかったです。", "I should have ordered that.",
  locs=("cafe", "restaurant"), cues=("drink", "food"), groups=SOLO_OR_PAIR,
  tones=("playful", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 8, "今日、カフェ日和ですね。", "Perfect weather for sitting in a café.",
  locs=("cafe",), cues=("weather",), groups=SOLO_OR_PAIR,
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID,
  notes="For a terrace or patio on a good day.")

# ---------------------------------------------------------------------------
# Bar
# ---------------------------------------------------------------------------
C = "bar"
L(C, 1, "それ、何飲んでるんですか？美味しそうですね。",
  "What are you drinking? It looks good.",
  locs=("bar", "standingBar", "club"), cues=("drink",), groups=SOLO_OR_PAIR,
  noise=("normal", "loud"), acts=("drinking",),
  tones=("safe", "friendly"), direct=2,
  follow="Order the same thing, or ask what else they recommend here.")
L(C, 2, "今日ここ、いい雰囲気ですね。", "Good atmosphere here tonight.",
  locs=("bar", "standingBar", "club"), noise=("normal", "loud"),
  tones=("safe", "situational"), direct=1)
L(C, 3, "ここ、初めてですけど当たりですね。",
  "First time here, and it turned out well.",
  locs=("bar", "standingBar"), noise=("normal", "loud"),
  tones=("friendly", "situational"), direct=2)
L(C, 4, "そのお酒選ぶの、センスいいですね。",
  "That's a good choice of drink.",
  locs=("bar", "standingBar"), cues=("drink",), groups=SOLO_OR_PAIR,
  noise=("normal", "loud"), tones=("friendly",), direct=2)
L(C, 5, "ここのおすすめ、詳しそうですね。",
  "You look like you know what's good here.",
  locs=("bar", "standingBar"), groups=SOLO_OR_PAIR, noise=("normal", "loud"),
  tones=("friendly", "playful"), direct=2,
  follow="Let her recommend something and then actually order it.")
L(C, 6, "なんか一番話しやすそうだったので来ました。",
  "You seemed like the easiest person here to talk to.",
  locs=("bar", "standingBar", "party"), groups=SOLO_OR_PAIR,
  noise=("normal", "loud"), tones=("friendly", "direct"), direct=3)
L(C, 7, "まずは乾杯だけしてもいいですか？",
  "Could we just have a toast first?",
  locs=("bar", "standingBar", "club", "party"), cues=("drink",),
  noise=("normal", "loud", "veryLoud"), tones=("playful", "friendly"),
  direct=3, notes="Needs both of you to already be holding a drink.")
L(C, 8, "一人で飲んでる仲間を発見しました。",
  "I've found a fellow solo drinker.",
  locs=("bar", "standingBar"), groups=("alone",), noise=("normal", "loud"),
  tones=("playful", "friendly"), direct=3,
  avoids=("companionsPresent",))
L(C, 9, "ここ、一人でも入りやすくていいですよね。",
  "It's nice that this place is easy to come to on your own.",
  locs=("bar", "standingBar"), groups=("alone",), noise=("normal", "loud"),
  tones=("safe", "situational"), direct=1, avoids=("companionsPresent",))
L(C, 10, "今日は軽く一杯のつもりだったんですけど、楽しくなりそうです。",
  "I only came for one drink, but this is turning into a good evening.",
  locs=("bar", "standingBar", "party"), noise=("normal", "loud"),
  tones=("friendly", "flirty"), direct=3, conds=("conversationStarted",))

# ---------------------------------------------------------------------------
# Standing bar
# ---------------------------------------------------------------------------
C = "standingBar"
L(C, 1, "その注文、常連感ありますね。",
  "That order has real regular-customer energy.",
  locs=("standingBar", "bar"), cues=("drink",), groups=SOLO_OR_PAIR,
  noise=("normal", "loud"), tones=("playful",), direct=2,
  notes="Needs a genuinely specific, confident order.")
L(C, 2, "その乾杯に混ざりたいくらい楽しそうですね。",
  "You all look like you're having such a good time I want to join the toast.",
  locs=("standingBar", "bar", "party"), cues=("groupHavingFun", "drink"),
  groups=("smallGroup", "largeGroup"), noise=("normal", "loud"),
  tones=("playful", "friendly"), direct=3)
L(C, 3, "その笑い声につられて来ました。",
  "Your laughter drew me over.",
  locs=("standingBar", "bar", "party"), cues=("groupHavingFun",),
  groups=("withOneFriend", "smallGroup"), noise=("normal", "loud"),
  tones=("playful", "friendly"), direct=3)
L(C, 4, "その席、一番楽しそうですね。",
  "That looks like the best seat in the place.",
  locs=("standingBar", "bar", "party"), cues=("groupHavingFun",),
  groups=("smallGroup", "largeGroup"), noise=("normal", "loud"),
  tones=("friendly", "playful"), direct=2)

# ---------------------------------------------------------------------------
# Club
# ---------------------------------------------------------------------------
C = "club"
L(C, 1, "その曲、最高ですね！", "This track is great!",
  locs=("club", "concert"), cues=("music",), noise=("loud", "veryLoud"),
  tones=("friendly", "situational"), direct=1, acts=("dancing",),
  notes="Short by design. In a loud room a long sentence is just noise.")
L(C, 2, "めっちゃいいノリですね！", "You've got great rhythm!",
  locs=("club",), cues=("sharedActivity",), noise=("loud", "veryLoud"),
  tones=("friendly", "playful"), direct=2, acts=("dancing",))
L(C, 3, "今日一番楽しんでますね！",
  "You're having the best time here tonight!",
  locs=("club", "festival", "concert"), cues=("groupHavingFun",),
  noise=("loud", "veryLoud"), tones=("friendly", "playful"), direct=2)
L(C, 4, "いい笑顔ですね！", "Great smile!",
  locs=("club", "festival", "concert"), cues=("smile", "eyeContact"),
  noise=("loud", "veryLoud"), tones=("friendly", "flirty"), direct=3,
  conds=("eyeContactEstablished",))
L(C, 5, "一瞬だけ乾杯しません？", "Quick toast?",
  locs=("club", "bar", "standingBar"), cues=("drink",),
  noise=("loud", "veryLoud"), tones=("playful",), direct=3)
L(C, 6, "僕より全然踊れてますね！",
  "You dance far better than I do!",
  locs=("club",), cues=("sharedActivity",), noise=("loud", "veryLoud"),
  tones=("playful", "friendly"), direct=2, acts=("dancing",),
  notes="Self-deprecating, which keeps it light.")
L(C, 7, "今日来て正解でしたね！", "Coming out tonight was the right call!",
  locs=("club", "concert", "festival"), cues=("music", "groupHavingFun"),
  noise=("loud", "veryLoud"), tones=("friendly", "situational"), direct=1)
L(C, 8, "名前だけ聞いてもいいですか？", "Could I just get your name?",
  locs=("club", "concert"), noise=("loud", "veryLoud"),
  tones=("direct", "friendly"), direct=4, conds=("conversationStarted",),
  notes="Only once you are already talking and the noise makes anything "
        "longer impossible.")

# ---------------------------------------------------------------------------
# Street or shopping area
# ---------------------------------------------------------------------------
C = "streetOrShopping"
L(C, 1, "すみません、そのコーデすごく素敵ですね。",
  "Excuse me, that outfit is really great.",
  locs=DAY, cues=("distinctiveOutfit",), groups=SOLO_OR_PAIR,
  tones=("friendly",), direct=3,
  conds=("personIsNotRushing", "busyPublicSetting"), avoids=BASIC_AVOID,
  notes="Approach from the front or side, leave several feet of space, and "
        "stop the moment she keeps walking. Never follow.")
L(C, 2, "そのバッグ、すごくセンスいいですね。",
  "That bag shows real taste.",
  locs=DAY, cues=("distinctiveOutfit",), groups=SOLO_OR_PAIR,
  tones=("safe", "friendly"), direct=2, conds=("personIsNotRushing",),
  avoids=BASIC_AVOID)
L(C, 3, "髪色すごくきれいですね。",
  "Your hair colour is beautiful.",
  locs=DAY + ("cafe",), cues=("hairstyle",), groups=SOLO_OR_PAIR,
  tones=("friendly",), direct=3, conds=("personIsNotRushing",),
  avoids=BASIC_AVOID)
L(C, 4, "そのネイル、かなり凝ってますね。",
  "Your nails are really intricate.",
  locs=DAY + ("cafe", "bar"), cues=("nails",), groups=SOLO_OR_PAIR,
  tones=("friendly",), direct=2, avoids=BASIC_AVOID,
  follow="Ask whether she chose the design herself.")
L(C, 5, "そのキャラクター好きなんですか？僕も気になってました。",
  "Do you like that character? I've been curious about it too.",
  locs=DAY + ("bookstore", "cosplayEvent"), cues=("characterMerchandise",),
  groups=SOLO_OR_PAIR, tones=("friendly",), direct=2,
  conds=("genuineKnowledgeOfSubject",), avoids=BASIC_AVOID)
L(C, 6, "今日、この辺すごく人多いですね。",
  "It's really crowded around here today.",
  locs=DAY + ("trainStation", "festival"), cues=("waiting",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID,
  notes="The lowest-pressure opener there is. Costs nothing to ignore.")
L(C, 7, "そのお店、何か良さそうですね。",
  "That shop looks promising.",
  locs=DAY, groups=SOLO_OR_PAIR, acts=("browsing", "shopping"),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 8, "その傘、デザインかわいいですね。",
  "Your umbrella has a lovely design.",
  locs=DAY + ("trainStation",), cues=("weather",), groups=SOLO_OR_PAIR,
  tones=("safe", "friendly"), direct=2, avoids=BASIC_AVOID)
L(C, 9, "すみません、急いでなければ一言だけ。すごくおしゃれだと思いました。",
  "Sorry, just one thing if you're not in a hurry. I thought you looked "
  "really stylish.",
  locs=DAY, cues=("distinctiveOutfit",), groups=("alone",),
  tones=("direct", "friendly"), direct=4,
  conds=("personIsNotRushing", "busyPublicSetting"), avoids=BASIC_AVOID,
  notes="Builds her exit into the sentence, which is what makes a direct "
        "daytime approach reasonable.")
L(C, 10, "ナンパっぽく聞こえたら申し訳ないんですけど、すごく素敵ですね。",
  "Sorry if this sounds like a pick-up line, but you look wonderful.",
  locs=DAY, cues=("distinctiveOutfit",), groups=("alone",),
  tones=("direct",), direct=4,
  conds=("personIsNotRushing", "busyPublicSetting"), avoids=BASIC_AVOID,
  notes="Use sparingly. Naming the awkwardness works once, not repeatedly.")

# ---------------------------------------------------------------------------
# Convenience store, supermarket, market
# ---------------------------------------------------------------------------
C = "convenienceStore"
L(C, 1, "それ、美味しいですよね。", "That one's good, isn't it.",
  locs=("convenienceStore",), cues=("food",), acts=("shopping",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID,
  notes="Keep it to one exchange. Most people here are mid-errand.")
L(C, 2, "僕もいつもそれ買います。", "I always buy that too.",
  locs=("convenienceStore",), cues=("food",), acts=("shopping",),
  tones=("safe", "friendly"), direct=1, avoids=BASIC_AVOID)
L(C, 3, "その新商品、気になってました。",
  "I've been curious about that new one.",
  locs=("convenienceStore",), cues=("food",), acts=("shopping", "browsing"),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 4, "その組み合わせ、絶対美味しいやつですね。",
  "That combination is definitely a good one.",
  locs=("convenienceStore",), cues=("food",), acts=("shopping",),
  tones=("playful", "friendly"), direct=2, avoids=BASIC_AVOID)
L(C, 5, "僕も夕飯で完全に迷ってます。",
  "I'm completely stuck on what to have for dinner too.",
  locs=("convenienceStore",), cues=("food",), acts=("shopping",),
  tones=("friendly", "situational"), direct=1, avoids=BASIC_AVOID)

# ---------------------------------------------------------------------------
# Bookstore or record store
# ---------------------------------------------------------------------------
C = "bookstore"
L(C, 1, "その本、面白いですよ。", "That book is good.",
  locs=("bookstore",), cues=("book",), acts=("browsing", "reading"),
  tones=("safe", "friendly"), direct=1,
  conds=("genuineKnowledgeOfSubject",), avoids=BASIC_AVOID,
  notes="Only if you have actually read it.")
L(C, 2, "それ、僕も気になってました。", "I've been curious about that too.",
  locs=("bookstore",), cues=("book",), acts=("browsing",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID,
  notes="Best when you are both looking at the same thing.")
L(C, 3, "その作家、いいですよね。", "That author is great.",
  locs=("bookstore",), cues=("book",), acts=("browsing",),
  tones=("friendly",), direct=2, conds=("genuineKnowledgeOfSubject",),
  avoids=BASIC_AVOID)
L(C, 4, "同じ棚を見てるってことは、趣味が近いかもしれませんね。",
  "If we're looking at the same shelf, maybe our tastes are similar.",
  locs=("bookstore",), cues=("sharedActivity",), acts=("browsing",),
  tones=("friendly", "playful"), direct=2, avoids=BASIC_AVOID)
L(C, 5, "その作品好きなら、〇〇も合いそうですね。",
  "If you like that, ___ might suit you too.",
  locs=("bookstore",), cues=("book", "music"), acts=("browsing",),
  tones=("friendly",), direct=2, conds=("genuineKnowledgeOfSubject",),
  avoids=BASIC_AVOID,
  follow="A real recommendation gives an obvious reason to exchange contacts "
         "later.")
L(C, 6, "ここ来ると予定より長居しちゃいますね。",
  "I always end up staying here longer than I planned.",
  locs=("bookstore",), acts=("browsing",), tones=("safe", "situational"),
  direct=1, avoids=BASIC_AVOID)
L(C, 7, "そのジャンル好きな人と話してみたかったんです。",
  "I've been wanting to talk to someone who likes that genre.",
  locs=("bookstore",), cues=("book", "music"), acts=("browsing",),
  tones=("friendly", "direct"), direct=3,
  conds=("genuineKnowledgeOfSubject",), avoids=BASIC_AVOID)

# ---------------------------------------------------------------------------
# Park or waterfront
# ---------------------------------------------------------------------------
C = "parkOrWaterfront"
L(C, 1, "今日、外にいるのが気持ちいいですね。",
  "It feels good to be outside today.",
  locs=("park", "waterfront"), cues=("weather",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 2, "その犬、すごくかわいいですね。", "Your dog is lovely.",
  locs=("park", "waterfront", "street"), cues=("dog",), groups=SOLO_OR_PAIR,
  acts=("walking",), tones=("safe", "friendly"), direct=1,
  avoids=BASIC_AVOID,
  follow="Talk to the dog first and let the conversation arrive on its own.",
  notes="Ask before touching the dog.")
L(C, 3, "すごく人懐っこいですね。", "He's very friendly.",
  locs=("park", "waterfront", "street"), cues=("dog",), acts=("walking",),
  tones=("safe", "friendly"), direct=1, avoids=BASIC_AVOID,
  notes="For when the dog has come to you first.")
L(C, 4, "ここ、夕方の雰囲気いいですよね。",
  "The atmosphere here in the evening is lovely.",
  locs=("park", "waterfront"), cues=("weather",), tones=("safe",
  "situational"), direct=1, avoids=("isolatedSetting",) + BASIC_AVOID,
  notes="Daylight and other people around only. Never approach someone "
        "sitting alone after dark in a quiet spot.")
L(C, 5, "その写真、いい感じに撮れそうですね。",
  "That looks like it'll make a good photo.",
  locs=("park", "waterfront", "festival"), cues=("takingPhotographs",),
  acts=("photographing",), tones=("safe", "friendly"), direct=1,
  avoids=BASIC_AVOID)
L(C, 6, "いい場所知ってますね。", "You know the good spots.",
  locs=("park", "waterfront"), groups=SOLO_OR_PAIR,
  tones=("friendly", "playful"), direct=2,
  avoids=("isolatedSetting",) + BASIC_AVOID)
L(C, 7, "ここの夕日、毎回ちょっと得した気分になります。",
  "This sunset makes me feel like I've got away with something every time.",
  locs=("park", "waterfront"), cues=("weather",),
  tones=("friendly", "situational"), direct=2,
  avoids=("isolatedSetting",) + BASIC_AVOID)

# ---------------------------------------------------------------------------
# Festival / matsuri
# ---------------------------------------------------------------------------
C = "festival"
L(C, 1, "浴衣、すごく似合ってますね。", "Your yukata really suits you.",
  locs=("festival",), cues=("distinctiveOutfit", "festivalItem"),
  groups=SOLO_OR_PAIR, noise=("normal", "loud"), tones=("friendly",),
  direct=2, avoids=BASIC_AVOID)
L(C, 2, "今日、雰囲気最高ですね。", "The atmosphere today is wonderful.",
  locs=("festival", "concert"), noise=("normal", "loud"),
  tones=("safe", "situational"), direct=1)
L(C, 3, "その食べ物、正解っぽいですね。",
  "That looks like the right choice.",
  locs=("festival",), cues=("food", "festivalItem"), noise=("normal", "loud"),
  tones=("friendly", "situational"), direct=1, acts=("eating",))
L(C, 4, "その景品、取れたんですか？すごいですね。",
  "Did you win that? That's impressive.",
  locs=("festival",), cues=("festivalItem",), noise=("normal", "loud"),
  tones=("friendly",), direct=2)
L(C, 5, "花火始まる前からもう楽しいですね。",
  "It's already fun and the fireworks haven't even started.",
  locs=("festival",), cues=("waiting",), noise=("normal", "loud"),
  tones=("friendly", "situational"), direct=1, acts=("waiting",))
L(C, 6, "お祭りって、知らない人とも話しやすくなりますね。",
  "Festivals make it easier to talk to people you don't know.",
  locs=("festival",), noise=("normal", "loud"),
  tones=("friendly", "situational"), direct=2)
L(C, 7, "その団扇かわいいですね。", "That fan is lovely.",
  locs=("festival",), cues=("festivalItem",), noise=("normal", "loud"),
  tones=("safe", "friendly"), direct=1)

# ---------------------------------------------------------------------------
# Cosplay / anime event
# ---------------------------------------------------------------------------
C = "cosplayEvent"
L(C, 1, "〇〇ですよね？完成度高いですね！",
  "You're ___, right? The execution is superb!",
  locs=("cosplayEvent",), cues=("cosplay",), noise=("normal", "loud"),
  tones=("friendly",), direct=2, conds=("genuineKnowledgeOfSubject",),
  follow="Ask how long the build took. Cosplayers usually enjoy that "
         "question.",
  notes="Naming the character correctly is the entire compliment.")
L(C, 2, "その衣装、細かいところまですごいですね。",
  "The detail on that costume is remarkable.",
  locs=("cosplayEvent",), cues=("cosplay",), noise=("normal", "loud"),
  tones=("safe", "friendly"), direct=2)
L(C, 3, "ウィッグのセット、めっちゃきれいですね。",
  "The wig styling is beautifully done.",
  locs=("cosplayEvent",), cues=("cosplay", "hairstyle"),
  noise=("normal", "loud"), tones=("friendly",), direct=2)
L(C, 4, "小物、自作ですか？すごく本物っぽいですね。",
  "Did you make the props yourself? They look completely real.",
  locs=("cosplayEvent",), cues=("cosplay",), noise=("normal", "loud"),
  tones=("friendly",), direct=2)
L(C, 5, "その作品好きな人に会えて嬉しいです。",
  "It's great to meet someone who likes that series.",
  locs=("cosplayEvent", "bookstore", "meetup"),
  cues=("cosplay", "characterMerchandise"), noise=("normal", "loud"),
  tones=("friendly",), direct=2, conds=("genuineKnowledgeOfSubject",))
L(C, 6, "写真お願いしたくなる完成度ですね。",
  "The quality makes me want to ask for a photo.",
  locs=("cosplayEvent",), cues=("cosplay",), noise=("normal", "loud"),
  tones=("friendly",), direct=2,
  follow="Ask permission before photographing, and stop if the answer is no.")
L(C, 7, "撮影終わったあと、少し作品の話したいです。",
  "Once you're done shooting, I'd like to talk about the series a bit.",
  locs=("cosplayEvent",), cues=("cosplay", "takingPhotographs"),
  noise=("normal", "loud"), tones=("friendly", "direct"), direct=3,
  notes="The right line when she is currently busy being photographed: it "
        "waits instead of interrupting.")
L(C, 8, "コスだけじゃなくて、本人の雰囲気にも合ってますね。",
  "It suits not just the cosplay but you as well.",
  locs=("cosplayEvent",), cues=("cosplay",), noise=("normal", "loud"),
  tones=("flirty", "friendly"), direct=4, conds=("conversationStarted",),
  notes="A more personal compliment. Only once you have actually been "
        "talking.")

# ---------------------------------------------------------------------------
# Concert / live music
# ---------------------------------------------------------------------------
C = "concert"
L(C, 1, "この曲、生で聴くと全然違いますね。",
  "This song is completely different live.",
  locs=("concert",), cues=("music",), noise=("loud", "veryLoud"),
  tones=("friendly", "situational"), direct=1,
  notes="Between songs, never during one.")
L(C, 2, "さっきの曲、最高でしたね。", "That last song was superb.",
  locs=("concert", "club"), cues=("music",), noise=("loud", "veryLoud"),
  tones=("safe", "situational"), direct=1)
L(C, 3, "そのバンド好きなのが伝わります。",
  "It's obvious how much you love this band.",
  locs=("concert",), cues=("characterMerchandise", "distinctiveOutfit"),
  noise=("loud", "veryLoud"), tones=("friendly",), direct=2)
L(C, 4, "そのTシャツ、かなりレアですよね。",
  "That shirt is pretty rare, isn't it.",
  locs=("concert",), cues=("distinctiveOutfit",), noise=("loud", "veryLoud"),
  tones=("friendly",), direct=2, conds=("genuineKnowledgeOfSubject",))
L(C, 5, "今日のセットリスト、強すぎますね。",
  "Tonight's setlist is ridiculous.",
  locs=("concert",), cues=("music",), noise=("loud", "veryLoud"),
  tones=("friendly", "situational"), direct=1)
L(C, 6, "耳大丈夫ですか？音かなり大きいですね。",
  "Are your ears all right? It's seriously loud.",
  locs=("concert", "club"), noise=("loud", "veryLoud"),
  tones=("safe", "friendly"), direct=1,
  notes="Genuine concern, best on the way out or in a quieter corner.")

# ---------------------------------------------------------------------------
# Gym / kickboxing class
# ---------------------------------------------------------------------------
C = "fitnessClass"
L(C, 1, "今日の練習、かなりきつかったですね。",
  "That session was hard going.",
  locs=("gym", "kickboxingClass"), cues=("sharedActivity",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID,
  notes="After class, never mid-set. Never comment on her body, weight, "
        "flexibility or clothing fit.")
L(C, 2, "あのコンビネーション、上手かったですね。",
  "That combination was well done.",
  locs=("kickboxingClass", "gym"), cues=("sharedActivity",),
  tones=("friendly",), direct=2, avoids=BASIC_AVOID)
L(C, 3, "今日、先生いつもより厳しいですね。",
  "The instructor is tougher than usual today.",
  locs=("gym", "kickboxingClass"), cues=("sharedActivity",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 4, "僕、途中で完全にバテてました。",
  "I was completely finished halfway through.",
  locs=("gym", "kickboxingClass"), cues=("sharedActivity",),
  tones=("playful", "friendly"), direct=1, avoids=BASIC_AVOID)
L(C, 5, "同じ曜日によく会いますね。",
  "We seem to end up here on the same days.",
  locs=("gym", "kickboxingClass"), tones=("safe", "friendly"), direct=2,
  avoids=BASIC_AVOID,
  notes="Only when it is genuinely true and has happened naturally.")
L(C, 6, "そのグローブ、デザインいいですね。",
  "Those gloves have a great design.",
  locs=("kickboxingClass", "gym"), cues=("sportsEquipment",),
  tones=("safe", "friendly"), direct=1, avoids=BASIC_AVOID)
L(C, 7, "練習仲間がいると続けやすいですね。",
  "It's easier to keep at it with training partners.",
  locs=("gym", "kickboxingClass"), cues=("sharedActivity",),
  tones=("friendly",), direct=2, conds=("conversationStarted",),
  avoids=BASIC_AVOID)

# ---------------------------------------------------------------------------
# Meetup / language exchange
# ---------------------------------------------------------------------------
C = "meetupOrLanguageExchange"
L(C, 1, "さっきの話、面白かったです。",
  "What you said earlier was interesting.",
  locs=("meetup", "languageExchange", "party"), cues=("sharedActivity",),
  tones=("safe", "friendly"), direct=2, conds=("conversationStarted",))
L(C, 2, "説明がすごく分かりやすかったです。",
  "Your explanation was really clear.",
  locs=("meetup", "languageExchange"), cues=("sharedActivity",),
  tones=("safe", "friendly"), direct=2, conds=("conversationStarted",))
L(C, 3, "発音きれいですね。", "Your pronunciation is lovely.",
  locs=("languageExchange",), cues=("sharedActivity",),
  tones=("safe", "friendly"), direct=2)
L(C, 4, "僕も同じところで迷いました。",
  "I got stuck in exactly the same place.",
  locs=("languageExchange", "meetup"), cues=("sharedActivity",),
  tones=("safe", "situational"), direct=1)
L(C, 5, "初参加同士っぽいですね。",
  "We both look like first-timers.",
  locs=("meetup", "languageExchange"), tones=("friendly", "situational"),
  direct=2)
L(C, 6, "さっきから共通点が多い気がします。",
  "I feel like we keep finding things in common.",
  locs=("meetup", "languageExchange", "party"),
  tones=("friendly", "flirty"), direct=3, conds=("conversationStarted",))

# ---------------------------------------------------------------------------
# Party
# ---------------------------------------------------------------------------
C = "party"
L(C, 1, "まだちゃんと話してなかったですね。",
  "We haven't properly spoken yet.",
  locs=("party",), noise=("normal", "loud"), tones=("safe", "friendly"),
  direct=2)
L(C, 2, "今日、誰と知り合いなんですか？",
  "So who do you know here?",
  locs=("party",), noise=("normal", "loud"), tones=("safe", "situational"),
  direct=1, follow="The answer usually hands you the next three questions.")
L(C, 3, "まだ乾杯してなかったですね。", "We haven't had a toast yet.",
  locs=("party", "bar"), cues=("drink",), noise=("normal", "loud"),
  tones=("playful", "friendly"), direct=2)
L(C, 4, "僕たち、共通の友達以外にも共通点ありそうですね。",
  "I suspect we have more in common than just the mutual friend.",
  locs=("party",), noise=("normal", "loud"), tones=("playful", "flirty"),
  direct=3, conds=("conversationStarted",))

# ---------------------------------------------------------------------------
# Waiting in line
# ---------------------------------------------------------------------------
C = "waitingLine"
L(C, 1, "結構並びますね。", "Quite a queue, isn't it.",
  locs=("waitingLine", "restaurant", "festival"), cues=("waiting",),
  acts=("waiting",), tones=("safe", "situational"), direct=1,
  avoids=BASIC_AVOID,
  notes="The safest opener in the library. Easy to answer, easy to ignore.")
L(C, 2, "ここまで並ぶと期待値上がりますね。",
  "After queueing this long the expectations go up.",
  locs=("waitingLine", "restaurant"), cues=("waiting",), acts=("waiting",),
  tones=("friendly", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 3, "進んだと思ったら全然進んでないですね。",
  "Just when you think it's moving, it isn't.",
  locs=("waitingLine", "trainStation"), cues=("waiting",), acts=("waiting",),
  tones=("playful", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 4, "その選択、人気みたいですね。",
  "Looks like that's the popular choice.",
  locs=("waitingLine", "restaurant", "convenienceStore"),
  cues=("food", "waiting"), acts=("waiting",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 5, "一人で並ぶより、ちょっと話せるほうが楽ですね。",
  "Queueing is easier with someone to talk to.",
  locs=("waitingLine",), cues=("waiting",), acts=("waiting",),
  tones=("friendly",), direct=2, conds=("conversationStarted",),
  avoids=BASIC_AVOID)

# ---------------------------------------------------------------------------
# Train station / public transport
# ---------------------------------------------------------------------------
C = "transport"
L(C, 1, "今日、電車かなり混んでますね。",
  "The trains are really packed today.",
  locs=("trainStation", "publicTransport"), cues=("waiting",),
  acts=("commuting", "waiting"), tones=("safe", "situational"), direct=1,
  conds=("busyPublicSetting",), avoids=BASIC_AVOID,
  notes="Open, populated platform only. Never inside a near-empty carriage, "
        "never late at night, never where she cannot easily walk away.")
L(C, 2, "この路線、よく遅れますね。", "This line is often delayed.",
  locs=("trainStation", "publicTransport"), cues=("waiting",),
  acts=("commuting", "waiting"), tones=("safe", "situational"), direct=1,
  conds=("busyPublicSetting",), avoids=BASIC_AVOID)
L(C, 3, "そのキーホルダー、〇〇ですよね。",
  "That keyring is ___, isn't it?",
  locs=("trainStation", "publicTransport"), cues=("characterMerchandise",),
  acts=("waiting",), tones=("safe", "friendly"), direct=2,
  conds=("genuineKnowledgeOfSubject", "busyPublicSetting"),
  avoids=BASIC_AVOID)
L(C, 4, "急にすみません。その服、すごく素敵だと思いました。",
  "Sorry to interrupt. I thought your outfit looked wonderful.",
  locs=("trainStation",), cues=("distinctiveOutfit",), acts=("waiting",),
  tones=("direct", "friendly"), direct=4,
  conds=("personIsNotRushing", "busyPublicSetting"), avoids=BASIC_AVOID,
  notes="Daytime, busy platform. Do not ask where she lives or which stop "
        "she is getting off at.")

# ---------------------------------------------------------------------------
# Weather
# ---------------------------------------------------------------------------
C = "weather"
L(C, 1, "急に降ってきましたね。", "That rain came out of nowhere.",
  locs=("street", "shoppingArea", "cafe", "trainStation"), cues=("weather",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 2, "この雨、聞いてないですよね。",
  "Nobody warned us about this rain.",
  locs=("street", "shoppingArea", "trainStation"), cues=("weather",),
  tones=("playful", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 3, "傘持ってる人が勝ち組ですね。",
  "Anyone with an umbrella is winning today.",
  locs=("street", "shoppingArea", "trainStation"), cues=("weather",),
  tones=("playful", "friendly"), direct=2, avoids=BASIC_AVOID)
L(C, 4, "今日、暑さが本気すぎますね。",
  "The heat is not messing about today.",
  locs=("street", "shoppingArea", "park", "festival"), cues=("weather",),
  tones=("safe", "situational"), direct=1, avoids=BASIC_AVOID)
L(C, 5, "雨宿り仲間ですね。",
  "Fellow rain-shelterers, then.",
  locs=("street", "shoppingArea", "cafe"), cues=("weather", "waiting"),
  tones=("playful", "friendly"), direct=2, avoids=BASIC_AVOID)
L(C, 6, "寒すぎて、知らない人とも団結できそうですね。",
  "It's cold enough that strangers could form an alliance.",
  locs=("street", "festival", "waitingLine", "concert"), cues=("weather",),
  tones=("playful",), direct=2, avoids=BASIC_AVOID)

# ---------------------------------------------------------------------------
# She is with one friend
# ---------------------------------------------------------------------------
C = "withOneFriend"
L(C, 1, "二人ともすごく楽しそうですね。",
  "You two look like you're having a great time.",
  locs=("bar", "standingBar", "festival", "party", "club"),
  cues=("groupHavingFun",), groups=("withOneFriend", "smallGroup"),
  noise=("normal", "loud"), tones=("safe", "friendly"), direct=2,
  notes="Address both of them. Ignoring the friend is the single most common "
        "way this goes wrong.")
L(C, 2, "二人ともおしゃれですね。方向性が違っていい感じです。",
  "You're both stylish, and in different directions, which is great.",
  locs=("bar", "standingBar", "festival", "party") + DAY,
  cues=("distinctiveOutfit",), groups=("withOneFriend",),
  noise=("quiet", "normal", "loud"), tones=("friendly",), direct=2)
L(C, 3, "どっちかだけに声かけるのも変なので、二人に挨拶しに来ました。",
  "It would be odd to talk to just one of you, so I came to greet you both.",
  locs=("bar", "standingBar", "festival", "party"),
  groups=("withOneFriend",), noise=("normal", "loud"),
  tones=("direct", "friendly"), direct=3,
  notes="Honest and disarming. Do not then peel one of them away; build a "
        "friendly interaction with both first.")
L(C, 4, "すごく仲良さそうですね。", "You two seem close.",
  locs=("bar", "cafe", "festival", "party"), cues=("groupHavingFun",),
  groups=("withOneFriend",), noise=("quiet", "normal", "loud"),
  tones=("safe", "friendly"), direct=1)
L(C, 5, "どっちが今日ここに来ようって言ったんですか？",
  "Which of you suggested coming here today?",
  locs=("bar", "standingBar", "festival", "party", "cafe"),
  groups=("withOneFriend", "smallGroup"), noise=("normal", "loud"),
  tones=("playful", "friendly"), direct=2,
  conds=("conversationStarted",),
  follow="A good second question because it includes them both.")

# ---------------------------------------------------------------------------
# Direct but respectful
# ---------------------------------------------------------------------------
C = "universal"
L(C, 11, "率直に言うと、すごくタイプです。",
  "To be direct about it, you're very much my type.",
  locs=("bar", "standingBar", "party", "club", "festival"),
  cues=("eyeContact",), groups=("alone",), noise=("normal", "loud"),
  tones=("direct", "flirty"), direct=5,
  conds=("eyeContactEstablished",), avoids=("companionsPresent",))
L(C, 12, "迷ったんですけど、話しかけないほうが後悔すると思いました。",
  "I hesitated, but I decided I'd regret not saying something.",
  locs=DAY + ("bar", "party", "cafe", "festival"), groups=("alone",),
  noise=("quiet", "normal", "loud"), tones=("direct", "friendly"), direct=4,
  conds=("busyPublicSetting",), avoids=BASIC_AVOID)
L(C, 13, "ナンパというより、普通に知り合いたいと思いました。",
  "This isn't really a pick-up. I just wanted to get to know you.",
  locs=DAY + ("cafe", "bookstore", "park"), groups=("alone",),
  tones=("direct", "friendly"), direct=4,
  conds=("busyPublicSetting",), avoids=BASIC_AVOID)
L(C, 14, "いきなり連絡先じゃなくて、まず少し話したいです。",
  "Rather than asking for your number straight away, I'd like to talk a "
  "little first.",
  locs=DAY + ("bar", "cafe", "party", "festival"), groups=("alone",),
  noise=("quiet", "normal", "loud"), tones=("direct", "friendly"), direct=4,
  avoids=BASIC_AVOID,
  notes="Reassuring precisely because it asks for less than expected.")
L(C, 15, "急にすみません。迷惑だったらすぐ行きます。すごく素敵だと思いました。",
  "Sorry to appear out of nowhere. I'll go if this is unwelcome. I thought "
  "you looked wonderful.",
  locs=DAY + ("cafe", "park", "trainStation"), groups=("alone",),
  tones=("direct",), direct=4,
  conds=("busyPublicSetting",), avoids=BASIC_AVOID,
  notes="Hands her the exit in the same breath as the compliment. That is "
        "what makes a direct approach acceptable.")
L(C, 16, "また会えたら嬉しいです。", "I'd be glad to see you again.",
  locs=("bar", "cafe", "party", "meetup", "festival"),
  noise=("quiet", "normal", "loud"), tones=("direct", "friendly"), direct=3,
  conds=("conversationStarted",),
  notes="A gentle close that does not require an answer on the spot.")

# ---------------------------------------------------------------------------
# Leads into exchanging contact details
# ---------------------------------------------------------------------------
C = "contactExchange"
L(C, 1, "この話、また続きしたいですね。",
  "I'd like to pick this conversation up again.",
  locs=("bar", "cafe", "party", "meetup", "concert", "cosplayEvent"),
  noise=("quiet", "normal", "loud"), tones=("friendly", "direct"), direct=3,
  conds=("conversationStarted",),
  notes="Works when there is a genuinely unfinished topic.")
L(C, 2, "そのおすすめ、あとで送ってほしいです。",
  "I'd like you to send me that recommendation later.",
  locs=("bar", "cafe", "bookstore", "concert", "cosplayEvent", "meetup"),
  noise=("quiet", "normal", "loud"), tones=("friendly",), direct=3,
  conds=("conversationStarted",),
  follow="Gives an ordinary, practical reason to exchange contacts.")
L(C, 3, "次はもう少しゆっくり話したいですね。",
  "Next time I'd like to talk somewhere a bit calmer.",
  locs=("club", "concert", "bar", "festival"), noise=("loud", "veryLoud"),
  tones=("friendly", "direct"), direct=3, conds=("conversationStarted",))
L(C, 4, "また会いたいので、連絡できるようにしてもいいですか？",
  "I'd like to see you again. Could we exchange contact details?",
  locs=("bar", "cafe", "party", "meetup", "festival", "cosplayEvent"),
  noise=("quiet", "normal", "loud"), tones=("direct",), direct=4,
  conds=("conversationStarted",),
  notes="Straightforward and easy to decline, which is the point.")
L(C, 5, "今日話せてよかったです。また連絡したいです。",
  "I'm glad we talked. I'd like to stay in touch.",
  locs=("bar", "cafe", "party", "meetup", "concert"),
  noise=("quiet", "normal", "loud"), tones=("direct", "friendly"), direct=3,
  conds=("conversationStarted",))
L(C, 6, "インスタ交換したら、次のイベント分かりやすいですね。",
  "If we swap Instagram it'll be easier to know about the next event.",
  locs=("cosplayEvent", "concert", "festival", "meetup"),
  noise=("normal", "loud"), tones=("friendly",), direct=3,
  conds=("conversationStarted",))

# ---------------------------------------------------------------------------
# Graceful exits
# ---------------------------------------------------------------------------
C = "gracefulExit"
EXIT_NOTE = ("Say it once, warmly, and then actually leave. A graceful exit "
             "matters more than any opener.")
L(C, 1, "すみません、急に声かけて。よい一日を。",
  "Sorry for approaching out of the blue. Have a good day.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 2, "邪魔してすみません。楽しんでください。",
  "Sorry to have interrupted. Enjoy your day.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 3, "お友達との時間にすみませんでした。",
  "Sorry for interrupting your time with your friend.",
  locs=(), groups=("withOneFriend", "smallGroup"), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 4, "急いでるところ、失礼しました。",
  "Sorry, I can see you're in a hurry.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 5, "大丈夫です、ありがとうございます。",
  "That's completely fine, thank you.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 6, "では、よい夜を。", "Have a good evening, then.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 7, "話してくれてありがとうございました。",
  "Thank you for talking with me.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 8, "ちょっとでも話せてよかったです。",
  "I'm glad we got to talk, even briefly.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 9, "仕事中にすみません。頑張ってください。",
  "Sorry to interrupt you at work. Good luck with it.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)
L(C, 10, "気にしないでください。失礼します。",
  "Please don't give it a thought. I'll leave you to it.",
  locs=(), tones=("safe",), direct=1,
  noise=("quiet", "normal", "loud", "veryLoud"), notes=EXIT_NOTE)


# ---------------------------------------------------------------------------
# Validation against the Dart enums, then output
# ---------------------------------------------------------------------------

def parse_dart_enums():
    """Extracts enum names and values from lib/domain/enums/enums.dart."""
    src = open(os.path.join(ROOT, 'lib/domain/enums/enums.dart'),
               encoding='utf-8').read()
    enums = {}
    for match in re.finditer(r'enum\s+(\w+)\s*\{(.*?)\}', src, re.S):
        name, body = match.group(1), match.group(2)
        # Stop at the first method/getter inside the enum body.
        body = body.split(';')[0]
        values = [v.strip() for v in body.split(',')]
        enums[name] = [v for v in values if re.fullmatch(r'\w+', v)]
    return enums


def validate(enums):
    problems = []
    seen_ids = set()
    seen_ja = {}
    field_enum = {
        'category': 'LineCategory',
        'locations': 'LocationTag',
        'activities': 'ActivityTag',
        'observableCues': 'ObservableCue',
        'groupSizes': 'GroupSize',
        'noiseLevels': 'NoiseLevel',
        'tones': 'Tone',
        'conditions': 'UseCondition',
        'avoidConditions': 'AvoidCondition',
    }
    for line in LINES:
        lid = line['id']
        if lid in seen_ids:
            problems.append('duplicate id: %s' % lid)
        seen_ids.add(lid)

        ja = line['japaneseText']
        if ja in seen_ja:
            problems.append('duplicate Japanese text %r (%s and %s)'
                            % (ja, seen_ja[ja], lid))
        seen_ja[ja] = lid

        if not ja.strip():
            problems.append('%s: empty japaneseText' % lid)
        if not line['englishMeaning']:
            problems.append('%s: missing englishMeaning' % lid)
        if not 1 <= line['directness'] <= 5:
            problems.append('%s: directness out of range' % lid)
        if not line['tones']:
            problems.append('%s: no tone' % lid)

        for field, enum_name in field_enum.items():
            allowed = enums.get(enum_name)
            if allowed is None:
                problems.append('unknown enum %s' % enum_name)
                continue
            value = line[field]
            values = [value] if isinstance(value, str) else value
            for v in values:
                if v not in allowed:
                    problems.append('%s: %s has invalid value %r (allowed: %s)'
                                    % (lid, field, v, ', '.join(allowed)))

        # An exit line must not also be tagged as an opener category.
        if line['category'] == 'gracefulExit' and line['directness'] != 1:
            problems.append('%s: exit lines should be directness 1' % lid)

        # A line that requires eye contact must not also avoid noEyeContact;
        # that is the same rule expressed twice.
        if ('eyeContactEstablished' in line['conditions']
                and 'noEyeContact' in line['avoidConditions']):
            problems.append('%s: redundant eye-contact rule' % lid)
    return problems


def main():
    enums = parse_dart_enums()
    problems = validate(enums)
    if problems:
        print('Seed validation FAILED:')
        for p in problems:
            print('  - %s' % p)
        return 1

    payload = {
        'schemaVersion': 1,
        'app': 'OpenCue',
        'kind': 'starterLibrary',
        'lines': LINES,
    }
    pretty = json.dumps(payload, ensure_ascii=False, indent=2,
                        sort_keys=False)

    ref_path = os.path.join(ROOT, 'assets/sample/starter_library.json')
    with open(ref_path, 'w', encoding='utf-8') as handle:
        handle.write(pretty + '\n')

    compact = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    if "'''" in compact or r'\'' in compact:
        print('Seed JSON contains a sequence that breaks the Dart raw string.')
        return 1

    dart_path = os.path.join(ROOT, 'lib/data/seed/starter_library.dart')
    with open(dart_path, 'w', encoding='utf-8') as handle:
        handle.write(dart_header(len(LINES)))
        handle.write("const String starterLibraryJson = r'''\n")
        handle.write(compact)
        handle.write("\n''';\n")

    counts = {}
    for line in LINES:
        counts[line['category']] = counts.get(line['category'], 0) + 1
    print('Seed OK: %d lines across %d categories'
          % (len(LINES), len(counts)))
    for cat in sorted(counts):
        print('  %-28s %d' % (cat, counts[cat]))
    return 0


def dart_header(count):
    return '''// GENERATED FILE. Do not edit by hand.
//
// Regenerate with:  python3 tool/build_seed.py
//
// The starter library ships as JSON rather than as Dart object literals so
// that seeding runs through exactly the same parser as user imports. If
// OpenerLine.fromJson can read this, it can read an import file, and the
// seed test proves it on every run.
//
// $count starter lines. Source material adapted and edited; lines that were
// backhanded, presumptuous about what the other person is thinking, or that
// pressed someone to leave their friends were dropped rather than tagged.

/// The starter library, as a transfer-format JSON document.
'''.replace('$count', str(count))


if __name__ == '__main__':
    sys.exit(main())
