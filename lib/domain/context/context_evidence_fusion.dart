library;

import '../enums/enums.dart';
import '../models/context_snapshot.dart';
import '../scan/confidence.dart';
import '../scan/venue_category.dart';
import 'context_draft.dart';
import 'radial_menu_tree.dart';
import 'signals/audio_environment_signal.dart';
import 'signals/context_signal.dart';
import 'signals/location_signal.dart';
import 'signals/nearby_place_signal.dart';

/// Everything known about the environment at one moment.
class ContextEvidenceBundle {
  ContextEvidenceBundle({
    required this.capturedAt,
    this.location,
    this.nearbyPlaces,
    this.audio,
    this.cameraVenue,
    this.cameraGroupSize,
    this.cameraConfidence = FieldConfidence.unknown,
    this.recentConfirmedContext,
    this.recentConfirmedAt,
    this.userCorrectedDraft,
  });

  final DateTime capturedAt;
  final LocationSignal? location;
  final NearbyPlaceSignal? nearbyPlaces;
  final AudioEnvironmentSignal? audio;

  /// Camera evidence, already normalized by the existing scan pipeline. Held
  /// as plain values rather than as the scan's own result type so that fusion
  /// does not depend on the camera layer.
  final VenueCategory? cameraVenue;

  /// **The only source of group size.** Never derived from GPS or audio: a
  /// coordinate and a sound level say nothing about how many people are
  /// present, and inferring it would be a fabrication dressed as a measurement.
  final GroupSize? cameraGroupSize;

  final FieldConfidence cameraConfidence;

  /// A context the user previously confirmed, replayed as evidence.
  final ContextSnapshot? recentConfirmedContext;
  final DateTime? recentConfirmedAt;

  /// A draft the user has explicitly edited. Outranks every automatic signal.
  final ContextDraft? userCorrectedDraft;

  /// Whether the confirmed context is recent enough to still describe reality.
  bool confirmedContextIsCurrent(Duration freshness) {
    final at = recentConfirmedAt;
    if (at == null || recentConfirmedContext == null) return false;
    return capturedAt.difference(at) <= freshness;
  }

  /// The signals that actually produced evidence, for diagnostics.
  List<ContextSignal> get usableSignals => <ContextSignal>[
        if (location?.isUsable ?? false) location!,
        if (nearbyPlaces?.isUsable ?? false) nearbyPlaces!,
        if (audio?.isUsable ?? false) audio!,
      ];
}

/// Why fusion reached the answer it did, for diagnostics and for tests.
enum FusionReason {
  userCorrection,
  recentConfirmedContext,
  cameraScan,
  nearbyPlaceWithPreciseFix,
  placeAndAudioAgree,
  audioOnly,
  weakPlaceCandidate,
  vehicleMotion,
  noUsableEvidence,
}

/// One weighted contribution, so the whole score can be shown and asserted.
class FusionFactor {
  const FusionFactor(this.code, this.delta, {this.detail});

  /// A code, not a sentence: the UI localizes it.
  final String code;
  final int delta;
  final String? detail;

  @override
  String toString() => '$code${detail == null ? '' : '($detail)'}: '
      '${delta >= 0 ? '+' : ''}$delta';
}

/// The outcome of fusing a bundle.
class FusedContextResult {
  FusedContextResult({
    required this.draft,
    required this.confidence,
    required this.reason,
    List<FusionFactor>? factors,
    List<LocationTag>? alternativeLocations,
    List<String>? warnings,
    this.placeName,
  })  : factors = List.unmodifiable(factors ?? const <FusionFactor>[]),
        alternativeLocations =
            List.unmodifiable(alternativeLocations ?? const <LocationTag>[]),
        warnings = List.unmodifiable(warnings ?? const <String>[]);

  /// The draft the radial menu, the detailed editor and the engine all read.
  /// Per-field provenance lives on it, so no field is reduced to one ambiguous
  /// source string.
  final ContextDraft draft;

  final FieldConfidence confidence;
  final FusionReason reason;
  final List<FusionFactor> factors;

