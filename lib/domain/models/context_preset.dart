import 'dart:convert';

import '../context/context_draft.dart';

/// A named context the user can reapply in one tap.
///
/// The brief lists eight example presets — café/one person/quiet, bar/two
/// people, subway platform/waiting, and so on. Those ship as *starter*
/// presets, marked [isStarter], and are ordinary rows the user may reorder,
/// rename or delete like any other. Nothing about the preset system is
/// hard-coded to that list.
///
/// The context itself is stored as one JSON blob, the same choice
/// `interactions.context_snapshot` makes, so a field added to [ContextDraft]
/// later needs no database migration.
class ContextPreset {
  ContextPreset({
    required this.id,
    required this.name,
    required this.draft,
    this.isFavorite = false,
    this.isStarter = false,
    this.sortOrder = 0,
    DateTime? createdAt,
    this.lastUsedAt,
    this.timesUsed = 0,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String id;

  /// The user's own name for it. Starter presets carry a localization key
  /// instead; see [isStarter] and [resolveName].
  final String name;

  final ContextDraft draft;

  final bool isFavorite;

  /// True for the presets seeded on first run. Their [name] is a
  /// localization key such as `preset.starter.cafeQuiet`, so they follow the
  /// interface language; a user-created preset's name is literal text and is
  /// shown as typed.
  final bool isStarter;

  /// Position in the list. Lower sorts first. Favourites are grouped ahead of
  /// non-favourites by the repository's ordering, not by this value.
  final int sortOrder;

  final DateTime createdAt;

  /// When the preset was last applied, for the "recent contexts" list.
  final DateTime? lastUsedAt;

  final int timesUsed;

  /// Whether [name] should be run through the localization table.
  bool get nameIsLocalizationKey => isStarter;

  ContextPreset copyWith({
    String? id,
    String? name,
    ContextDraft? draft,
    bool? isFavorite,
    bool? isStarter,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    bool clearLastUsedAt = false,
    int? timesUsed,
  }) {
    return ContextPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      draft: draft ?? this.draft,
      isFavorite: isFavorite ?? this.isFavorite,
      isStarter: isStarter ?? this.isStarter,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }

  /// Marks the preset as just applied.
  ContextPreset markUsed({DateTime? at}) => copyWith(
        lastUsedAt: at ?? DateTime.now().toUtc(),
        timesUsed: timesUsed + 1,
      );

  /// Problems that make this preset unusable. Empty means valid.
  List<String> validationErrors() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('preset.error.emptyId');
    if (name.trim().isEmpty) errors.add('preset.error.emptyName');
    if (sortOrder < 0) errors.add('preset.error.negativeOrder');
    return errors;
  }

  Map<String, Object?> toDbRow() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'draft': jsonEncode(draft.toJson()),
      'is_favorite': isFavorite ? 1 : 0,
      'is_starter': isStarter ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toUtc().toIso8601String(),
      'last_used_at': lastUsedAt?.toUtc().toIso8601String(),
      'times_used': timesUsed,
    };
  }

  /// Reads a row. A corrupt draft blob costs that preset its context rather
  /// than breaking the presets list, matching how a corrupt context snapshot
  /// is handled on the history screen.
  static ContextPreset fromDbRow(Map<String, Object?> row) {
    ContextDraft draft;
    try {
      final raw = row['draft'];
      final decoded = raw is String ? jsonDecode(raw) : null;
      draft = decoded is Map<String, Object?>
          ? ContextDraft.fromJson(decoded)
          : ContextDraft.empty();
    } on FormatException {
      draft = ContextDraft.empty();
    }
    final lastUsed = row['last_used_at'];
    return ContextPreset(
      id: row['id']! as String,
      name: (row['name'] as String?) ?? '',
      draft: draft,
      isFavorite: (row['is_favorite'] as int? ?? 0) == 1,
      isStarter: (row['is_starter'] as int? ?? 0) == 1,
      sortOrder: row['sort_order'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      lastUsedAt:
          lastUsed is String ? DateTime.tryParse(lastUsed)?.toUtc() : null,
      timesUsed: row['times_used'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'ContextPreset($id, "$name", starter: $isStarter)';
}
