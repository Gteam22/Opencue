import 'confidence.dart';
import 'environmental_observation.dart';
import 'text_evidence.dart';
import 'venue_category.dart';

/// One analyzer's contribution.
class AnalyzerEvidence {
  const AnalyzerEvidence({
    required this.source,
    this.venueScores = const <VenueCategory, int>{},
    this.terms = const <String>[],
    this.placeName,
    this.subtype,
  });

  /// 'labels', 'objects', 'text', 'scene', 'cloud'.
  final String source;

  final Map<VenueCategory, int> venueScores;

  /// What produced the scores, for the explanation.
  final List<String> terms;

  final String? placeName;
  final VenueCategory? subtype;
}

/// Combines evidence from every analyzer into one venue guess.
///
/// Deterministic and weighted. The rule that matters most: a later analyzer
/// never overwrites an earlier one. Everything contributes to a shared score
/// per category, so three weak agreeing signals beat one loud disagreeing one,
/// and a station can be identified from text even when the image labeller has
/// nothing useful to say — which is precisely the case that failed.
class EvidenceFusion {
  const EvidenceFusion();

  /// How much each analyzer's score counts, as a percentage.
  ///
  /// Text outranks generic labels for venue identification because signage is
  /// explicit where labels are inferential: 番線 means a platform, whereas
  /// 'metal' means nothing. Scene classification, when present, outranks both
  /// for the same reason a purpose-built model outranks a generic one.
  static const Map<String, int> sourceWeight = <String, int>{
    'text': 130,
    'scene': 120,
    'objects': 100,
    'labels': 70,
    'cloud': 140,
    'quality': 0,
  };

  /// Categories that reinforce rather than contradict each other.
  ///
  /// Without this, 'platform' from text and 'station' from labels would look
  /// like disagreement and damp each other, when they are the same answer at
  /// two levels of detail.
  static int _affinity(VenueCategory a, VenueCategory b) {
    if (a == b) return 100;
    if (a.parent == b || b.parent == a) return 85;
    final family = a.family;
    if (family != null && family == b.family) return 60;
    return 0;
  }

  FusionResult fuse({
    required List<AnalyzerEvidence> evidence,
    TextTransitEvidence textEvidence = TextTransitEvidence.none,
    int frameAgreement = 1,
    int frameCount = 1,
  }) {
    final totals = <VenueCategory, int>{};
    final contributions = <VenueCategory, List<String>>{};

    for (final item in evidence) {
      final weight = sourceWeight[item.source] ?? 100;
      item.venueScores.forEach((category, raw) {
        final weighted = (raw * weight / 100).round();
        totals[category] = (totals[category] ?? 0) + weighted;
        contributions
            .putIfAbsent(category, () => <String>[])
            .add('${item.source}:$raw');
      });
    }

    // Related categories lend each other support.
    final reinforced = <VenueCategory, int>{};
    totals.forEach((category, score) {
      var total = score;
      totals.forEach((other, otherScore) {
        if (identical(category, other) || category == other) return;
        final affinity = _affinity(category, other);
        if (affinity > 0) {
          total += (otherScore * affinity / 100 * 0.35).round();
        }
      });
      reinforced[category] = total;
    });

    if (reinforced.isEmpty) {
      return const FusionResult(
        guess: VenueGuess.unknown(),
        confidence: FieldConfidence.unknown,
        explanation: 'No analyzer produced usable venue evidence.',
        scores: <VenueCategory, int>{},
      );
    }

    final ranked = reinforced.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        return byScore != 0 ? byScore : a.key.name.compareTo(b.key.name);
      });

    final winner = ranked.first;
    var score = winner.value;

    // Agreement across frames strengthens; disagreement weakens.
    if (frameCount > 1) {
      final ratio = frameAgreement / frameCount;
      score = (score * (0.75 + 0.25 * ratio)).round();
    }

    // A close runner-up from an *unrelated* category is real disagreement and
    // must be damped. A close runner-up that is a sibling transit category is
    // not - it is the same answer, and picking either is fine.
    var contested = false;
    if (ranked.length > 1) {
      final runnerUp = ranked[1];
      final related = _affinity(winner.key, runnerUp.key) > 0;
      if (!related && runnerUp.value >= winner.value * 0.85) {
        score = (score * 0.6).round();
        contested = true;
      }
    }

    // Text can settle a subtype and a place name that nothing else can.
    final subtype = TextEvidence.subtypeFromText(textEvidence);
    final placeName = evidence
        .map((e) => e.placeName)
        .firstWhere((name) => name != null, orElse: () => null);

    final category = _refine(winner.key, subtype);

    return FusionResult(
      guess: VenueGuess(
        category: category,
        subtype: subtype?.name,
        possiblePlaceName: placeName,
        placeNameFromText: placeName != null,
      ),
      confidence: FieldConfidence.fromScore(
        score,
        evidence: contributions[winner.key] ?? const <String>[],
      ),
      explanation: _explain(
        winner.key,
        contributions[winner.key] ?? const <String>[],
        textEvidence,
        contested: contested,
      ),
      scores: reinforced,
      contested: contested,
    );
  }

  /// Prefers the more specific of two compatible categories.
  static VenueCategory _refine(VenueCategory base, VenueCategory? subtype) {
    if (subtype == null) return base;
    if (_affinity(base, subtype) >= 60) return subtype;
    return base;
  }

  static String _explain(
    VenueCategory category,
    List<String> contributions,
    TextTransitEvidence text, {
    required bool contested,
  }) {
    if (contested) {
      return 'Uncertain: analyzers disagreed. Best guess ${category.name}.';
    }
    final parts = <String>[];
    if (text.score > 0) {
      parts.add('text contained ${text.terms.take(4).join(", ")}');
    }
    if (contributions.isNotEmpty) {
      parts.add(contributions.join(", "));
    }
    return '${category.name}: ${parts.join("; ")}.';
  }
}