  /// Other plausible locations, ranked. Shown as one-tap corrections when
  /// confidence is medium, rather than hidden behind a form.
  final List<LocationTag> alternativeLocations;

  final List<String> warnings;

  /// A specific venue name, only when confidence is high and the user has not
  /// turned place names off. Never persisted by default.
  final String? placeName;

  /// Whether recommendations may be shown without asking.
  bool get mayShowRecommendationsDirectly =>
      confidence.level == ConfidenceLevel.high;

  /// Whether to offer a short list of choices rather than a single answer.
  bool get shouldOfferQuickCorrection =>
      confidence.level == ConfidenceLevel.medium;

  /// Whether to fall back to the radial menu with partial evidence preselected.
  bool get shouldOpenRadialMenu =>
      confidence.level == ConfidenceLevel.low ||
      confidence.level == ConfidenceLevel.unknown;

  String debugReport() {
    final lines = <String>[
      'FusedContextResult',
      '  location:   ${draft.location.name}',
      '  venue:      ${draft.venue?.name ?? "-"}',
      '  activity:   ${draft.activity?.name ?? "-"}',
      '  groupSize:  ${draft.groupSize.name}',
      '  noise:      ${draft.noiseLevel.name}',
      '  cues:       ${draft.cues.map((c) => c.name).join(", ")}',
      '  confidence: ${confidence.level.name} (${confidence.score})',
      '  reason:     ${reason.name}',
      if (alternativeLocations.isNotEmpty)
        '  alternatives: ${alternativeLocations.map((l) => l.name).join(", ")}',
      if (warnings.isNotEmpty) '  warnings:   ${warnings.join(", ")}',
      '  factors:',
      for (final factor in factors) '    $factor',
    ];
    return lines.join('\n');
  }
}

/// Combines location, place, audio and camera evidence into one draft.
///
/// Deterministic and pure: no I/O, no clock of its own, no platform. Given the
/// same bundle it returns the same result, which is what makes the seven cases
/// the brief names into ordinary unit tests.
///
/// The weights are named constants at the top so the ordering of evidence is
/// visible rather than buried in branches.
class ContextEvidenceFusionService {
  const ContextEvidenceFusionService({
    this.confirmedContextFreshness = const Duration(minutes: 5),
  });

  /// How long a confirmed context keeps describing reality.
  final Duration confirmedContextFreshness;

  // --- Weights -------------------------------------------------------------
  //
  // Place evidence outweighs audio by roughly three to one, deliberately. A
  // GPS fix eighteen metres from a station entrance is a measurement; a train
  // sound is a hint that fits a platform, a carriage, a level crossing and a
  // café next to a railway line.

  /// A mapped candidate inside the plausible radius of a precise fix.
  static const int kPlacePreciseAndInside = 60;

  /// A mapped candidate from a fix good enough to trust, but not inside it.
  static const int kPlacePreciseNearby = 35;

  /// A candidate from an approximate or stale fix.
  static const int kPlaceApproximate = 18;

  /// Audio agreeing with the leading place candidate.
  static const int kAudioAgreesWithPlace = 25;

  /// Audio disagreeing with it. A penalty, never a veto.
  static const int kAudioContradictsPlace = -12;

  /// The strongest camera evidence, which sees the room itself.
  static const int kCameraStrong = 70;
  static const int kCameraWeak = 25;

  /// A still-current confirmed context.
  static const int kConfirmedContext = 85;

  /// Vehicle motion, which turns a station into a carriage.
  static const int kVehicleMotion = 30;

  /// Time of day. A tie-breaker and nothing more: the brief is explicit that
  /// evening must not by itself imply a bar, so this is small enough that it
  /// can only reorder candidates that are already level.
  static const int kTimeOfDayPrior = 6;

