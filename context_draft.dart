import '../enums/enums.dart';
import '../models/context_snapshot.dart';
import '../scan/venue_category.dart';
import 'radial_menu_tree.dart';

/// Where a value in the draft came from.
///
/// The brief asks the menu to distinguish defaults, scan-inferred values and
/// user overrides, and to do it without relying on colour alone. Keeping the
/// provenance on the draft rather than in the widget means the detailed
/// editor and the list fallback can show the same distinction.
enum DraftOrigin {
  /// Nothing has set this dimension; it holds the model's own default.
  unset,

  /// Filled in from the user's saved preferences.
  fromDefaults,

  /// Suggested by an environmental scan and not since corrected.
  fromScan,

  /// Loaded from a saved preset or a recent context.
  fromPreset,

  /// Chosen by the user in this session. Always wins.
  fromUser,
}

/// The dimensions the draft tracks provenance for.
enum ContextDimension {
  location,
  venue,
  activity,
  groupSize,
  noiseLevel,
  cues,
  eyeContact,
  conversationStarted,
  caution,
  tones,
  directness,
}

/// The one context object every editing surface writes to.
///
/// The radial menu, the scan correction sheet, the detailed editor, the list
/// fallback and the preset loader all mutate a single [ContextDraft]; none of
/// them keeps its own copy. [toSnapshot] is the only way a draft becomes the
/// `ContextSnapshot` the recommendation engine reads, and it is called on
/// apply, never on every drag.
///
/// Immutable. Every mutation returns a new draft and pushes the previous one
/// onto an undo stack held by the controller, so `undo` is a stack pop rather
/// than an inverse operation per dimension.
class ContextDraft {
  ContextDraft({
    this.location = LocationTag.other,
    this.venue,
    this.activity,
    this.groupSize = GroupSize.unknown,
    this.noiseLevel = NoiseLevel.normal,
    Set<ObservableCue>? cues,
    this.eyeContact = false,
    this.conversationStarted = false,
    Set<AvoidCondition>? cautions,
    Set<Tone>? preferredTones,
    this.directness = 2,
    this.userNotes,
    Map<ContextDimension, DraftOrigin>? origins,
    this.source = ContextSource.manual,
  })  : cues = Set.unmodifiable(cues ?? const <ObservableCue>{}),
        cautions = Set.unmodifiable(cautions ?? const <AvoidCondition>{}),
        preferredTones = Set.unmodifiable(preferredTones ?? const <Tone>{}),
        origins = Map.unmodifiable(
          origins ?? const <ContextDimension, DraftOrigin>{},
        );

  final LocationTag location;

  /// The finer-grained venue behind [location], when one was chosen.
  ///
  /// The engine reasons in [LocationTag] only. This is kept so that a scan
  /// that saw a train platform, and a user who picked "platform" from the
  /// menu, both round-trip back to the same option when the menu reopens.
  final VenueCategory? venue;

  final ActivityTag? activity;
  final GroupSize groupSize;
  final NoiseLevel noiseLevel;
  final Set<ObservableCue> cues;
  final bool eyeContact;
  final bool conversationStarted;

  /// The caution flags the user has asserted. Only the five values in
  /// [ToggleCaution.settable] ever appear here; the rest are derived.
  final Set<AvoidCondition> cautions;

  /// Preferences, not part of the snapshot — passed alongside it to the
  /// engine. Held here so one draft carries everything the results screen
  /// needs.
  final Set<Tone> preferredTones;
  final int directness;

  final String? userNotes;
  final Map<ContextDimension, DraftOrigin> origins;
  final ContextSource source;

  /// Where [dimension]'s current value came from.
  DraftOrigin originOf(ContextDimension dimension) =>
      origins[dimension] ?? DraftOrigin.unset;

  /// Whether the user has overridden a scanned or default value here.
  bool isOverridden(ContextDimension dimension) =>
      originOf(dimension) == DraftOrigin.fromUser;

  /// How many dimensions the user has actually established, for the progress
  /// summary outside the ring.
  int get establishedDimensionCount =>
      origins.values.where((o) => o != DraftOrigin.unset).length;

  /// The snapshot the recommendation engine reads.
  ///
  /// The five caution flags are expanded back into the booleans
  /// `ContextSnapshot` exposes, which is what raises the advisory.
  ContextSnapshot toSnapshot() {
    return ContextSnapshot(
      location: location,
      activity: activity,
      groupSize: groupSize,
      noiseLevel: noiseLevel,
      observableCues: cues,
      eyeContact: eyeContact,
      conversationAlreadyStarted: conversationStarted,
      personAppearsOccupied: cautions.contains(AvoidCondition.personOccupied),
      isWorking: cautions.contains(AvoidCondition.personWorking),
      isUsingHeadphones: cautions.contains(AvoidCondition.headphonesOn),
      personIsMovingQuickly: cautions.contains(AvoidCondition.movingQuickly),
      isIsolatedOrUnsafeSetting:
          cautions.contains(AvoidCondition.isolatedSetting),
      userNotes: userNotes,
      source: source,
    );
  }

