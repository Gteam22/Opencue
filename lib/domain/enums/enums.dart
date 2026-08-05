/// Controlled vocabulary for OpenCue.
///
/// Every enum value's [Enum.name] is the stable identifier used in the SQLite
/// database and in the JSON transfer format. Renaming a value is a breaking
/// change and requires a database migration plus a transfer-schema bump.
///
/// This file deliberately contains no Flutter imports. Human-readable labels
/// live in `lib/l10n`.
library;

/// Where the interaction is taking place.
enum LocationTag {
  bar,
  standingBar,
  club,
  cafe,
  restaurant,
  street,
  shoppingArea,
  convenienceStore,
  bookstore,
  park,
  waterfront,
  trainStation,
  publicTransport,
  festival,
  cosplayEvent,
  concert,
  gym,
  kickboxingClass,
  languageExchange,
  meetup,
  party,
  waitingLine,
  other,
}

/// What the other person is visibly doing. Neutral, observable activity only.
enum ActivityTag {
  browsing,
  waiting,
  eating,
  drinking,
  dancing,
  walking,
  exercising,
  reading,
  photographing,
  shopping,
  socialising,
  resting,
  commuting,
  other,
}

/// How many people are together.
/// How many people are in the situation, coarsely.
///
/// `alone` and `withOneFriend` are the project's existing names for what a
/// scan calls one person and two people; they are kept rather than renamed so
/// that the 155 seed lines, every user-written line and every stored snapshot
/// keep their meaning. `noneVisible` is new, and is what a scan returns when
/// the environment is clearly visible but nobody is in frame — distinct from
/// `unknown`, which means the scan could not tell.
enum GroupSize {
  /// The scan could see the place, and no person was in it.
  noneVisible,

  /// One person. What a scan reports as "one person visible".
  alone,

  /// Two people. What a scan reports as "two people visible".
  withOneFriend,

  smallGroup,
  largeGroup,

  /// Not established. Never assume a value in place of this.
  unknown;

  /// Whether a line that speaks to a specific person makes sense at all.
  bool get hasVisiblePeople =>
      this != GroupSize.noneVisible && this != GroupSize.unknown;

  /// Whether wording should acknowledge more than one person.
  bool get isMultiplePeople =>
      this == GroupSize.withOneFriend ||
      this == GroupSize.smallGroup ||
      this == GroupSize.largeGroup;
}

/// Ambient noise, which governs how long a line can reasonably be.
enum NoiseLevel {
  quiet,
  normal,
  loud,
  veryLoud;

  /// Ordinal distance to another level, used by the recommendation engine.
  int distanceTo(NoiseLevel other) => (index - other.index).abs();

  bool get isLoud => index >= NoiseLevel.loud.index;
}

/// The register of a line.
enum Tone {
  safe,
  friendly,
  situational,
  playful,
  direct,
  flirty,
}

/// Neutral, externally observable facts about the situation.
///
/// These are contextual facts only. There is deliberately no cue that infers
/// attraction, availability, relationship status, personality, ethnicity,
/// sexuality, vulnerability or consent, and none should be added.
enum ObservableCue {
  eyeContact,
  smile,
  distinctiveOutfit,
  hairstyle,
  nails,
  drink,
  food,
  book,
  characterMerchandise,
  cosplay,
  dog,
  music,
  sharedActivity,
  waiting,
  takingPhotographs,
  weather,
  festivalItem,
  sportsEquipment,
  groupHavingFun,
  other,
}

/// Preconditions that must hold before a line is appropriate.
///
/// A line whose conditions are not met is excluded by the recommendation
/// engine rather than merely down-ranked.
enum UseCondition {
  eyeContactEstablished,
  conversationStarted,
  priorRapport,
  personIsNotRushing,
  sharedActivityInProgress,
  genuineKnowledgeOfSubject,
  busyPublicSetting,
}

/// Situations in which a line should not be used.
///
/// The first five values correspond one-to-one with the boolean flags on
/// ContextSnapshot that trigger the "may not be a good time" advisory.
enum AvoidCondition {
  personOccupied,
  personWorking,
  headphonesOn,
  movingQuickly,
  isolatedSetting,
  noEyeContact,
  companionsPresent,
  veryLoudSetting,
  quietFocusedSetting,
}

/// Grouping used by the starter library and the library filters.
enum LineCategory {
  universal,
  eyeContactEstablished,
  cafe,
  bar,
  standingBar,
  club,
  streetOrShopping,
  convenienceStore,
  bookstore,
  parkOrWaterfront,
  festival,
  cosplayEvent,
  concert,
  fitnessClass,
  meetupOrLanguageExchange,
  party,
  waitingLine,
  transport,
  weather,
  withOneFriend,
  contactExchange,
  gracefulExit,
}

/// How an interaction went. Describes the interaction, never the person.
enum InteractionOutcome {
  positive,
  neutral,
  unreceptive,
  notRecorded,
}

/// Where a ContextSnapshot came from.
///
/// Version 1 only ever produces [manual]. The remaining values exist so that
/// a future context provider can construct an identical snapshot without any
/// change to the recommendation engine.
enum ContextSource {
  manual,
  cameraScan,
  smartGlasses,
  ambientAudio,
}

/// Interface language preference.
enum LanguageMode {
  japanese,
  english,
  bilingual,
}

/// Theme preference. Mapped to Flutter's ThemeMode in the presentation layer.
enum AppThemePreference {
  light,
  dark,
  system,
}

/// Library sort order.
enum LibrarySort {
  recentlyAdded,
  mostUsed,
  highestPositiveHistory,
  alphabetical,
}

/// Valid inclusive range for the directness scale.
const int kMinDirectness = 1;
const int kMaxDirectness = 5;

/// Clamps an arbitrary integer into the directness scale.
int clampDirectness(int value) {
  if (value < kMinDirectness) return kMinDirectness;
  if (value > kMaxDirectness) return kMaxDirectness;
  return value;
}

/// Resolves an enum value from its stable [Enum.name].
///
/// Returns null for unknown or absent names so that importing a file written
/// by a newer version degrades gracefully instead of throwing.
T? enumFromName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Resolves an enum value from its name, falling back to [fallback].
T enumFromNameOr<T extends Enum>(
  List<T> values,
  Object? name,
  T fallback,
) {
  return enumFromName<T>(values, name) ?? fallback;
}

/// Reads a set of enum values from a JSON list, skipping unknown names.
Set<T> enumSetFromJson<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! List) return <T>{};
  final result = <T>{};
  for (final item in raw) {
    final parsed = enumFromName<T>(values, item);
    if (parsed != null) result.add(parsed);
  }
  return result;
}

/// Reads a set of enum values from a comma-separated database column.
Set<T> enumSetFromCsv<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String || raw.isEmpty) return <T>{};
  final result = <T>{};
  for (final item in raw.split(',')) {
    final parsed = enumFromName<T>(values, item.trim());
    if (parsed != null) result.add(parsed);
  }
  return result;
}

/// Serialises a set of enum values to a stable, sorted list of names.
///
/// Sorting by declaration order keeps serialisation deterministic, which the
/// round-trip tests rely on.
List<String> enumSetToJson<T extends Enum>(Set<T> items) {
  final sorted = items.toList()..sort((a, b) => a.index.compareTo(b.index));
  return sorted.map((e) => e.name).toList();
}

/// Serialises a set of enum values to a comma-separated database column.
String enumSetToCsv<T extends Enum>(Set<T> items) =>
    enumSetToJson<T>(items).join(',');
