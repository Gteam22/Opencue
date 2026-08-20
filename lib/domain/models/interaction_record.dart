import 'dart:convert';

import '../enums/enums.dart';
import 'context_snapshot.dart';

/// A record that the user used a particular line, and how the interaction
/// went.
///
/// Wording throughout describes the *interaction*, never the other person. The
/// outcomes are positive, neutral, unreceptive and not recorded; there is no
/// notion of a success, a failure or a target anywhere in the model.
class InteractionRecord {
  InteractionRecord({
    required this.id,
    required this.openerLineId,
    this.contextSnapshot,
    DateTime? dateUsed,
    this.outcome = InteractionOutcome.notRecorded,
    this.optionalNotes,
  }) : dateUsed = dateUsed ?? DateTime.now().toUtc();

  final String id;
  final String openerLineId;

  /// The situation the line was used in. Optional so that a user can log a
  /// line from the library without having built a situation first.
  final ContextSnapshot? contextSnapshot;

  final DateTime dateUsed;
  final InteractionOutcome outcome;

  /// A private note. Stays on this device unless the user exports their data.
  final String? optionalNotes;

  InteractionRecord copyWith({
    String? id,
    String? openerLineId,
    ContextSnapshot? contextSnapshot,
    bool clearContextSnapshot = false,
    DateTime? dateUsed,
    InteractionOutcome? outcome,
    String? optionalNotes,
    bool clearOptionalNotes = false,
  }) {
    return InteractionRecord(
      id: id ?? this.id,
      openerLineId: openerLineId ?? this.openerLineId,
      contextSnapshot: clearContextSnapshot
          ? null
          : (contextSnapshot ?? this.contextSnapshot),
      dateUsed: dateUsed ?? this.dateUsed,
      outcome: outcome ?? this.outcome,
      optionalNotes: clearOptionalNotes
          ? null
          : (optionalNotes ?? this.optionalNotes),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'openerLineId': openerLineId,
      'contextSnapshot': contextSnapshot?.toJson(),
      'dateUsed': dateUsed.toUtc().toIso8601String(),
      'outcome': outcome.name,
      'optionalNotes': optionalNotes,
    };
  }

  static InteractionRecord fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final lineId = json['openerLineId'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Interaction is missing a non-empty "id".');
    }
    if (lineId is! String || lineId.trim().isEmpty) {
      throw FormatException('Interaction "$id" is missing "openerLineId".');
    }
    final rawContext = json['contextSnapshot'];
    final rawDate = json['dateUsed'];
    return InteractionRecord(
      id: id,
      openerLineId: lineId,
      contextSnapshot: rawContext is Map<String, Object?>
          ? ContextSnapshot.fromJson(rawContext)
          : null,
      dateUsed: rawDate is String ? DateTime.tryParse(rawDate) : null,
      outcome: enumFromNameOr(
        InteractionOutcome.values,
        json['outcome'],
        InteractionOutcome.notRecorded,
      ),
      optionalNotes: json['optionalNotes'] is String
          ? (json['optionalNotes']! as String)
          : null,
    );
  }

  /// Column map for the `interactions` table.
  ///
  /// The snapshot is stored as a JSON blob rather than as thirteen columns.
  /// It is written once and only ever read back whole, and keeping it opaque
  /// means a future context source can add fields without a migration.
  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'opener_line_id': openerLineId,
      'context_snapshot': contextSnapshot == null
          ? null
          : jsonEncode(contextSnapshot!.toJson()),
      'date_used': dateUsed.toUtc().toIso8601String(),
      'outcome': outcome.name,
      'optional_notes': optionalNotes,
    };
  }

  static InteractionRecord fromDbRow(Map<String, Object?> row) {
    final rawContext = row['context_snapshot'];
    ContextSnapshot? snapshot;
    if (rawContext is String && rawContext.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawContext);
        if (decoded is Map<String, Object?>) {
          snapshot = ContextSnapshot.fromJson(decoded);
        }
      } on FormatException {
        // A corrupt snapshot blob must not make the whole history unreadable.
        snapshot = null;
      }
    }
    final rawDate = row['date_used'];
    return InteractionRecord(
      id: row['id']! as String,
      openerLineId: row['opener_line_id']! as String,
      contextSnapshot: snapshot,
      dateUsed: rawDate is String ? DateTime.tryParse(rawDate) : null,
      outcome: enumFromNameOr(
        InteractionOutcome.values,
        row['outcome'],
        InteractionOutcome.notRecorded,
      ),
      optionalNotes: row['optional_notes'] as String?,
    );
  }

  @override
  String toString() =>
      'InteractionRecord($id, line: $openerLineId, ${outcome.name})';
}
