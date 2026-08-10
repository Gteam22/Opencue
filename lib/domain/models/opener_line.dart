import 'dart:convert';

import '../enums/enums.dart';

/// A single conversation opener plus the situations it suits.
///
/// Instances are immutable; use [copyWith] to derive a modified line. The
/// class is Flutter-free so that it can be unit tested and reused unchanged
/// in a future Android build.
class OpenerLine {
  OpenerLine({
    required this.id,
    required this.japaneseText,
    this.englishMeaning,
    Map<String, String>? translations,
    this.koreanRomanization,
    this.category = LineCategory.universal,
    Set<LocationTag>? locations,
    Set<ActivityTag>? activities,
    Set<ObservableCue>? observableCues,
    Set<GroupSize>? groupSizes,
    Set<NoiseLevel>? noiseLevels,
    Set<Tone>? tones,
    int directness = 2,
    this.boldness,
    this.usageType,
    Set<String>? topics,
    this.manualOnly = false,
    this.ttsJapanese = true,
    this.ttsKorean = true,
    Set<UseCondition>? conditions,
    Set<AvoidCondition>? avoidConditions,
    this.followUpSuggestion,
    this.notes,
    this.isFavorite = false,
    this.isUserCreated = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.timesShown = 0,
    this.timesUsed = 0,
    this.positiveResults = 0,
    this.neutralResults = 0,
    this.negativeResults = 0,
  })  : translations =
            Map.unmodifiable(translations ?? const <String, String>{}),
        locations = Set.unmodifiable(locations ?? const <LocationTag>{}),
        activities = Set.unmodifiable(activities ?? const <ActivityTag>{}),
        observableCues =
            Set.unmodifiable(observableCues ?? const <ObservableCue>{}),
        groupSizes = Set.unmodifiable(groupSizes ?? const <GroupSize>{}),
        noiseLevels = Set.unmodifiable(noiseLevels ?? const <NoiseLevel>{}),
        tones = Set.unmodifiable(tones ?? const <Tone>{Tone.friendly}),
        directness = clampDirectness(directness),
        topics = Set.unmodifiable(topics ?? const <String>{}),
        conditions = Set.unmodifiable(conditions ?? const <UseCondition>{}),
        avoidConditions =
            Set.unmodifiable(avoidConditions ?? const <AvoidCondition>{}),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now().toUtc();

  final String id;

  /// The opener as it is spoken. Required.
  final String japaneseText;

  /// A natural English rendering. Optional but strongly encouraged.
  final String? englishMeaning;

  /// Translations of [japaneseText] into other display languages, keyed by
  /// lowercase ISO-639 code — 'ko' for Korean today, and the door is open for
  /// 'zh', 'es' and so on without another schema change.
  ///
  /// The Japanese text is *not* duplicated in here: it stays on
  /// [japaneseText] so every line that worked before this field existed still
  /// works. A line is the same entry in every language; the map is how its
  /// Korean twin travels with it rather than being a separate, unrelated line.
  final Map<String, String> translations;

  /// An easy-to-read Roman reading of the Korean text, shown under it when the
  /// romanization setting is on. Null when there is no Korean or no reading
  /// was generated.
  final String? koreanRomanization;

  /// The Korean text, or null when this line has none.
  String? get koreanText => translations['ko'];

  /// The spoken text for a display language, falling back to Japanese when a
  /// translation is missing so a partly-translated library never shows blanks.
  String textFor(String languageCode) =>
      translations[languageCode] ?? japaneseText;

  final LineCategory category;

  /// Locations this line suits. An empty set means the line is universal and
  /// is treated as a weak match everywhere rather than a mismatch.
  final Set<LocationTag> locations;

  final Set<ActivityTag> activities;

  /// Cues the line refers to. A line that mentions a drink needs the drink to
  /// actually be observable.
  final Set<ObservableCue> observableCues;

  /// Group sizes this line suits. A set containing only [GroupSize.alone]
  /// marks a line as directed at a single person, which the engine penalises
  /// when companions are present.
  final Set<GroupSize> groupSizes;

