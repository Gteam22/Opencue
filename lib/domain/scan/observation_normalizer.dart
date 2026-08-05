import '../enums/enums.dart';
import 'confidence.dart';
import 'environmental_observation.dart';
import 'scan_heuristics.dart';

/// Turns raw analyser labels into the app's controlled vocabulary.
///
/// Pure Dart, no Flutter, no ML package, no I/O. It takes labels and returns
/// an [EnvironmentalObservation], which is what makes every heuristic in
/// ScanHeuristics directly testable without a camera or a model.
///
/// Two properties this class is responsible for:
///
/// 1. Nothing in [ScanHeuristics.neverInferred] is ever produced, whatever the
///    labels contain. Enforced below and asserted in the tests.
/// 2. Weak evidence stays weak. A field with a low total is returned as a
///    suggestion at low confidence, never promoted to fill a gap, and never
///    silently written into a ContextSnapshot.
class ObservationNormalizer {
  const ObservationNormalizer();

  /// Labels below this model confidence are ignored entirely.
  ///
  /// ML Kit returns a long tail of low-scoring guesses; feeding them in makes
  /// every scan look like a busy café.
  static const double minimumLabelConfidence = 0.55;

  /// How much a label's own confidence can scale its rule weight.
  ///
  /// A label the model is 0.9 sure of counts for more than one it is 0.6 sure
  /// of, but the rule weight still dominates, so a strong rule on a hesitant
  /// label beats a weak rule on a confident one.
  static int _scaled(int weight, double labelConfidence) =>
      (weight * (0.6 + 0.4 * labelConfidence)).round();

  /// Builds an observation from the labels of one or more frames.
  EnvironmentalObservation normalize({
    required String id,
    required List<ScoredLabel> labels,
    required FrameSourceKind source,
    required DateTime capturedAt,
    int frameCount = 1,
    Duration processingDuration = Duration.zero,
    String modelInformation = '',
  }) {
    final usable = labels
        .where((l) => l.confidence >= minimumLabelConfidence)
        .where((l) => !ScanHeuristics.isStopLabel(l.text))
        .toList();

    final warnings = <String>[];

    final locationScores = _score(usable, ScanHeuristics.locationRules);
    // Cosplay is capped rather than excluded: costume-like labels fire on
    // uniforms, mascots and mannequins often enough that a confident answer
    // would frequently be wrong.
    if (locationScores.containsKey(LocationTag.cosplayEvent)) {
      locationScores[LocationTag.cosplayEvent] = _capped(
        locationScores[LocationTag.cosplayEvent]!,
        ScanHeuristics.cosplayConfidenceCeiling,
      );
    }

    final activityScores = _score(usable, ScanHeuristics.activityRules);
    final cueScores = _score(usable, ScanHeuristics.cueRules);

    // Rule 1: the person-judgement cues can never be produced. Removed after
    // scoring as well as being absent from the rules, so that a rule added
    // later by mistake still cannot leak one through.
    for (final blocked in ScanHeuristics.neverInferred) {
      cueScores.remove(blocked);
    }

    final location = _best(
      locationScores,
      usable,
      ScanHeuristics.locationRules,
    );
    final activity = _best(
      activityScores,
      usable,
      ScanHeuristics.activityRules,
    );

    // Recognising *labels* is not the same as recognising a *place*: a photo
    // of a blank wall returns plenty of labels, none of which map to anything.
    // The warning has to key off whether any rule matched, not off whether the
    // model said something.
    if (locationScores.isEmpty &&
        activityScores.isEmpty &&
        cueScores.isEmpty) {
      warnings.add('scan.warning.nothingRecognised');
    } else if (location.value != null &&
        location.level == ConfidenceLevel.low) {
      warnings.add('scan.warning.locationUncertain');
    }

    // Noise is derived from the location rather than from the image, and only
    // when the location itself is solid. A photograph cannot hear a room.
    var noise = const Inferred<NoiseLevel>.unknown();
    final locationValue = location.value;
    if (locationValue != null && location.confidence.level.mayPreselect) {
      final suggested = ScanHeuristics.noiseByLocation[locationValue];
      if (suggested != null) {
        noise = Inferred<NoiseLevel>(
          suggested,
          // One step below the location it was derived from: it is an
          // inference about an inference.
          FieldConfidence(
            location.level == ConfidenceLevel.high
                ? ConfidenceLevel.medium
                : ConfidenceLevel.low,
            score: location.confidence.score,
            evidence: <String>['derived:${locationValue.name}'],
          ),
        );
      }
    }

    final cues = <ObservableCue, FieldConfidence>{};
    cueScores.forEach((cue, score) {
      final confidence = FieldConfidence.fromScore(
        score,
        evidence: _evidenceFor(usable, ScanHeuristics.cueRules[cue]),
      );
      if (confidence.level != ConfidenceLevel.unknown) {
        cues[cue] = confidence;
      }
    });

    return EnvironmentalObservation(
      id: id,
      capturedAt: capturedAt,
      source: source,
      detectedLabels: usable,
      location: location,
      activity: activity,
      noiseLevel: noise,
      observableCues: cues,
      warnings: warnings,
      processingDuration: processingDuration,
      frameCount: frameCount,
      modelInformation: modelInformation,
    );
  }

