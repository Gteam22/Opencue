import '../enums/enums.dart';

/// The rules that turn image labels into app context.
///
/// Kept in one file, as data, rather than as string comparisons scattered
/// through widgets. Every rule is unit-tested in
/// test/scan_heuristics_test.dart.
///
/// Weights are integers accumulated per candidate; FieldConfidence turns the
/// total into a level. They are set so that a single generic label cannot on
/// its own preselect anything — corroboration is required. `cup` contributes
/// to Café, but a cup alone stays below the preselect threshold, because cups
/// are also on tables in restaurants, offices and trains.
class ScanHeuristics {
  const ScanHeuristics._();

  /// Cues the scanner is never allowed to infer, whatever the labels say.
  ///
  /// Coarse anonymous head-counting is allowed and lives in PersonPresence.
  /// These are different: every one is a judgement about a *particular*
  /// person — whether they looked at you, whether they smiled, what their
  /// hair or nails or outfit are like, whether a group appears to be enjoying
  /// itself. Counting how many people are in a carriage is scene description;
  /// deciding that someone smiled at you is profiling. The user ticks these
  /// themselves if they apply.
  ///
  /// ObservationNormalizer asserts against this set, so adding a rule that
  /// produces one of these fails the tests rather than shipping.
  static const Set<ObservableCue> neverInferred = <ObservableCue>{
    ObservableCue.eyeContact,
    ObservableCue.smile,
    ObservableCue.distinctiveOutfit,
    ObservableCue.hairstyle,
    ObservableCue.nails,
    ObservableCue.groupHavingFun,
  };

  /// Labels that suggest a location, with their weight.
  ///
  /// A label may appear under several locations; the totals compete.
  static const Map<LocationTag, Map<String, int>> locationRules =
      <LocationTag, Map<String, int>>{
    LocationTag.cafe: <String, int>{
      'cafe': 45,
      'café': 45,
      'coffeehouse': 45,
      'coffee': 30,
      'espresso': 35,
      'latte': 35,
      'cappuccino': 35,
      'mug': 20,
      'cup': 15,
      'saucer': 20,
      'teapot': 20,
      'pastry': 20,
      'cake': 15,
      'barista': 40,
      'counter': 10,
      'table': 8,
    },
    LocationTag.bar: <String, int>{
      'bar': 40,
      'pub': 45,
      'tavern': 45,
      'beer': 35,
      'ale': 30,
      'lager': 30,
      'cocktail': 40,
      'wine': 30,
      'wine glass': 35,
      'whisky': 35,
      'whiskey': 35,
      'sake': 35,
      'liquor': 35,
      'bottle': 12,
      'bartender': 40,
      'stool': 15,
      'neon': 12,
    },
    LocationTag.standingBar: <String, int>{
      'izakaya': 40,
      'standing bar': 45,
      'counter': 12,
    },
    LocationTag.restaurant: <String, int>{
      // Food alone must not imply a restaurant: the spec is explicit, and a
      // plate of food is equally a café, a festival stall or a kitchen. These
      // weights only add up with room-level evidence.
      'restaurant': 45,
      'diner': 40,
      'dining room': 35,
      'menu': 20,
      'tableware': 18,
      'cutlery': 18,
      'waiter': 30,
    },
    LocationTag.club: <String, int>{
      'nightclub': 50,
      'disco': 45,
      'dance floor': 40,
      'dj': 35,
      'stage light': 25,
      'laser': 20,
    },
    LocationTag.bookstore: <String, int>{
      'bookstore': 50,
      'bookshop': 50,
      'library': 40,
      'bookcase': 35,
      'bookshelf': 35,
      'book': 20,
      'shelf': 12,
      'magazine': 20,
    },
    LocationTag.convenienceStore: <String, int>{
      'convenience store': 50,
      'supermarket': 40,
      'grocery store': 40,
      'aisle': 20,
      'shelf': 10,
      'refrigerator': 15,
      'vending machine': 20,
    },
    LocationTag.trainStation: <String, int>{
      'train station': 50,
      'railway station': 50,
      'subway': 40,
      'metro': 40,
      'platform': 35,
      'train': 30,
      'railway': 30,
      'track': 25,
      'turnstile': 35,
      'timetable': 30,
    },
    LocationTag.publicTransport: <String, int>{
      'bus': 35,
      'bus stop': 40,
      'tram': 35,
      'passenger': 15,
      'handrail': 20,
    },
    LocationTag.park: <String, int>{
      'park': 40,
      'garden': 30,
      'lawn': 30,
      'grass': 25,
      'tree': 18,
      'bench': 25,
      'playground': 35,
      'flower': 15,
    },
    LocationTag.waterfront: <String, int>{
      'beach': 45,
      'sea': 40,
      'ocean': 40,
      'river': 35,
      'lake': 35,
      'harbor': 40,
      'harbour': 40,
      'pier': 40,
      'boat': 20,
      'sand': 25,
    },
    LocationTag.street: <String, int>{
      'street': 35,
      'road': 25,
      'sidewalk': 35,
      'crosswalk': 35,
      'traffic light': 30,
      'building': 10,
      'city': 15,
      'alley': 30,
    },
    LocationTag.shoppingArea: <String, int>{
      'shopping mall': 45,
      'mall': 40,
      'boutique': 35,
      'storefront': 30,
      'shop window': 35,
      'shopping': 20,
    },
    LocationTag.gym: <String, int>{
      'gym': 50,
      'fitness': 45,
      'dumbbell': 40,
      'barbell': 40,
      'treadmill': 45,
      'weight': 25,
      'exercise equipment': 40,
      'yoga mat': 30,
    },
    LocationTag.kickboxingClass: <String, int>{
      'boxing': 45,
      'boxing glove': 50,
      'punching bag': 50,
      'martial arts': 45,
      'ring': 20,
      'dojo': 45,
    },
    LocationTag.festival: <String, int>{
      'festival': 45,
      'lantern': 30,
      'fireworks': 40,
      'parade': 35,
      'stall': 25,
      'market stall': 30,
      'yukata': 40,
      'kimono': 30,
      'shrine': 30,
      'temple': 25,
    },
    LocationTag.concert: <String, int>{
      'concert': 50,
      'stage': 30,
      'guitar': 25,
      'drum': 25,
      'microphone': 25,
      'amplifier': 30,
      'band': 30,
      'audience': 25,
    },
    LocationTag.cosplayEvent: <String, int>{
      // Capped by cosplayConfidenceCeiling below.
      'costume': 35,
      'cosplay': 45,
      'convention': 35,
      'wig': 25,
      'mascot': 20,
      'anime': 30,
      'comic': 25,
    },
    LocationTag.party: <String, int>{
      'party': 40,
      'balloon': 30,
      'confetti': 35,
      'birthday': 35,
    },
    LocationTag.waitingLine: <String, int>{
      'queue': 45,
      'line': 15,
      'ticket': 20,
    },
  };