  final Set<NoiseLevel> noiseLevels;

  final Set<Tone> tones;

  /// 1 (most indirect) to 5 (most direct).
  final int directness;

  /// Manual intensity metadata. Null for the original situational openers.
  final ConversationBoldness? boldness;

  /// Question/statement/comeback/game shape for manual browsing.
  final ConversationUsageType? usageType;

  /// Free, normalized search facets such as `kissing` and `compatibility`.
  final Set<String> topics;

  /// True for content which must only be browsed or explicitly selected.
  /// The recommendation engine excludes these records unconditionally.
  final bool manualOnly;

  /// Whether each native text is eligible for its own TTS control.
  final bool ttsJapanese;
  final bool ttsKorean;

  /// Preconditions that must hold. Unmet conditions exclude the line.
  final Set<UseCondition> conditions;

  /// Situations in which this line should not be used.
  final Set<AvoidCondition> avoidConditions;

  final String? followUpSuggestion;
  final String? notes;
  final bool isFavorite;

  /// False for lines that came from the starter library.
  final bool isUserCreated;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// How many times this line has been offered as a recommendation.
  final int timesShown;

  /// How many times the user recorded actually using it.
  final int timesUsed;

  final int positiveResults;
  final int neutralResults;

  /// Count of interactions recorded as unreceptive. Describes the
  /// interaction, not the person.
  final int negativeResults;

  /// True when this line is a graceful exit rather than an opener.
  bool get isExitLine => category == LineCategory.gracefulExit;

  /// True when the line addresses one person specifically.
  bool get addressesSinglePersonOnly =>
      groupSizes.length == 1 && groupSizes.contains(GroupSize.alone);

  /// Length in user-perceived characters, used for the loud-venue preference.
  int get displayLength => japaneseText.runes.length;

  /// Number of outcomes recorded against this line.
  int get recordedOutcomes =>
      positiveResults + neutralResults + negativeResults;

  /// Net personal signal in the range -1.0 to 1.0, or null when there is not
  /// enough personal history to say anything meaningful.
  double? get personalSignal {
    if (recordedOutcomes < 2) return null;
    final net = positiveResults - negativeResults;
    return net / recordedOutcomes;
  }