  /// Rebuilds a draft from an existing snapshot, marking every dimension the
  /// snapshot actually establishes with [origin].
  ///
  /// Used to preselect scan results (`DraftOrigin.fromScan`) and to open the
  /// menu on a context the user is amending.
  static ContextDraft fromSnapshot(
    ContextSnapshot snapshot, {
    DraftOrigin origin = DraftOrigin.fromScan,
    VenueCategory? venue,
    Set<Tone> preferredTones = const <Tone>{},
    int directness = 2,
  }) {
    final origins = <ContextDimension, DraftOrigin>{};
    void mark(ContextDimension dimension, bool established) {
      origins[dimension] = established ? origin : DraftOrigin.unset;
    }

    mark(ContextDimension.location, snapshot.location != LocationTag.other);
    mark(ContextDimension.venue, venue != null);
    mark(ContextDimension.activity, snapshot.activity != null);
    mark(ContextDimension.groupSize, snapshot.groupSize != GroupSize.unknown);
    // Normal is the model default, so a snapshot reporting it tells us nothing
    // about whether anyone established it.
    mark(ContextDimension.noiseLevel, snapshot.noiseLevel != NoiseLevel.normal);
    mark(ContextDimension.cues, snapshot.observableCues.isNotEmpty);
    mark(ContextDimension.eyeContact, snapshot.eyeContact);
    mark(
      ContextDimension.conversationStarted,
      snapshot.conversationAlreadyStarted,
    );
    mark(ContextDimension.caution, snapshot.activeAvoidConditions.isNotEmpty);

    return ContextDraft(
      location: snapshot.location,
      venue: venue,
      activity: snapshot.activity,
      groupSize: snapshot.groupSize,
      noiseLevel: snapshot.noiseLevel,
      cues: snapshot.observableCues.toSet(),
      eyeContact: snapshot.eyeContact,
      conversationStarted: snapshot.conversationAlreadyStarted,
      cautions: snapshot.activeAvoidConditions.toSet(),
      preferredTones: preferredTones,
      directness: clampDirectness(directness),
      userNotes: snapshot.userNotes,
      origins: origins,
      source: snapshot.source,
    );
  }

  // -------------------------------------------------------------------------
  // Applying a selection
  // -------------------------------------------------------------------------

  /// Applies one radial selection, returning the resulting draft.
  ///
  /// [RunCommand] actions are handled by the controller, not here — they are
  /// navigation and side effects rather than context — so this returns the
  /// draft unchanged for them.
  ContextDraft apply(
    RadialSelectionAction action, {
    DraftOrigin origin = DraftOrigin.fromUser,
  }) {
    switch (action) {
      case SetLocation(:final value, :final venue):
        return copyWith(
          location: value,
          venue: venue,
          clearVenue: venue == null,
          origins: _mark(<ContextDimension>{
            ContextDimension.location,
            if (venue != null) ContextDimension.venue,
          }, origin),
        );
      case SetActivity(:final value):
        return copyWith(
          activity: value,
          origins: _mark(<ContextDimension>{ContextDimension.activity}, origin),
        );
      case SetGroupSize(:final value):
        return copyWith(
          groupSize: value,
          origins:
              _mark(<ContextDimension>{ContextDimension.groupSize}, origin),
        );
      case SetNoiseLevel(:final value):
        return copyWith(
          noiseLevel: value,
          origins:
              _mark(<ContextDimension>{ContextDimension.noiseLevel}, origin),
        );
      case ToggleCue(:final value):
        return copyWith(
          cues: _toggled(cues, value),
          origins: _mark(<ContextDimension>{ContextDimension.cues}, origin),
        );
      case ToggleTone(:final value):
        return copyWith(
          preferredTones: _toggled(preferredTones, value),
          origins: _mark(<ContextDimension>{ContextDimension.tones}, origin),
        );
      case SetDirectness(:final value):
        return copyWith(
          directness: clampDirectness(value),
          origins:
              _mark(<ContextDimension>{ContextDimension.directness}, origin),
        );
      case ToggleInteraction(:final value):
        switch (value) {
          case InteractionFlag.eyeContact:
            return copyWith(
              eyeContact: !eyeContact,
              origins: _mark(
                <ContextDimension>{ContextDimension.eyeContact},
                origin,
              ),
            );
          case InteractionFlag.conversationStarted:
            return copyWith(
              conversationStarted: !conversationStarted,
              origins: _mark(
                <ContextDimension>{ContextDimension.conversationStarted},
                origin,
              ),
            );
        }
      case ToggleCaution(:final value):
        return copyWith(
          cautions: _toggled(cautions, value),
          origins: _mark(<ContextDimension>{ContextDimension.caution}, origin),
        );
      case RunCommand():
        return this;
    }
  }