  /// Fuses a bundle.
  FusedContextResult fuse(ContextEvidenceBundle evidence) {
    // 1. An explicit user correction ends the discussion. Nothing automatic
    //    may overwrite what the person in the room has said.
    final corrected = evidence.userCorrectedDraft;
    if (corrected != null) {
      return FusedContextResult(
        draft: corrected,
        confidence: const FieldConfidence(ConfidenceLevel.high),
        reason: FusionReason.userCorrection,
        factors: const <FusionFactor>[
          FusionFactor('fusion.userCorrection', kConfirmedContext),
        ],
      );
    }

    // 2. A confirmed context that is still current. Reusing it is also what
    //    keeps the microphone off: there is nothing to detect.
    if (evidence.confirmedContextIsCurrent(confirmedContextFreshness)) {
      final snapshot = evidence.recentConfirmedContext!;
      return FusedContextResult(
        draft: ContextDraft.fromSnapshot(
          snapshot,
          origin: DraftOrigin.fromPreset,
        ),
        confidence: const FieldConfidence(ConfidenceLevel.high),
        reason: FusionReason.recentConfirmedContext,
        factors: const <FusionFactor>[
          FusionFactor('fusion.recentConfirmed', kConfirmedContext),
        ],
      );
    }

    final factors = <FusionFactor>[];
    final warnings = <String>[];
    final scores = <LocationTag, int>{};

    void addScore(LocationTag tag, int weight, String code, {String? detail}) {
      if (weight == 0) return;
      scores[tag] = (scores[tag] ?? 0) + weight;
      factors.add(FusionFactor(code, weight, detail: detail ?? tag.name));
    }

    final location = evidence.location;
    final places = evidence.nearbyPlaces;
    final audio = evidence.audio;

    // --- Place evidence ----------------------------------------------------
    NearbyPlaceCandidate? leadingCandidate;
    LocationTag? leadingPlaceTag;

    if (places != null && places.isUsable && places.candidates.isNotEmpty) {
      final ranked = location == null
          ? places.candidates
          : PlaceTypeMapping.rank(places.candidates, location);

      for (var index = 0; index < ranked.length && index < 4; index++) {
        final candidate = ranked[index];
        final tag = PlaceTypeMapping.toLocationTag(candidate.primaryType);
        if (tag == null) continue;

        final int weight;
        final String code;
        if (location != null &&
            location.isVenuePrecise &&
            candidate.isWithinVenueRadius(location.accuracyMeters)) {
          weight = kPlacePreciseAndInside;
          code = 'fusion.placeInsideRadius';
        } else if (location != null && location.isVenuePrecise) {
          weight = kPlacePreciseNearby;
          code = 'fusion.placeNearby';
        } else {
          weight = kPlaceApproximate;
          code = 'fusion.placeApproximate';
        }

        // Candidates after the first are attenuated, so a list of neighbours
        // produces several close scores rather than one runaway winner.
        final attenuated = index == 0 ? weight : (weight * 0.55).round();
        addScore(tag, attenuated, code);

        leadingCandidate ??= candidate;
        leadingPlaceTag ??= tag;
      }

      if (places.isContested) {
        warnings.add('fusion.warning.severalPlausiblePlaces');
      }
    } else if (places != null && !places.isUsable) {
      warnings.add('fusion.warning.placesUnavailable');
      if (places.metadata.unavailableReason ==
          SignalUnavailableReason.notConfigured) {
        warnings.add('fusion.warning.placesNotConfigured');
      }
    }

    // --- Audio evidence ----------------------------------------------------
    final audioAffinities = <LocationTag, int>{};
    if (audio != null && audio.isUsable && audio.sampleWasUsable) {
      audioAffinities.addAll(
        SoundCueMapping.locationAffinities(audio.soundCues),
      );
      for (final entry in audioAffinities.entries) {
        addScore(entry.key, entry.value, 'fusion.audioAffinity');
      }

      // Corroboration bonus, or a penalty when audio points elsewhere.
      if (leadingPlaceTag != null) {
        if (audioAffinities.containsKey(leadingPlaceTag)) {
          addScore(leadingPlaceTag, kAudioAgreesWithPlace,
              'fusion.audioAgreesWithPlace');
        } else if (audioAffinities.isNotEmpty) {
          addScore(leadingPlaceTag, kAudioContradictsPlace,
              'fusion.audioContradictsPlace');
          warnings.add('fusion.warning.audioDisagreesWithPlace');
        }
      }
    } else if (audio != null && !audio.sampleWasUsable) {
      warnings.add('fusion.warning.audioUnusable');
    }

    // --- Camera evidence ---------------------------------------------------
    final cameraTag = evidence.cameraVenue?.toLocationTag();
    if (cameraTag != null) {
      final weight = evidence.cameraConfidence.level == ConfidenceLevel.high
          ? kCameraStrong
          : kCameraWeak;
      addScore(cameraTag, weight, 'fusion.cameraScan');
    }

    // --- Vehicle motion ----------------------------------------------------
    //
    // A station and a carriage sound almost identical. Speed is what separates
    // them, and it is a physical measurement rather than an inference, so it
    // is allowed to move the answer.
    var inVehicle = false;
    if (location != null && location.appearsInVehicle) {
      inVehicle = true;
      addScore(LocationTag.publicTransport, kVehicleMotion,
          'fusion.vehicleMotion');
      if (scores.containsKey(LocationTag.trainStation)) {
        addScore(LocationTag.trainStation, -kVehicleMotion,
            'fusion.movingPastStation');
      }
    }

    // --- Nothing to go on --------------------------------------------------
    if (scores.isEmpty) {
      return FusedContextResult(
        draft: ContextDraft.empty(),
        confidence: const FieldConfidence(ConfidenceLevel.unknown),
        reason: FusionReason.noUsableEvidence,
        factors: factors,
        warnings: <String>[...warnings, 'fusion.warning.noUsableEvidence'],
      );
    }

    // --- Pick a winner -----------------------------------------------------
    final ordered = scores.entries.toList()
      // Ties break on the enum's own order so the result never wobbles
      // between identical inputs.
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        return a.key.index.compareTo(b.key.index);
      });

    final winner = ordered.first;
    final alternatives = ordered
        .skip(1)
        .where((entry) => entry.value > 0)
        .take(3)
        .map((entry) => entry.key)
        .toList();

    final reason = _reasonFor(
      inVehicle: inVehicle,
      hasCamera: cameraTag != null,
      leadingPlaceTag: leadingPlaceTag,
      winner: winner.key,
      audioAgrees: audioAffinities.containsKey(winner.key),
      preciseFix: location?.isVenuePrecise ?? false,
    );

    final confidence = _confidenceFor(
      ordered: ordered,
      location: location,
      places: places,
      audio: audio,
      cameraConfidence: cameraTag == null ? null : evidence.cameraConfidence,
    );

    // --- Build the draft ---------------------------------------------------
    var draft = ContextDraft.empty();

    // Location, with a venue subtype when one is known. The subtype comes from
    // the camera first: a scan that saw a platform is better evidence of *which
    // part* of a station than a place lookup that only knows the station.
    final venue = evidence.cameraVenue ??
        (leadingPlaceTag == winner.key && leadingCandidate != null
            ? PlaceTypeMapping.toVenueCategory(leadingCandidate.primaryType)
            : null);
    // fromScan covers every automatic source in the draft's provenance
    // vocabulary; the finer-grained per-signal detail lives on `factors` and
    // `reason` rather than being flattened into one enum.
    draft = draft.apply(
      SetLocation(winner.key, venue: venue),
      origin: DraftOrigin.fromScan,
    );

    // Noise, from audio only. There is no other source for it.
    if (audio != null && audio.noiseLevel != null) {
      draft = draft.apply(
        SetNoiseLevel(audio.noiseLevel!),
        origin: DraftOrigin.fromScan,
      );
    }

    // Cues, from audio and from the venue.
    if (audio != null && audio.isUsable) {
      for (final cue in SoundCueMapping.toObservableCues(audio)) {
        draft = draft.apply(ToggleCue(cue), origin: DraftOrigin.fromScan);
      }
    }

    // Activity. Only the two that follow from a physical measurement: standing
    // still at a transit stop is waiting, and moving at vehicle speed is
    // commuting. Everything else is left unset for the user to say.
    final activity = _activityFor(winner.key, location, inVehicle);
    if (activity != null) {
      draft = draft.apply(SetActivity(activity), origin: DraftOrigin.fromScan);
    }

    // Group size, from the camera and nowhere else.
    if (evidence.cameraGroupSize != null) {
      draft = draft.apply(
        SetGroupSize(evidence.cameraGroupSize!),
        origin: DraftOrigin.fromScan,
      );
    }

    // A place name only when the answer is not in doubt.
    final placeName = confidence.level == ConfidenceLevel.high &&
            leadingPlaceTag == winner.key
        ? leadingCandidate?.displayName
        : null;

    return FusedContextResult(
      draft: draft,
      confidence: confidence,
      reason: reason,
      factors: factors,
      alternativeLocations: alternatives,
      warnings: warnings,
      placeName: placeName,
    );
  }

  FusionReason _reasonFor({
    required bool inVehicle,
    required bool hasCamera,
    required LocationTag? leadingPlaceTag,
    required LocationTag winner,
    required bool audioAgrees,
    required bool preciseFix,
  }) {
    if (inVehicle && winner == LocationTag.publicTransport) {
      return FusionReason.vehicleMotion;
    }
    if (hasCamera) return FusionReason.cameraScan;
    if (leadingPlaceTag == winner) {
      if (audioAgrees) return FusionReason.placeAndAudioAgree;
      if (preciseFix) return FusionReason.nearbyPlaceWithPreciseFix;
      return FusionReason.weakPlaceCandidate;
    }
    if (audioAgrees) return FusionReason.audioOnly;
    return FusionReason.weakPlaceCandidate;
  }

  /// Confidence in the winning location.
  ///
  /// Starts from the best single piece of evidence and is then demoted by
  /// every reason for doubt, so the answer is governed by its weakest link
  /// rather than by an average that hides one.
  FieldConfidence _confidenceFor({
    required List<MapEntry<LocationTag, int>> ordered,
    required LocationSignal? location,
    required NearbyPlaceSignal? places,
    required AudioEnvironmentSignal? audio,
    required FieldConfidence? cameraConfidence,
  }) {
    final winnerScore = ordered.first.value;
    final runnerUp = ordered.length > 1 ? ordered[1].value : 0;

    var level = switch (winnerScore) {
      >= 80 => ConfidenceLevel.high,
      >= 45 => ConfidenceLevel.medium,
      >= 18 => ConfidenceLevel.low,
      _ => ConfidenceLevel.unknown,
    };

    void demoteTo(ConfidenceLevel candidate) {
      if (candidate.index > level.index) level = candidate;
    }

    // A close second means the honest answer is a short list.
    if (winnerScore > 0 && runnerUp >= winnerScore * 0.8) {
      demoteTo(ConfidenceLevel.medium);
    }
    if (winnerScore > 0 && runnerUp >= winnerScore * 0.95) {
      demoteTo(ConfidenceLevel.low);
    }

    // Audio alone can never be high: it corroborates, it does not identify.
    final placeContributed =
        places != null && places.isUsable && places.candidates.isNotEmpty;
    if (!placeContributed && cameraConfidence == null) {
      demoteTo(ConfidenceLevel.medium);
      if (audio == null || !audio.sampleWasUsable) {
        demoteTo(ConfidenceLevel.unknown);
      }
    }

    if (location != null) {
      if (location.isApproximate) demoteTo(ConfidenceLevel.medium);
      if (!location.isVenuePrecise && cameraConfidence == null) {
        demoteTo(ConfidenceLevel.medium);
      }
    } else if (cameraConfidence == null) {
      demoteTo(ConfidenceLevel.low);
    }

    if (places != null && places.isContested) demoteTo(ConfidenceLevel.medium);

    return FieldConfidence(level, score: winnerScore);
  }

  /// The only activities that follow from a measurement rather than a guess.
  ActivityTag? _activityFor(
    LocationTag location,
    LocationSignal? signal,
    bool inVehicle,
  ) {
    if (inVehicle) return ActivityTag.commuting;
    if (signal == null || !signal.appearsStationary) return null;
    if (location == LocationTag.trainStation ||
        location == LocationTag.publicTransport ||
        location == LocationTag.waitingLine) {
      return ActivityTag.waiting;
    }
    return null;
  }
}