  /// Labels that suggest an environmental cue.
  ///
  /// Only cues describing objects and conditions appear here. Nothing in
  /// [neverInferred] may be given a rule.
  static const Map<ObservableCue, Map<String, int>> cueRules =
      <ObservableCue, Map<String, int>>{
    ObservableCue.drink: <String, int>{
      'drink': 40,
      'coffee': 40,
      'beer': 45,
      'cocktail': 45,
      'wine': 40,
      'wine glass': 45,
      'mug': 35,
      'cup': 30,
      'bottle': 25,
      'tea': 35,
      'juice': 35,
    },
    ObservableCue.food: <String, int>{
      'food': 40,
      'meal': 40,
      'dish': 35,
      'plate': 25,
      'cake': 40,
      'pastry': 40,
      'noodle': 40,
      'ramen': 45,
      'sushi': 45,
      'sandwich': 40,
      'dessert': 40,
    },
    ObservableCue.book: <String, int>{
      'book': 45,
      'bookshelf': 40,
      'bookcase': 40,
      'magazine': 35,
      'novel': 40,
      'reading': 30,
    },
    ObservableCue.dog: <String, int>{
      'dog': 55,
      'puppy': 55,
      'leash': 35,
      'canine': 45,
    },
    ObservableCue.music: <String, int>{
      'concert': 40,
      'stage': 25,
      'guitar': 40,
      'drum': 35,
      'microphone': 30,
      'speaker': 25,
      'dj': 40,
      'band': 35,
      'record': 30,
      'vinyl': 40,
    },
    ObservableCue.weather: <String, int>{
      'umbrella': 50,
      'rain': 50,
      'raincoat': 45,
      'snow': 45,
      'puddle': 35,
      'storm': 40,
      'fog': 35,
    },
    ObservableCue.festivalItem: <String, int>{
      'lantern': 40,
      'fireworks': 45,
      'yukata': 45,
      'festival': 40,
      'fan': 25,
      'mask': 25,
      'stall': 25,
    },
    ObservableCue.sportsEquipment: <String, int>{
      'dumbbell': 45,
      'barbell': 45,
      'boxing glove': 50,
      'punching bag': 50,
      'treadmill': 45,
      'yoga mat': 40,
      'bicycle': 30,
      'racket': 40,
      'ball': 25,
    },
    ObservableCue.characterMerchandise: <String, int>{
      'figurine': 40,
      'toy': 25,
      'plush': 35,
      'keychain': 30,
      'poster': 25,
      'comic': 35,
      'anime': 35,
    },
    ObservableCue.cosplay: <String, int>{
      'costume': 40,
      'cosplay': 50,
      'wig': 35,
      'mask': 20,
    },
    ObservableCue.takingPhotographs: <String, int>{
      'camera': 45,
      'photographer': 45,
      'tripod': 40,
      'smartphone': 15,
    },
    ObservableCue.waiting: <String, int>{
      'queue': 45,
      'bench': 20,
      'waiting room': 45,
      'timetable': 25,
    },
  };