  /// Whether [action] is currently satisfied by the draft, so the menu can
  /// mark it when reopened.
  bool isSelected(RadialSelectionAction action) {
    switch (action) {
      case SetLocation(:final value, :final venue):
        if (venue != null) return this.venue == venue;
        return location == value && this.venue == null;
      case SetActivity(:final value):
        return activity == value;
      case SetGroupSize(:final value):
        return groupSize == value;
      case SetNoiseLevel(:final value):
        return noiseLevel == value;
      case ToggleCue(:final value):
        return cues.contains(value);
      case ToggleTone(:final value):
        return preferredTones.contains(value);
      case SetDirectness(:final value):
        return directness == value;
      case ToggleInteraction(:final value):
        return switch (value) {
          InteractionFlag.eyeContact => eyeContact,
          InteractionFlag.conversationStarted => conversationStarted,
        };
      case ToggleCaution(:final value):
        return cautions.contains(value);
      case RunCommand():
        return false;
    }
  }

  /// Resets one dimension to its model default and marks it unset.
  ContextDraft clearDimension(ContextDimension dimension) {
    final cleared = Map<ContextDimension, DraftOrigin>.from(origins)
      ..[dimension] = DraftOrigin.unset;
    switch (dimension) {
      case ContextDimension.location:
        return copyWith(
          location: LocationTag.other,
          clearVenue: true,
          origins: cleared..[ContextDimension.venue] = DraftOrigin.unset,
        );
      case ContextDimension.venue:
        return copyWith(clearVenue: true, origins: cleared);
      case ContextDimension.activity:
        return copyWith(clearActivity: true, origins: cleared);
      case ContextDimension.groupSize:
        return copyWith(groupSize: GroupSize.unknown, origins: cleared);
      case ContextDimension.noiseLevel:
        return copyWith(noiseLevel: NoiseLevel.normal, origins: cleared);
      case ContextDimension.cues:
        return copyWith(cues: <ObservableCue>{}, origins: cleared);
      case ContextDimension.eyeContact:
        return copyWith(eyeContact: false, origins: cleared);
      case ContextDimension.conversationStarted:
        return copyWith(conversationStarted: false, origins: cleared);
      case ContextDimension.caution:
        return copyWith(cautions: <AvoidCondition>{}, origins: cleared);
      case ContextDimension.tones:
        return copyWith(preferredTones: <Tone>{}, origins: cleared);
      case ContextDimension.directness:
        return copyWith(directness: 2, origins: cleared);
    }
  }

  /// An empty draft that keeps the user's saved tone and directness defaults,
  /// because the brief asks that tone not have to be set every time.
  static ContextDraft empty({
    Set<Tone> defaultTones = const <Tone>{},
    int defaultDirectness = 2,
  }) {
    return ContextDraft(
      preferredTones: defaultTones,
      directness: clampDirectness(defaultDirectness),
      origins: <ContextDimension, DraftOrigin>{
        if (defaultTones.isNotEmpty)
          ContextDimension.tones: DraftOrigin.fromDefaults,
        ContextDimension.directness: DraftOrigin.fromDefaults,
      },
    );
  }

  Map<ContextDimension, DraftOrigin> _mark(
    Set<ContextDimension> dimensions,
    DraftOrigin origin,
  ) {
    final next = Map<ContextDimension, DraftOrigin>.from(origins);
    for (final dimension in dimensions) {
      next[dimension] = origin;
    }
    return next;
  }

  static Set<T> _toggled<T>(Set<T> current, T value) {
    final next = current.toSet();
    if (!next.remove(value)) next.add(value);
    return next;
  }

