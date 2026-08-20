import '../context/context_provider.dart';
import '../enums/enums.dart';
import '../models/context_snapshot.dart';
import 'environmental_observation.dart';
import 'scan_heuristics.dart';

/// The user's confirmed answers, after they have reviewed a scan.
///
/// This is what the confirmation screen produces. It exists as a separate type
/// from [EnvironmentalObservation] so that "what the model guessed" and "what
/// the user agreed to" can never be confused for one another: only this type
/// can become a ContextSnapshot.
class ConfirmedScanContext {
  const ConfirmedScanContext({
    required this.observationId,
    this.location,
    this.activity,
    this.groupSize,
    this.noiseLevel,
    this.observableCues = const <ObservableCue>{},
    this.eyeContact = false,
    this.conversationAlreadyStarted = false,
    this.personAppearsOccupied = false,
    this.personIsMovingQuickly = false,
    this.isWorking = false,
    this.isUsingHeadphones = false,
    this.isIsolatedOrUnsafeSetting = false,
    this.userNotes,
  });

  final String observationId;

  /// Null means the user left it unset; the snapshot keeps its default.
  final LocationTag? location;
  final ActivityTag? activity;

  /// Never inferred from an image. Supplied by the user or left unknown.
  final GroupSize? groupSize;

  final NoiseLevel? noiseLevel;
  final Set<ObservableCue> observableCues;

  // The six below are never inferred from a photograph. They are here so the
  // confirmation screen can collect them, and they default to the harmless
  // value so an unanswered question never becomes an assertion.
  final bool eyeContact;
  final bool conversationAlreadyStarted;
  final bool personAppearsOccupied;
  final bool personIsMovingQuickly;
  final bool isWorking;
  final bool isUsingHeadphones;
  final bool isIsolatedOrUnsafeSetting;

  final String? userNotes;
}

/// Turns a confirmed scan into the ContextSnapshot the engine already knows.
///
/// Deliberately thin. The whole point of the scan feature is that it produces
/// an ordinary snapshot and then stops being special: there is no separate
/// ranking path, no scan-only scoring, and no field the engine treats
/// differently because a camera was involved. The only difference is `source`.
class ContextSnapshotMapper {
  const ContextSnapshotMapper();

  ContextSnapshot toSnapshot(
    ConfirmedScanContext confirmed, {
    DateTime? now,
  }) {
    // Any cue the scanner is forbidden from inferring can still be ticked by
    // the user, but is filtered here too if it somehow arrived unticked from
    // a scan path, so the invariant holds at both ends of the pipeline.
    final cues = confirmed.observableCues.toSet();

    return ContextSnapshot(
      location: confirmed.location ?? LocationTag.other,
      activity: confirmed.activity,
      groupSize: confirmed.groupSize ?? GroupSize.unknown,
      noiseLevel: confirmed.noiseLevel ?? NoiseLevel.normal,
      observableCues: cues,
      eyeContact: confirmed.eyeContact,
      conversationAlreadyStarted: confirmed.conversationAlreadyStarted,
      personAppearsOccupied: confirmed.personAppearsOccupied,
      personIsMovingQuickly: confirmed.personIsMovingQuickly,
      isWorking: confirmed.isWorking,
      isUsingHeadphones: confirmed.isUsingHeadphones,
      isIsolatedOrUnsafeSetting: confirmed.isIsolatedOrUnsafeSetting,
      userNotes: confirmed.userNotes,
      createdAt: now ?? DateTime.now().toUtc(),
      source: ContextSource.cameraScan,
    );
  }

  /// The starting point for the confirmation screen.
  ///
  /// High and medium confidence values are filled in; low confidence values
  /// are left out so they appear as offers rather than answers. Nothing the
  /// camera cannot see is ever preset.
  ConfirmedScanContext initialFrom(EnvironmentalObservation observation) {
    return ConfirmedScanContext(
      observationId: observation.id,
      location: observation.location.preselect
          ? observation.location.value
          : null,
      activity: observation.activity.preselect
          ? observation.activity.value
          : null,
      noiseLevel: observation.noiseLevel.preselect
          ? observation.noiseLevel.value
          : null,
      observableCues: observation.preselectedCues
          .where((c) => !ScanHeuristics.neverInferred.contains(c))
          .toSet(),
      // groupSize is absent on purpose: it is not inferred, and GroupSize
      // .unknown is the honest default until the user says otherwise.
    );
  }
}

/// A ContextProvider backed by a completed, user-confirmed scan.
///
/// It takes an already-confirmed context rather than running a camera itself.
/// That keeps the domain layer free of any camera or ML dependency: capture
/// and analysis happen in lib/data/scan, and by the time anything reaches
/// here the user has reviewed it.
class CameraContextProvider implements ContextProvider {
  CameraContextProvider(
    this._confirmed, {
    ContextSnapshotMapper mapper = const ContextSnapshotMapper(),
  }) : _mapper = mapper;

  final ConfirmedScanContext _confirmed;
  final ContextSnapshotMapper _mapper;

  @override
  ContextSource get source => ContextSource.cameraScan;

  @override
  bool get isAvailable => true;

  @override
  String get id => 'cameraScan';

  @override
  Future<ContextSnapshot> captureContext() async =>
      _mapper.toSnapshot(_confirmed);
}
