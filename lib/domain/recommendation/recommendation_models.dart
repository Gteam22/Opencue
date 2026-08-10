import '../enums/enums.dart';
import '../models/opener_line.dart';

/// Which slot a recommendation fills.
enum RecommendationCategory {
  safest,
  playful,
  moreDirect,

  /// Returned in the alternates pool behind "Show another".
  alternative,

  /// A graceful exit line, offered separately from the three main slots.
  gracefulExit,
}

/// A named reason a line's score moved up or down.
///
/// Codes rather than English prose, so the explanation can be localised and
/// asserted on in tests without depending on wording.
enum ScoreFactorCode {
  locationMatch,
  universalLine,
  locationMismatch,
  cueMatch,
  cueNotObserved,
  activityMatch,
  groupSizeMatch,
  groupSizeMismatch,

  /// The line speaks to a specific person, and nobody is in frame.
  personSpecificLineWithNoPeople,

  /// The line acknowledges both people when two are present.
  addressesBothPeople,

  /// The line works whatever the group size, and the group size is unknown.
  groupNeutralWording,
  singlePersonLineWithCompanions,
  noiseMatch,
  noiseNear,
  noiseMismatch,
  shortLineForLoudVenue,
  longLineForLoudVenue,
  directnessAlignment,
  directnessMismatch,
  tonePreference,
  categoryMatch,
  favorite,
  positiveHistory,
  cautiousHistory,
  recentlyShown,
  conversationAlreadyStarted,
}

/// One entry in a score explanation.
class ScoreFactor {
  const ScoreFactor(this.code, this.delta, {this.detail});

  final ScoreFactorCode code;

  /// Points added (positive) or removed (negative).
  final int delta;

  /// Optional extra context, e.g. the specific cue that matched.
  final String? detail;

  bool get isPositive => delta > 0;

  @override
  String toString() =>
      '${code.name}${detail == null ? '' : '($detail)'}: '
      '${delta >= 0 ? '+' : ''}$delta';
}

/// Why a line was removed from consideration entirely.
enum ExclusionReason {
  /// Deliberately available only through explicit library browsing.
  manualOnly,

  /// The line lists an avoid condition that the situation makes true.
  conflictingAvoidCondition,

  /// The line needs a precondition that has not happened, such as eye contact.
  unmetCondition,

  /// Exit lines are never offered as openers.
  exitLine,

  /// The line refers to a cue that is not present in the situation.
  requiredCueNotObserved,

  /// The line is invalid, e.g. blank Japanese text.
  invalidLine,
}

/// A line that did not make the cut, kept for the debug explanation.
class ExcludedLine {
  const ExcludedLine(this.line, this.reason, {this.detail});

  final OpenerLine line;
  final ExclusionReason reason;
  final String? detail;

  @override
  String toString() => '${line.id} excluded: ${reason.name}';
}

/// A line with its score and full explanation.
class ScoredLine {
  const ScoredLine({
    required this.line,
    required this.score,
    required this.factors,
    this.category = RecommendationCategory.alternative,
  });

  final OpenerLine line;
  final int score;
  final List<ScoreFactor> factors;
  final RecommendationCategory category;

  /// The factors that count as "matching reasons" for display on a card.
  List<ScoreFactor> get matchingReasons =>
      factors.where((f) => f.isPositive).toList()
        ..sort((a, b) => b.delta.compareTo(a.delta));

  /// Factors that pushed the line down, for the debug view.
  List<ScoreFactor> get penalties =>
      factors.where((f) => f.delta < 0).toList()
        ..sort((a, b) => a.delta.compareTo(b.delta));

  ScoredLine withCategory(RecommendationCategory category) => ScoredLine(
        line: line,
        score: score,
        factors: factors,
        category: category,
      );

  /// A single-line, human-readable explanation for debugging.
  String get explanation {
    final parts = factors.map((f) => f.toString()).join(', ');
    return '${line.id} = $score [$parts]';
  }

  @override
  String toString() => 'ScoredLine(${line.id}, $score, ${category.name})';
}

/// The "this may not be a good time" verdict.
class ApproachAdvisory {
  const ApproachAdvisory({
    required this.discouraged,
    required this.reasons,
  });

  static const ApproachAdvisory clear =
      ApproachAdvisory(discouraged: false, reasons: <AvoidCondition>[]);

  /// True when the situation contains at least one hard signal against
  /// approaching at all.
  final bool discouraged;

  /// The specific selected conditions that caused the advisory, so the UI can
  /// name them rather than showing a vague warning.
  final List<AvoidCondition> reasons;
}

/// Everything the recommendation screen needs.
class RecommendationResult {
  const RecommendationResult({
    required this.advisory,
    required this.primary,
    required this.alternates,
    required this.exitLines,
    required this.consideredCount,
    required this.excluded,
  });

  final ApproachAdvisory advisory;

  /// Up to three cards: safest, playful, more direct. Empty when the advisory
  /// is raised, because the app does not offer openers for a moment it has
  /// just described as a bad one.
  final List<ScoredLine> primary;

  /// Further candidates, in score order, behind "Show another".
  final List<ScoredLine> alternates;

  /// Graceful exits, always available regardless of the advisory.
  final List<ScoredLine> exitLines;

  /// How many library lines were scored.
  final int consideredCount;

  final List<ExcludedLine> excluded;

  bool get hasRecommendations => primary.isNotEmpty;

  int get excludedCount => excluded.length;

  /// Multi-line debug dump of the whole ranking decision.
  String debugReport() {
    final buffer = StringBuffer()
      ..writeln('advisory: ${advisory.discouraged}'
          '${advisory.reasons.isEmpty ? '' : ' '
              '${advisory.reasons.map((r) => r.name).join(', ')}'}')
      ..writeln('considered: $consideredCount, excluded: ${excluded.length}');
    for (final scored in primary) {
      buffer.writeln('${scored.category.name}: ${scored.explanation}');
    }
    for (final scored in alternates) {
      buffer.writeln('alt: ${scored.explanation}');
    }
    for (final drop in excluded) {
      buffer.writeln('drop: $drop');
    }
    return buffer.toString();
  }
}

/// The user's stated preference for the kind of line they want.
class RecommendationPreferences {
  const RecommendationPreferences({
    this.desiredDirectness = 2,
    this.preferredTones = const <Tone>{},
    this.maxAlternates = 8,
  });

  /// 1 to 5. Lines far from this value are penalised.
  final int desiredDirectness;

  /// Optional tone nudge. Empty means no preference.
  final Set<Tone> preferredTones;

  final int maxAlternates;

  RecommendationPreferences copyWith({
    int? desiredDirectness,
    Set<Tone>? preferredTones,
    int? maxAlternates,
  }) {
    return RecommendationPreferences(
      desiredDirectness:
          clampDirectness(desiredDirectness ?? this.desiredDirectness),
      preferredTones: preferredTones ?? this.preferredTones,
      maxAlternates: maxAlternates ?? this.maxAlternates,
    );
  }
}