  /// Labels that suggest an activity happening in the space.
  static const Map<ActivityTag, Map<String, int>> activityRules =
      <ActivityTag, Map<String, int>>{
    ActivityTag.drinking: <String, int>{
      'drink': 35,
      'beer': 40,
      'cocktail': 40,
      'coffee': 30,
      'bar': 25,
    },
    ActivityTag.eating: <String, int>{
      'food': 35,
      'meal': 40,
      'restaurant': 30,
      'dining': 35,
    },
    ActivityTag.browsing: <String, int>{
      'bookstore': 40,
      'shelf': 25,
      'shop': 25,
      'market': 25,
      'aisle': 30,
    },
    ActivityTag.exercising: <String, int>{
      'gym': 45,
      'fitness': 45,
      'treadmill': 45,
      'boxing': 40,
      'exercise': 45,
    },
    ActivityTag.dancing: <String, int>{
      'nightclub': 40,
      'dance floor': 50,
      'disco': 40,
    },
    ActivityTag.commuting: <String, int>{
      'train station': 40,
      'platform': 35,
      'subway': 40,
      'bus': 30,
    },
    ActivityTag.waiting: <String, int>{
      'queue': 45,
      'waiting room': 45,
    },
    ActivityTag.photographing: <String, int>{
      'camera': 35,
      'tripod': 40,
      'photographer': 45,
    },
    ActivityTag.shopping: <String, int>{
      'shopping mall': 40,
      'supermarket': 35,
      'storefront': 30,
    },
  };

  /// Locations whose surroundings are reliably loud.
  ///
  /// Noise is a property of a room that an image genuinely does hint at: a
  /// nightclub is loud, a library is quiet. It stays a suggestion, and the
  /// confirmation screen leaves it editable, because a photograph cannot hear.
  static const Map<LocationTag, NoiseLevel> noiseByLocation =
      <LocationTag, NoiseLevel>{
    LocationTag.club: NoiseLevel.veryLoud,
    LocationTag.concert: NoiseLevel.veryLoud,
    LocationTag.bar: NoiseLevel.loud,
    LocationTag.standingBar: NoiseLevel.loud,
    LocationTag.festival: NoiseLevel.loud,
    LocationTag.party: NoiseLevel.loud,
    LocationTag.gym: NoiseLevel.normal,
    LocationTag.kickboxingClass: NoiseLevel.normal,
    LocationTag.cafe: NoiseLevel.normal,
    LocationTag.restaurant: NoiseLevel.normal,
    LocationTag.street: NoiseLevel.normal,
    LocationTag.shoppingArea: NoiseLevel.normal,
    LocationTag.trainStation: NoiseLevel.normal,
    LocationTag.publicTransport: NoiseLevel.normal,
    LocationTag.bookstore: NoiseLevel.quiet,
    LocationTag.park: NoiseLevel.quiet,
    LocationTag.waterfront: NoiseLevel.quiet,
  };

  /// The most a cosplay-event inference may ever reach.
  ///
  /// Costume-like labels fire on ordinary clothing, uniforms, mascots and
  /// shop mannequins often enough that a confident answer would be wrong a
  /// lot. Capped so it is always offered rather than assumed.
  static const int cosplayConfidenceCeiling = 60;

  /// Ignored entirely: too generic to mean anything on their own.
  static const Set<String> stopLabels = <String>{
    'person',
    'people',
    'human',
    'face',
    'crowd',
    'photograph',
    'photography',
    'snapshot',
    'image',
    'screenshot',
    'room',
    'indoor',
    'outdoor',
    'light',
    'color',
    'pattern',
    'texture',
    'line',
    'circle',
    'material',
    'design',
    'art',
    'font',
    'text',
    'black',
    'white',
  };

  /// Whether a label should be discarded before scoring.
  ///
  /// The person-related entries are dropped here because they are useless for
  /// identifying a *venue*, not because counting people is forbidden: that
  /// happens in PersonPresence, from a generic detector, and never through
  /// these label rules.
  static bool isStopLabel(String label) =>
      stopLabels.contains(label.trim().toLowerCase());
}
