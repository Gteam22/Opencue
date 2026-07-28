import '../enums/enums.dart';

/// A description of the current social situation.
///
/// In Version 1 this is always filled in by hand, but the shape is
/// deliberately source-agnostic: every field is a plain observable fact that a
/// later camera or smart-glasses module could populate without any change to
/// the recommendation engine. See `lib/domain/context/context_provider.dart`.
///
/// The snapshot describes a *setting*. It carries no field that identifies,
/// profiles, rates or infers anything about a person, and none should be
/// added. `eyeContact` and `conversationAlreadyStarted` record interactions
/// that have already happened between the user and the other person; they are
/// not inferences about that person's feelings.
class ContextSnapshot {
  ContextSnapshot({
    this.location = LocationTag.other,
    this.activity,
    this.groupSize = GroupSize.unknown,
    this.noiseLevel = NoiseLevel.normal,
    Set<ObservableCue>? observableCues,
    this.eyeContact = false,
    this.conversationAlreadyStarted = false,
    this.personAppearsOccupied = false,
    this.personIsMovingQuickly = false,
    this.isWorking = false,
    this.isUsingHeadphones = false,
    this.isIsolatedOrUnsafeSetting = false,
    this.userNotes,
    DateTime? createdAt,
    this.source = ContextSource.manual,
  })  : observableCues =
            Set.unmodifiable(observableCues ?? const <ObservableCue>{}),
        createdAt = createdAt ?? DateTime.now().toUtc();

  final LocationTag location;
  final ActivityTag? activity;
  final GroupSize groupSize;
  final NoiseLevel noiseLevel;
  final Set<ObservableCue> observableCues;

  /// Whether eye contact has already occurred between the user and the person.
  final bool eyeContact;

  /// Whether the two are already talking.
  final bool conversationAlreadyStarted;

  // The five flags below are the "do not approach now" signals. Each maps to
  // exactly one AvoidCondition and each on its own is enough to raise the
  // advisory.
  final bool personAppearsOccupied;
  final bool personIsMovingQuickly;
  final bool isWorking;
  final bool isUsingHeadphones;
  final bool isIsolatedOrUnsafeSetting;

  /// A free-text private note. Never leaves the device unless exported.
  final String? userNotes;

  final DateTime createdAt;

  /// Always ContextSource.manual in Version 1.
  final ContextSource source;

  /// The avoid conditions that the current flags make true.
  ///
  /// The recommendation engine treats these as hard signals, and the UI lists
  /// them so the user can see exactly which choice raised the warning.
  List<AvoidCondition> get activeAvoidConditions {
    final active = <AvoidCondition>[];
    if (personAppearsOccupied) active.add(AvoidCondition.personOccupied);
    if (isWorking) active.add(AvoidCondition.personWorking);
    if (isUsingHeadphones) active.add(AvoidCondition.headphonesOn);
    if (personIsMovingQuickly) active.add(AvoidCondition.movingQuickly);
    if (isIsolatedOrUnsafeSetting) {
      active.add(AvoidCondition.isolatedSetting);
    }
    return active;
  }

  /// All avoid conditions implied by the situation, including the softer ones
  /// derived from noise and eye contact. Used for line exclusion.
  Set<AvoidCondition> get impliedAvoidConditions {
    final implied = activeAvoidConditions.toSet();
    if (!eyeContact) implied.add(AvoidCondition.noEyeContact);
    if (noiseLevel == NoiseLevel.veryLoud) {
      implied.add(AvoidCondition.veryLoudSetting);
    }
    if (noiseLevel == NoiseLevel.quiet) {
      implied.add(AvoidCondition.quietFocusedSetting);
    }
    if (hasCompanions) implied.add(AvoidCondition.companionsPresent);
    return implied;
  }

  /// True when at least one hard signal says this is a bad moment.
  bool get discouragesApproach => activeAvoidConditions.isNotEmpty;

  /// True when the person is not by themselves.
  bool get hasCompanions =>
      groupSize == GroupSize.withOneFriend ||
      groupSize == GroupSize.smallGroup ||
      groupSize == GroupSize.largeGroup;

