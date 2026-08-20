import '../enums/enums.dart';

/// How much weight to give an inferred field.
///
/// Deliberately a category rather than a raw number in the ordinary interface.
/// A percentage invites the user to read precision that a label-matching
/// heuristic does not have; a word does not. The underlying score is preserved
/// on [FieldConfidence] for the diagnostics screen and for tests.
enum ConfidenceLevel {
  /// Strong, corroborated evidence. May be preselected without a marker.
  high,

  /// Plausible but worth a glance. May be preselected, but marked as such.
  medium,

  /// A suggestion only. Never preselected.
  low,

  /// No usable evidence. The field is left unset.
  unknown;

  /// Whether a field at this level may start out already filled in.
  bool get mayPreselect =>
      this == ConfidenceLevel.high || this == ConfidenceLevel.medium;

  /// Whether the interface should visibly flag this as uncertain.
  bool get needsMarker => this != ConfidenceLevel.high;
}

/// A confidence level plus the score it came from.
class FieldConfidence {
  const FieldConfidence(this.level, {this.score = 0, this.evidence = const []});

  final ConfidenceLevel level;

  /// The accumulated weight behind this inference. Diagnostics only.
  final int score;

  /// The raw labels that contributed, for the diagnostics screen.
  final List<String> evidence;

  static const FieldConfidence unknown =
      FieldConfidence(ConfidenceLevel.unknown);

  /// Thresholds for turning an accumulated weight into a level.
  ///
  /// Set high deliberately. A single matching label is never enough to
  /// preselect anything: `cup` alone should not decide you are in a café,
  /// because a cup is on the table in a restaurant, an office and a train.
  static const int mediumThreshold = 40;
  static const int highThreshold = 75;

  /// Builds a confidence from an accumulated weight.
  factory FieldConfidence.fromScore(
    int score, {
    List<String> evidence = const <String>[],
  }) {
    if (score <= 0) {
      return FieldConfidence(ConfidenceLevel.unknown, evidence: evidence);
    }
    if (score >= highThreshold) {
      return FieldConfidence(
        ConfidenceLevel.high,
        score: score,
        evidence: evidence,
      );
    }
    if (score >= mediumThreshold) {
      return FieldConfidence(
        ConfidenceLevel.medium,
        score: score,
        evidence: evidence,
      );
    }
    return FieldConfidence(
      ConfidenceLevel.low,
      score: score,
      evidence: evidence,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'level': level.name,
        'score': score,
        'evidence': evidence,
      };

  static FieldConfidence fromJson(Map<String, Object?> json) {
    final rawEvidence = json['evidence'];
    return FieldConfidence(
      enumFromNameOr(
        ConfidenceLevel.values,
        json['level'],
        ConfidenceLevel.unknown,
      ),
      score: json['score'] is int ? json['score']! as int : 0,
      evidence: rawEvidence is List
          ? rawEvidence.whereType<String>().toList()
          : const <String>[],
    );
  }

  @override
  String toString() => '${level.name}($score)';
}

/// A single inferred value with its confidence.
class Inferred<T> {
  const Inferred(this.value, this.confidence);

  const Inferred.unknown()
      : value = null,
        confidence = FieldConfidence.unknown;

  /// Null when nothing was inferred. Never guessed to fill a gap.
  final T? value;

  final FieldConfidence confidence;

  /// Whether the confirmation screen should start with this filled in.
  bool get preselect => value != null && confidence.level.mayPreselect;

  ConfidenceLevel get level => confidence.level;
}