  /// Merges the observations from several frames of one capture.
  ///
  /// Consensus, not sum: a label present in two of three frames is much better
  /// evidence than one seen once, and averaging by frame count stops a single
  /// misread frame from carrying the result. This is what makes the burst
  /// capture worth doing at all.
  EnvironmentalObservation mergeFrames({
    required String id,
    required List<List<ScoredLabel>> perFrameLabels,
    required FrameSourceKind source,
    required DateTime capturedAt,
    Duration processingDuration = Duration.zero,
    String modelInformation = '',
  }) {
    if (perFrameLabels.isEmpty) {
      return normalize(
        id: id,
        labels: const <ScoredLabel>[],
        source: source,
        capturedAt: capturedAt,
        frameCount: 0,
        processingDuration: processingDuration,
        modelInformation: modelInformation,
      );
    }

    final frameCount = perFrameLabels.length;
    // Best confidence per label, and how many frames it appeared in.
    final best = <String, ScoredLabel>{};
    final appearances = <String, int>{};

    for (var index = 0; index < frameCount; index++) {
      final seen = <String>{};
      for (final label in perFrameLabels[index]) {
        final key = label.text.trim().toLowerCase();
        if (key.isEmpty) continue;
        if (seen.add(key)) {
          appearances[key] = (appearances[key] ?? 0) + 1;
        }
        final current = best[key];
        if (current == null || label.confidence > current.confidence) {
          best[key] = ScoredLabel(key, label.confidence, frameIndex: index);
        }
      }
    }

    // A label seen in every frame keeps its confidence; one seen in a single
    // frame of three is damped towards a suggestion.
    final merged = <ScoredLabel>[];
    best.forEach((key, label) {
      final ratio = (appearances[key] ?? 1) / frameCount;
      final consensus = 0.55 + 0.45 * ratio;
      merged.add(
        ScoredLabel(
          key,
          (label.confidence * consensus).clamp(0.0, 1.0),
          frameIndex: label.frameIndex,
        ),
      );
    });

    return normalize(
      id: id,
      labels: merged,
      source: source,
      capturedAt: capturedAt,
      frameCount: frameCount,
      processingDuration: processingDuration,
      modelInformation: modelInformation,
    );
  }

  Map<T, int> _score<T extends Enum>(
    List<ScoredLabel> labels,
    Map<T, Map<String, int>> rules,
  ) {
    final totals = <T, int>{};
    for (final label in labels) {
      final key = label.text.trim().toLowerCase();
      rules.forEach((candidate, ruleset) {
        final weight = ruleset[key];
        if (weight == null) return;
        totals[candidate] =
            (totals[candidate] ?? 0) + _scaled(weight, label.confidence);
      });
    }
    return totals;
  }

  /// The highest-scoring candidate, or unknown when nothing scored.
  ///
  /// A near-tie is demoted: if the runner-up is close behind, the evidence
  /// does not actually distinguish them, and saying "likely bar" when it was
  /// nearly "likely café" would be overclaiming.
  Inferred<T> _best<T extends Enum>(
    Map<T, int> scores,
    List<ScoredLabel> labels,
    Map<T, Map<String, int>> rules,
  ) {
    if (scores.isEmpty) return Inferred<T>.unknown();
    final ranked = scores.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        // Ties break on name so the result is deterministic.
        return byScore != 0 ? byScore : a.key.name.compareTo(b.key.name);
      });

    final winner = ranked.first;
    var score = winner.value;
    if (ranked.length > 1) {
      final runnerUp = ranked[1].value;
      if (runnerUp > 0 && runnerUp >= winner.value * 0.8) {
        score = (score * 0.7).round();
      }
    }

    return Inferred<T>(
      winner.key,
      FieldConfidence.fromScore(
        score,
        evidence: _evidenceFor(labels, rules[winner.key]),
      ),
    );
  }

  int _capped(int score, int ceiling) => score > ceiling ? ceiling : score;

  List<String> _evidenceFor(
    List<ScoredLabel> labels,
    Map<String, int>? ruleset,
  ) {
    if (ruleset == null) return const <String>[];
    return labels
        .map((l) => l.text.trim().toLowerCase())
        .where(ruleset.containsKey)
        .toSet()
        .toList()
      ..sort();
  }
}
