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
    this.category = LineCategory.universal,
    Set<LocationTag>? locations,
    Set<ActivityTag>? activities,
    Set<ObservableCue>? observableCues,
    Set<GroupSize>? groupSizes,
    Set<NoiseLevel>? noiseLevels,
    Set<Tone>? tones,
    int directness = 2,
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
  })  : locations = Set.unmodifiable(locations ?? const <LocationTag>{}),
        activities = Set.unmodifiable(activities ?? const <ActivityTag>{}),
        observableCues =
            Set.unmodifiable(observableCues ?? const <ObservableCue>{}),
        groupSizes = Set.unmodifiable(groupSizes ?? const <GroupSize>{}),
        noiseLevels = Set.unmodifiable(noiseLevels ?? const <NoiseLevel>{}),
        tones = Set.unmodifiable(tones ?? const <Tone>{Tone.friendly}),
        directness = clampDirectness(directness),
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
    return errors;
  }

  bool get isValid => validationErrors().isEmpty;

  OpenerLine copyWith({
    String? id,
    String? japaneseText,
    String? englishMeaning,
    bool clearEnglishMeaning = false,
    LineCategory? category,
    Set<LocationTag>? locations,
    Set<ActivityTag>? activities,
    Set<ObservableCue>? observableCues,
    Set<GroupSize>? groupSizes,
    Set<NoiseLevel>? noiseLevels,
    Set<Tone>? tones,
    int? directness,
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
      category: category ?? this.category,
      locations: locations ?? this.locations,
      activities: activities ?? this.activities,
      observableCues: observableCues ?? this.observableCues,
      groupSizes: groupSizes ?? this.groupSizes,
      noiseLevels: noiseLevels ?? this.noiseLevels,
      tones: tones ?? this.tones,
      directness: directness ?? this.directness,
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
      'category': category.name,
      'locations': enumSetToJson(locations),
      'activities': enumSetToJson(activities),
      'observableCues': enumSetToJson(observableCues),
      'groupSizes': enumSetToJson(groupSizes),
      'noiseLevels': enumSetToJson(noiseLevels),
      'tones': enumSetToJson(tones),
      'directness': directness,
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
      'category': category.name,
      'locations': enumSetToCsv(locations),
      'activities': enumSetToCsv(activities),
      'observable_cues': enumSetToCsv(observableCues),
      'group_sizes': enumSetToCsv(groupSizes),
      'noise_levels': enumSetToCsv(noiseLevels),
      'tones': enumSetToCsv(tones),
      'directness': directness,
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