  ContextSnapshot copyWith({
    LocationTag? location,
    ActivityTag? activity,
    bool clearActivity = false,
    GroupSize? groupSize,
    NoiseLevel? noiseLevel,
    Set<ObservableCue>? observableCues,
    bool? eyeContact,
    bool? conversationAlreadyStarted,
    bool? personAppearsOccupied,
    bool? personIsMovingQuickly,
    bool? isWorking,
    bool? isUsingHeadphones,
    bool? isIsolatedOrUnsafeSetting,
    String? userNotes,
    bool clearUserNotes = false,
    DateTime? createdAt,
    ContextSource? source,
  }) {
    return ContextSnapshot(
      location: location ?? this.location,
      activity: clearActivity ? null : (activity ?? this.activity),
      groupSize: groupSize ?? this.groupSize,
      noiseLevel: noiseLevel ?? this.noiseLevel,
      observableCues: observableCues ?? this.observableCues,
      eyeContact: eyeContact ?? this.eyeContact,
      conversationAlreadyStarted:
          conversationAlreadyStarted ?? this.conversationAlreadyStarted,
      personAppearsOccupied:
          personAppearsOccupied ?? this.personAppearsOccupied,
      personIsMovingQuickly:
          personIsMovingQuickly ?? this.personIsMovingQuickly,
      isWorking: isWorking ?? this.isWorking,
      isUsingHeadphones: isUsingHeadphones ?? this.isUsingHeadphones,
      isIsolatedOrUnsafeSetting:
          isIsolatedOrUnsafeSetting ?? this.isIsolatedOrUnsafeSetting,
      userNotes: clearUserNotes ? null : (userNotes ?? this.userNotes),
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'location': location.name,
      'activity': activity?.name,
      'groupSize': groupSize.name,
      'noiseLevel': noiseLevel.name,
      'observableCues': enumSetToJson(observableCues),
      'eyeContact': eyeContact,
      'conversationAlreadyStarted': conversationAlreadyStarted,
      'personAppearsOccupied': personAppearsOccupied,
      'personIsMovingQuickly': personIsMovingQuickly,
      'isWorking': isWorking,
      'isUsingHeadphones': isUsingHeadphones,
      'isIsolatedOrUnsafeSetting': isIsolatedOrUnsafeSetting,
      'userNotes': userNotes,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'source': source.name,
    };
  }

  static ContextSnapshot fromJson(Map<String, Object?> json) {
    final rawCreated = json['createdAt'];
    return ContextSnapshot(
      location: enumFromNameOr(
        LocationTag.values,
        json['location'],
        LocationTag.other,
      ),
      activity: enumFromName(ActivityTag.values, json['activity']),
      groupSize: enumFromNameOr(
        GroupSize.values,
        json['groupSize'],
        GroupSize.unknown,
      ),
      noiseLevel: enumFromNameOr(
        NoiseLevel.values,
        json['noiseLevel'],
        NoiseLevel.normal,
      ),
      observableCues:
          enumSetFromJson(ObservableCue.values, json['observableCues']),
      eyeContact: json['eyeContact'] == true,
      conversationAlreadyStarted: json['conversationAlreadyStarted'] == true,
      personAppearsOccupied: json['personAppearsOccupied'] == true,
      personIsMovingQuickly: json['personIsMovingQuickly'] == true,
      isWorking: json['isWorking'] == true,
      isUsingHeadphones: json['isUsingHeadphones'] == true,
      isIsolatedOrUnsafeSetting: json['isIsolatedOrUnsafeSetting'] == true,
      userNotes: json['userNotes'] is String
          ? (json['userNotes']! as String).trim().isEmpty
              ? null
              : (json['userNotes']! as String).trim()
          : null,
      createdAt: rawCreated is String ? DateTime.tryParse(rawCreated) : null,
      source: enumFromNameOr(
        ContextSource.values,
        json['source'],
        ContextSource.manual,
      ),
    );
  }

  @override
  String toString() =>
      'ContextSnapshot(${location.name}, ${groupSize.name}, '
      '${noiseLevel.name}, source: ${source.name})';
}