  ContextDraft copyWith({
    LocationTag? location,
    VenueCategory? venue,
    bool clearVenue = false,
    ActivityTag? activity,
    bool clearActivity = false,
    GroupSize? groupSize,
    NoiseLevel? noiseLevel,
    Set<ObservableCue>? cues,
    bool? eyeContact,
    bool? conversationStarted,
    Set<AvoidCondition>? cautions,
    Set<Tone>? preferredTones,
    int? directness,
    String? userNotes,
    bool clearUserNotes = false,
    Map<ContextDimension, DraftOrigin>? origins,
    ContextSource? source,
  }) {
    return ContextDraft(
      location: location ?? this.location,
      venue: clearVenue ? null : (venue ?? this.venue),
      activity: clearActivity ? null : (activity ?? this.activity),
      groupSize: groupSize ?? this.groupSize,
      noiseLevel: noiseLevel ?? this.noiseLevel,
      cues: cues ?? this.cues,
      eyeContact: eyeContact ?? this.eyeContact,
      conversationStarted: conversationStarted ?? this.conversationStarted,
      cautions: cautions ?? this.cautions,
      preferredTones: preferredTones ?? this.preferredTones,
      directness: directness ?? this.directness,
      userNotes: clearUserNotes ? null : (userNotes ?? this.userNotes),
      origins: origins ?? this.origins,
      source: source ?? this.source,
    );
  }

  // -------------------------------------------------------------------------
  // Serialisation
  // -------------------------------------------------------------------------

  /// Serialises the draft for storage inside a preset.
  ///
  /// Written as one JSON blob for the same reason `ContextSnapshot` is: a
  /// field added to the draft later needs no database migration. Provenance is
  /// deliberately **not** stored — a preset the user loads is a preset, not a
  /// scan result, and [fromJson] marks everything it establishes accordingly.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'location': location.name,
      'venue': venue?.name,
      'activity': activity?.name,
      'groupSize': groupSize.name,
      'noiseLevel': noiseLevel.name,
      'cues': enumSetToJson(cues),
      'eyeContact': eyeContact,
      'conversationStarted': conversationStarted,
      'cautions': enumSetToJson(cautions),
      'preferredTones': enumSetToJson(preferredTones),
      'directness': directness,
      'userNotes': userNotes,
    };
  }

  /// Reads a draft written by [toJson], skipping anything unrecognised.
  ///
  /// Never throws: a preset written by a newer version loads with the fields
  /// this version understands rather than taking the presets list down.
  static ContextDraft fromJson(
    Map<String, Object?> json, {
    DraftOrigin origin = DraftOrigin.fromPreset,
  }) {
    final location = enumFromNameOr(
      LocationTag.values,
      json['location'],
      LocationTag.other,
    );
    final venue = enumFromName(VenueCategory.values, json['venue']);
    final activity = enumFromName(ActivityTag.values, json['activity']);
    final groupSize = enumFromNameOr(
      GroupSize.values,
      json['groupSize'],
      GroupSize.unknown,
    );
    final noiseLevel = enumFromNameOr(
      NoiseLevel.values,
      json['noiseLevel'],
      NoiseLevel.normal,
    );
    final cues = enumSetFromJson(ObservableCue.values, json['cues']);
    final cautions = enumSetFromJson(AvoidCondition.values, json['cautions'])
      // Only the five user-settable conditions belong on a draft; a file
      // naming a derived one is filtered rather than rejected.
      ..removeWhere((c) => !ToggleCaution.settable.contains(c));
    final tones = enumSetFromJson(Tone.values, json['preferredTones']);
    final eyeContact = json['eyeContact'] == true;
    final conversationStarted = json['conversationStarted'] == true;
    final rawDirectness = json['directness'];
    final directness =
        clampDirectness(rawDirectness is int ? rawDirectness : 2);

    final origins = <ContextDimension, DraftOrigin>{};
    void mark(ContextDimension dimension, bool established) {
      origins[dimension] = established ? origin : DraftOrigin.unset;
    }

    mark(ContextDimension.location, location != LocationTag.other);
    mark(ContextDimension.venue, venue != null);
    mark(ContextDimension.activity, activity != null);
    mark(ContextDimension.groupSize, groupSize != GroupSize.unknown);
    mark(ContextDimension.noiseLevel, noiseLevel != NoiseLevel.normal);
    mark(ContextDimension.cues, cues.isNotEmpty);
    mark(ContextDimension.eyeContact, eyeContact);
    mark(ContextDimension.conversationStarted, conversationStarted);
    mark(ContextDimension.caution, cautions.isNotEmpty);
    mark(ContextDimension.tones, tones.isNotEmpty);
    origins[ContextDimension.directness] = origin;

    return ContextDraft(
      location: location,
      venue: venue,
      activity: activity,
      groupSize: groupSize,
      noiseLevel: noiseLevel,
      cues: cues,
      eyeContact: eyeContact,
      conversationStarted: conversationStarted,
      cautions: cautions,
      preferredTones: tones,
      directness: directness,
      userNotes: json['userNotes'] is String
          ? (json['userNotes']! as String)
          : null,
      origins: origins,
    );
  }

  @override
  String toString() => 'ContextDraft(${location.name}, ${groupSize.name}, '
      '${noiseLevel.name}, ${cues.length} cues, ${cautions.length} cautions)';
}