  /// Returns a list of human-facing validation problems. Empty means valid.
  ///
  /// Message text is intentionally returned as stable keys resolved by the
  /// l10n layer rather than as English prose.
  List<String> validationErrors() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('validation.idRequired');
    if (japaneseText.trim().isEmpty) {
      errors.add('validation.japaneseRequired');
    }
    if (directness < kMinDirectness || directness > kMaxDirectness) {
      errors.add('validation.directnessRange');
    }
    if (tones.isEmpty) errors.add('validation.toneRequired');
    if (manualOnly) {
      if ((englishMeaning ?? '').trim().isEmpty) {
        errors.add('validation.englishRequired');
      }
      if ((koreanText ?? '').trim().isEmpty) {
        errors.add('validation.koreanRequired');
      }
      if (boldness == null) errors.add('validation.boldnessRequired');
      if (usageType == null) errors.add('validation.usageTypeRequired');
    }
    return errors;
  }

  bool get isValid => validationErrors().isEmpty;

  OpenerLine copyWith({
    String? id,
    String? japaneseText,
    String? englishMeaning,
    bool clearEnglishMeaning = false,
    Map<String, String>? translations,
    String? koreanRomanization,
    bool clearKoreanRomanization = false,
    LineCategory? category,
    Set<LocationTag>? locations,
    Set<ActivityTag>? activities,
    Set<ObservableCue>? observableCues,
    Set<GroupSize>? groupSizes,
    Set<NoiseLevel>? noiseLevels,
    Set<Tone>? tones,
    int? directness,
    ConversationBoldness? boldness,
    bool clearBoldness = false,
    ConversationUsageType? usageType,
    bool clearUsageType = false,
    Set<String>? topics,
    bool? manualOnly,
    bool? ttsJapanese,
    bool? ttsKorean,
    Set<UseCondition>? conditions,
    Set<AvoidCondition>? avoidConditions,
    String? followUpSuggestion,
    bool clearFollowUpSuggestion = false,
    String? notes,
    bool clearNotes = false,
    bool? isFavorite,
    bool? isUserCreated,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? timesShown,
    int? timesUsed,
    int? positiveResults,
    int? neutralResults,
    int? negativeResults,
  }) {
    return OpenerLine(
      id: id ?? this.id,
      japaneseText: japaneseText ?? this.japaneseText,
      englishMeaning:
          clearEnglishMeaning ? null : (englishMeaning ?? this.englishMeaning),
      translations: translations ?? this.translations,
      koreanRomanization: clearKoreanRomanization
          ? null
          : (koreanRomanization ?? this.koreanRomanization),
      category: category ?? this.category,
      locations: locations ?? this.locations,
      activities: activities ?? this.activities,
      observableCues: observableCues ?? this.observableCues,
      groupSizes: groupSizes ?? this.groupSizes,
      noiseLevels: noiseLevels ?? this.noiseLevels,
      tones: tones ?? this.tones,
      directness: directness ?? this.directness,
      boldness: clearBoldness ? null : (boldness ?? this.boldness),
      usageType: clearUsageType ? null : (usageType ?? this.usageType),
      topics: topics ?? this.topics,
      manualOnly: manualOnly ?? this.manualOnly,
      ttsJapanese: ttsJapanese ?? this.ttsJapanese,
      ttsKorean: ttsKorean ?? this.ttsKorean,
      conditions: conditions ?? this.conditions,
      avoidConditions: avoidConditions ?? this.avoidConditions,
      followUpSuggestion: clearFollowUpSuggestion
          ? null
          : (followUpSuggestion ?? this.followUpSuggestion),
      notes: clearNotes ? null : (notes ?? this.notes),
      isFavorite: isFavorite ?? this.isFavorite,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      timesShown: timesShown ?? this.timesShown,
      timesUsed: timesUsed ?? this.timesUsed,
      positiveResults: positiveResults ?? this.positiveResults,
      neutralResults: neutralResults ?? this.neutralResults,
      negativeResults: negativeResults ?? this.negativeResults,
    );
  }

  /// Applies a recorded outcome, returning an updated line.
  OpenerLine withRecordedOutcome(InteractionOutcome outcome) {
    return copyWith(
      timesUsed: timesUsed + 1,
      positiveResults: outcome == InteractionOutcome.positive
          ? positiveResults + 1
          : positiveResults,
      neutralResults: outcome == InteractionOutcome.neutral
          ? neutralResults + 1
          : neutralResults,
      negativeResults: outcome == InteractionOutcome.unreceptive
          ? negativeResults + 1
          : negativeResults,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  // ---------------------------------------------------------------------
  // JSON (transfer format)
  // ---------------------------------------------------------------------

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'japaneseText': japaneseText,
      'englishMeaning': englishMeaning,
      // Omitted entirely when empty, so existing exports are byte-identical.
      if (translations.isNotEmpty) 'translations': translations,
      if (koreanRomanization != null) 'koreanRomanization': koreanRomanization,
      'category': category.name,
      'locations': enumSetToJson(locations),
      'activities': enumSetToJson(activities),
      'observableCues': enumSetToJson(observableCues),
      'groupSizes': enumSetToJson(groupSizes),
      'noiseLevels': enumSetToJson(noiseLevels),
      'tones': enumSetToJson(tones),
      'directness': directness,
      if (boldness != null) 'boldness': boldness!.name,
      if (usageType != null) 'usageType': usageType!.name,
      if (topics.isNotEmpty) 'topics': topics.toList()..sort(),
      if (manualOnly) 'manualOnly': true,
      'tts': <String, bool>{'jp': ttsJapanese, 'ko': ttsKorean},
      'conditions': enumSetToJson(conditions),
      'avoidConditions': enumSetToJson(avoidConditions),
      'followUpSuggestion': followUpSuggestion,
      'notes': notes,
      'isFavorite': isFavorite,
      'isUserCreated': isUserCreated,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'timesShown': timesShown,
      'timesUsed': timesUsed,
      'positiveResults': positiveResults,
      'neutralResults': neutralResults,
      'negativeResults': negativeResults,
    };
  }

  /// Builds a line from decoded JSON.
  ///
  /// Throws [FormatException] only when a genuinely required field is missing
  /// or unusable. Unknown enum names are skipped rather than fatal so that a
  /// file written by a newer version still imports.
  static OpenerLine fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final japanese = json['japaneseText'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Line is missing a non-empty "id".');
    }
    if (japanese is! String || japanese.trim().isEmpty) {
      throw FormatException('Line "$id" is missing "japaneseText".');
    }

    final tones = enumSetFromJson(Tone.values, json['tones']);
    return OpenerLine(
      id: id,
      japaneseText: japanese,
      englishMeaning: _optionalString(json['englishMeaning']),
      translations: _stringMap(json['translations']),
      koreanRomanization: _optionalString(json['koreanRomanization']),
      category: enumFromNameOr(
        LineCategory.values,
        json['category'],
        LineCategory.universal,
      ),
      locations: enumSetFromJson(LocationTag.values, json['locations']),
      activities: enumSetFromJson(ActivityTag.values, json['activities']),
      observableCues:
          enumSetFromJson(ObservableCue.values, json['observableCues']),
      groupSizes: enumSetFromJson(GroupSize.values, json['groupSizes']),
      noiseLevels: enumSetFromJson(NoiseLevel.values, json['noiseLevels']),
      tones: tones.isEmpty ? <Tone>{Tone.friendly} : tones,
      directness: _int(json['directness'], 2),
      boldness: enumFromName(ConversationBoldness.values, json['boldness']),
      usageType:
          enumFromName(ConversationUsageType.values, json['usageType']),
      topics: _stringSet(json['topics']),
      manualOnly: _bool(json['manualOnly']),
      ttsJapanese: _ttsFlag(json['tts'], 'jp'),
      ttsKorean: _ttsFlag(json['tts'], 'ko'),
      conditions: enumSetFromJson(UseCondition.values, json['conditions']),
      avoidConditions:
          enumSetFromJson(AvoidCondition.values, json['avoidConditions']),
      followUpSuggestion: _optionalString(json['followUpSuggestion']),
      notes: _optionalString(json['notes']),
      isFavorite: _bool(json['isFavorite']),
      isUserCreated: _bool(json['isUserCreated']),
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
      timesShown: _int(json['timesShown'], 0),
      timesUsed: _int(json['timesUsed'], 0),
      positiveResults: _int(json['positiveResults'], 0),
      neutralResults: _int(json['neutralResults'], 0),
      negativeResults: _int(json['negativeResults'], 0),
    );
  }

  // ---------------------------------------------------------------------
  // SQLite mapping
  // ---------------------------------------------------------------------

  /// Column map for the `opener_lines` table.
  ///
  /// Sets are stored as comma-separated names. They are short controlled
  /// vocabularies, never free text, so this stays queryable with LIKE while
  /// remaining readable when inspecting the database by hand.
  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'japanese_text': japaneseText,
      'english_meaning': englishMeaning,
      // One JSON column rather than a column per language, so a new language
      // is a data change and never a schema change.
      'translations': translations.isEmpty ? null : jsonEncode(translations),
      'korean_romanization': koreanRomanization,
      'category': category.name,
      'locations': enumSetToCsv(locations),
      'activities': enumSetToCsv(activities),
      'observable_cues': enumSetToCsv(observableCues),
      'group_sizes': enumSetToCsv(groupSizes),
      'noise_levels': enumSetToCsv(noiseLevels),
      'tones': enumSetToCsv(tones),
      'directness': directness,
      'boldness': boldness?.name,
      'usage_type': usageType?.name,
      'topics': (topics.toList()..sort()).join(','),
      'manual_only': manualOnly ? 1 : 0,
      'tts_japanese': ttsJapanese ? 1 : 0,
      'tts_korean': ttsKorean ? 1 : 0,
      'conditions': enumSetToCsv(conditions),
      'avoid_conditions': enumSetToCsv(avoidConditions),
      'follow_up_suggestion': followUpSuggestion,
      'notes': notes,
      'is_favorite': isFavorite ? 1 : 0,
      'is_user_created': isUserCreated ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'times_shown': timesShown,
      'times_used': timesUsed,
      'positive_results': positiveResults,
      'neutral_results': neutralResults,
      'negative_results': negativeResults,
    };
  }

  static OpenerLine fromDbRow(Map<String, Object?> row) {
    final tones = enumSetFromCsv(Tone.values, row['tones']);
    return OpenerLine(
      id: row['id']! as String,
      japaneseText: row['japanese_text']! as String,
      englishMeaning: _optionalString(row['english_meaning']),
      translations: _decodeTranslations(row['translations']),
      koreanRomanization: _optionalString(row['korean_romanization']),
      category: enumFromNameOr(
        LineCategory.values,
        row['category'],
        LineCategory.universal,
      ),
      locations: enumSetFromCsv(LocationTag.values, row['locations']),
      activities: enumSetFromCsv(ActivityTag.values, row['activities']),
      observableCues:
          enumSetFromCsv(ObservableCue.values, row['observable_cues']),
      groupSizes: enumSetFromCsv(GroupSize.values, row['group_sizes']),
      noiseLevels: enumSetFromCsv(NoiseLevel.values, row['noise_levels']),
      tones: tones.isEmpty ? <Tone>{Tone.friendly} : tones,
      directness: _int(row['directness'], 2),
      boldness: enumFromName(ConversationBoldness.values, row['boldness']),
      usageType:
          enumFromName(ConversationUsageType.values, row['usage_type']),
      topics: _stringSetFromDb(row['topics']),
      manualOnly: _bool(row['manual_only']),
      ttsJapanese: row['tts_japanese'] == null || _bool(row['tts_japanese']),
      ttsKorean: row['tts_korean'] == null || _bool(row['tts_korean']),
      conditions: enumSetFromCsv(UseCondition.values, row['conditions']),
      avoidConditions:
          enumSetFromCsv(AvoidCondition.values, row['avoid_conditions']),
      followUpSuggestion: _optionalString(row['follow_up_suggestion']),
      notes: _optionalString(row['notes']),
      isFavorite: _bool(row['is_favorite']),
      isUserCreated: _bool(row['is_user_created']),
      createdAt: _dateTime(row['created_at']),
      updatedAt: _dateTime(row['updated_at']),
      timesShown: _int(row['times_shown'], 0),
      timesUsed: _int(row['times_used'], 0),
      positiveResults: _int(row['positive_results'], 0),
      neutralResults: _int(row['neutral_results'], 0),
      negativeResults: _int(row['negative_results'], 0),
    );
  }

  /// Reads a translations map from decoded JSON, keeping only string values so
  /// a malformed entry costs one language rather than the whole line.
  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const <String, String>{};
    final out = <String, String>{};
    value.forEach((key, v) {
      if (key is String && v is String) out[key] = v;
    });
    return out;
  }

  /// Reads the translations JSON column, tolerating null and corruption.
  static Map<String, String> _decodeTranslations(Object? value) {
    if (value is! String || value.isEmpty) return const <String, String>{};
    try {
      return _stringMap(jsonDecode(value));
    } on FormatException {
      return const <String, String>{};
    }
  }

  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'OpenerLine($id, "$japaneseText")';

  @override
  bool operator ==(Object other) =>
      other is OpenerLine && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return false;
}

Set<String> _stringSet(Object? value) {
  if (value is! List) return const <String>{};
  return value
      .whereType<String>()
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet();
}

Set<String> _stringSetFromDb(Object? value) {
  if (value is! String || value.trim().isEmpty) return const <String>{};
  return value
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet();
}

bool _ttsFlag(Object? value, String language) {
  if (value is! Map) return true;
  final flag = value[language];
  return flag == null || _bool(flag);
}

/// Parses a timestamp, returning null when absent or unparseable so that the
/// constructor's own default applies.
DateTime? _dateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  return null;
}