/// The fused answer plus why.
class FusionResult {
  const FusionResult({
    required this.guess,
    required this.confidence,
    required this.explanation,
    required this.scores,
    this.contested = false,
  });

  final VenueGuess guess;
  final FieldConfidence confidence;

  /// A short internal sentence, shown in full only in developer mode.
  final String explanation;

  final Map<VenueCategory, int> scores;

  /// True when two unrelated categories scored closely, so the user should
  /// be asked rather than told.
  final bool contested;

  /// Whether this is good enough to skip the confirmation step.
  bool get isHighConfidence =>
      confidence.level == ConfidenceLevel.high && !contested;

  /// Whether one tap of confirmation is enough.
  bool get isMediumConfidence =>
      confidence.level == ConfidenceLevel.medium || contested;
}

/// Maps raw analyzer vocabulary onto canonical terms.
///
/// The original pipeline matched label strings exactly, against a vocabulary
/// the model does not emit. This is the fix: analyzers speak their own
/// dialects, and everything is folded to canonical terms before scoring.
class SynonymTable {
  const SynonymTable._();

  /// canonical term -> everything that means it.
  static const Map<String, Set<String>> _synonyms = <String, Set<String>>{
    'train': <String>{
      'train',
      'locomotive',
      'railcar',
      'rail car',
      'subway train',
      'metro train',
      'tram',
      'railway',
      'rail',
      'rolling stock',
      '電車',
      '列車',
    },
    'platform': <String>{
      'platform',
      'railway platform',
      'train platform',
      'ホーム',
      '番線',
    },
    'ticket_gate': <String>{
      'ticket gate',
      'turnstile',
      'fare gate',
      'ticket barrier',
      '改札',
    },
    'transit_sign': <String>{
      'transit map',
      'route map',
      'station sign',
      'timetable',
      'departure board',
      '時刻表',
      '路線図',
    },
    'escalator': <String>{'escalator', 'moving staircase', 'travelator'},
    'handrail': <String>{
      'handrail',
      'hand strap',
      'grab handle',
      'strap',
      'つり革',
    },
    'vehicle_interior': <String>{
      'vehicle interior',
      'bus interior',
      'train interior',
      'cabin',
    },
    'coffee': <String>{'coffee', 'espresso', 'latte', 'cappuccino', 'コーヒー'},
    'cup': <String>{'cup', 'mug', 'tumbler', 'glass'},
    'beer': <String>{'beer', 'ale', 'lager', 'draught', 'ビール'},
    'book': <String>{'book', 'novel', 'paperback', 'magazine', '本'},
    'bookshelf': <String>{'bookshelf', 'bookcase', 'shelf', 'shelving'},
    'dog': <String>{'dog', 'puppy', 'canine'},
    'umbrella': <String>{'umbrella', 'parasol', '傘'},
    'gym_equipment': <String>{
      'dumbbell',
      'barbell',
      'treadmill',
      'exercise equipment',
      'weight',
    },
  };

  /// The canonical term for a raw label, or the label itself if unmapped.
  static String canonical(String raw) {
    final key = raw.trim().toLowerCase();
    for (final entry in _synonyms.entries) {
      if (entry.value.contains(key)) return entry.key;
    }
    return key;
  }

  /// Canonical terms for a whole set of labels, de-duplicated.
  static List<ScoredLabel> canonicalize(List<ScoredLabel> labels) {
    final best = <String, ScoredLabel>{};
    for (final label in labels) {
      final key = canonical(label.text);
      final existing = best[key];
      if (existing == null || label.confidence > existing.confidence) {
        best[key] = ScoredLabel(
          key,
          label.confidence,
          frameIndex: label.frameIndex,
        );
      }
    }
    return best.values.toList();
  }
}
