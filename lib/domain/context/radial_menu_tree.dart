import '../enums/enums.dart';
import '../scan/venue_category.dart';

/// The radial context menu's node tree.
///
/// Flutter-free, like the rest of `lib/domain`. Nodes carry a **localization
/// key** and an **icon identifier string**, never a `String` label or an
/// `IconData`; the widget layer resolves both. That is what keeps the menu
/// from growing its own copy of the vocabulary.
///
/// Every leaf's [RadialSelectionAction] holds a real enum value from
/// `lib/domain/enums/enums.dart` or a real [VenueCategory]. There are no
/// string-only options, so a value added to an enum cannot silently fail to
/// appear here: `test/radial_menu_tree_test.dart` asserts that every value of
/// every dimension the menu covers is reachable from the root.
library;

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// What selecting a leaf does to the draft context.
sealed class RadialSelectionAction {
  const RadialSelectionAction();

  /// Whether this action toggles membership of a set rather than replacing a
  /// single value. Multi-select leaves stay selectable when reopened.
  bool get isMultiSelect => false;
}

class SetLocation extends RadialSelectionAction {
  const SetLocation(this.value, {this.venue});
  final LocationTag value;

  /// The finer-grained venue this option came from, preserved alongside the
  /// broad tag the engine reasons about. Null when the user picked the broad
  /// tag directly.
  final VenueCategory? venue;
}

class SetActivity extends RadialSelectionAction {
  const SetActivity(this.value);
  final ActivityTag value;
}

class SetGroupSize extends RadialSelectionAction {
  const SetGroupSize(this.value);
  final GroupSize value;
}

class SetNoiseLevel extends RadialSelectionAction {
  const SetNoiseLevel(this.value);
  final NoiseLevel value;
}

class ToggleCue extends RadialSelectionAction {
  const ToggleCue(this.value);
  final ObservableCue value;
  @override
  bool get isMultiSelect => true;
}

class ToggleTone extends RadialSelectionAction {
  const ToggleTone(this.value);
  final Tone value;
  @override
  bool get isMultiSelect => true;
}

class SetDirectness extends RadialSelectionAction {
  const SetDirectness(this.value);
  final int value;
}

/// Toggles one of the interaction facts the user reports about themselves.
enum InteractionFlag { eyeContact, conversationStarted }

class ToggleInteraction extends RadialSelectionAction {
  const ToggleInteraction(this.value);
  final InteractionFlag value;
  @override
  bool get isMultiSelect => true;
}

/// Toggles one of the five caution flags on the snapshot.
///
/// Typed as [AvoidCondition] rather than as a bespoke enum so the menu, the
/// advisory and the engine all name the same thing. Only the five values that
/// `ContextSnapshot` exposes as flags are offered; the remaining
/// `AvoidCondition` values are derived from other fields and are not
/// user-settable.
class ToggleCaution extends RadialSelectionAction {
  const ToggleCaution(this.value);
  final AvoidCondition value;
  @override
  bool get isMultiSelect => true;

  /// The five conditions a user can assert directly.
  static const List<AvoidCondition> settable = <AvoidCondition>[
    AvoidCondition.personOccupied,
    AvoidCondition.personWorking,
    AvoidCondition.headphonesOn,
    AvoidCondition.movingQuickly,
    AvoidCondition.isolatedSetting,
  ];
}

/// A command rather than a value: the centre and the Finish sector.
enum RadialCommand {
  showRecommendations,
  clearAll,
  clearDimension,
  undo,
  useScanResult,
  restoreDefaults,
  recentContexts,
  savedPresets,
  savePreset,
  detailedEditor,
  openListFallback,
}

class RunCommand extends RadialSelectionAction {
  const RunCommand(this.command);
  final RadialCommand command;
}

// ---------------------------------------------------------------------------
// Nodes
// ---------------------------------------------------------------------------

/// One node of the menu tree.
///
/// A node is a branch when [children] is non-empty and a leaf when [action] is
/// non-null. It is never both; [assertWellFormed] checks this for the whole
/// tree in a test rather than at every construction.
class RadialMenuNode {
  const RadialMenuNode({
    required this.id,
    required this.labelKey,
    required this.iconId,
    this.action,
    this.children = const <RadialMenuNode>[],
    this.allowMultipleSelection = false,
  });

  /// Stable identifier, used by chips that reopen the menu at this branch and
  /// by the local usability counters. Never shown to the user.
  final String id;

  /// Key into the tables in `lib/l10n`. Resolved by `AppLocalizations.t`.
  final String labelKey;

  /// Name of an icon in `RadialIcons`, resolved in the features layer so this
  /// file needs no Flutter import.
  final String iconId;

  final RadialSelectionAction? action;
  final List<RadialMenuNode> children;

  /// Whether this branch's children may be selected together. Set on the cue,
  /// tone and caution branches.
  final bool allowMultipleSelection;

  bool get isLeaf => action != null;
  bool get isBranch => children.isNotEmpty;

  /// Depth-first walk including this node.
  Iterable<RadialMenuNode> walk() sync* {
    yield this;
    for (final child in children) {
      yield* child.walk();
    }
  }

  /// The path from this node to the node with [id], or null when absent.
  ///
  /// Used to open the menu directly at a branch when a context chip is tapped,
  /// so the user is not sent back to the root every time.
  List<RadialMenuNode>? pathTo(String id) {
    if (this.id == id) return <RadialMenuNode>[this];
    for (final child in children) {
      final below = child.pathTo(id);
      if (below != null) return <RadialMenuNode>[this, ...below];
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// The tree
// ---------------------------------------------------------------------------

/// Builds the menu tree. A function rather than a top-level constant so the
/// list-building loops over enum values stay readable.
RadialMenuNode buildRadialMenuTree() {
  return RadialMenuNode(
    id: 'root',
    labelKey: 'radial.root',
    iconId: 'root',
    children: <RadialMenuNode>[
      _place(),
      _people(),
      _activity(),
      _cue(),
      _atmosphere(),
      _tone(),
      _caution(),
      _finish(),
    ],
  );
}

// --- Place -----------------------------------------------------------------

RadialMenuNode _venue(String id, VenueCategory venue, LocationTag tag,
        String iconId) =>
    RadialMenuNode(
      id: id,
      labelKey: 'venue.${venue.name}',
      iconId: iconId,
      action: SetLocation(tag, venue: venue),
    );

RadialMenuNode _location(LocationTag tag, String iconId) => RadialMenuNode(
      id: 'place.tag.${tag.name}',
      labelKey: 'location.${tag.name}',
      iconId: iconId,
      action: SetLocation(tag),
    );

RadialMenuNode _place() {
  return RadialMenuNode(
    id: 'place',
    labelKey: 'radial.place',
    iconId: 'place',
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'place.foodDrink',
        labelKey: 'radial.place.foodDrink',
        iconId: 'foodDrink',
        children: <RadialMenuNode>[
          _location(LocationTag.cafe, 'cafe'),
          _location(LocationTag.restaurant, 'restaurant'),
          _location(LocationTag.convenienceStore, 'convenienceStore'),
        ],
      ),
      RadialMenuNode(
        id: 'place.nightlife',
        labelKey: 'radial.place.nightlife',
        iconId: 'nightlife',
        children: <RadialMenuNode>[
          _location(LocationTag.bar, 'bar'),
          _location(LocationTag.standingBar, 'standingBar'),
          _location(LocationTag.club, 'club'),
          _location(LocationTag.party, 'party'),
        ],
      ),
      RadialMenuNode(
        id: 'place.transit',
        labelKey: 'radial.place.transit',
        iconId: 'transit',
        children: <RadialMenuNode>[
          // Subtypes collapse onto the two location tags the 155 lines are
          // written against, while the subtype itself is kept on the draft.
          _venue('place.transit.station', VenueCategory.subwayOrTrainStation,
              LocationTag.trainStation, 'station'),
          _venue('place.transit.platform', VenueCategory.trainPlatform,
              LocationTag.trainStation, 'platform'),
          _venue('place.transit.concourse', VenueCategory.stationConcourse,
              LocationTag.trainStation, 'concourse'),
          _venue('place.transit.gate', VenueCategory.ticketGateArea,
              LocationTag.trainStation, 'gate'),
          _venue('place.transit.interior', VenueCategory.trainInterior,
              LocationTag.publicTransport, 'trainInterior'),
          _venue('place.transit.busStop', VenueCategory.busStop,
              LocationTag.publicTransport, 'busStop'),
          _location(LocationTag.publicTransport, 'publicTransport'),
        ],
      ),
      RadialMenuNode(
        id: 'place.outdoors',
        labelKey: 'radial.place.outdoors',
        iconId: 'outdoors',
        children: <RadialMenuNode>[
          _location(LocationTag.street, 'street'),
          _location(LocationTag.park, 'park'),
          _location(LocationTag.waterfront, 'waterfront'),
        ],
      ),
      RadialMenuNode(
        id: 'place.shopping',
        labelKey: 'radial.place.shopping',
        iconId: 'shopping',
        children: <RadialMenuNode>[
          _location(LocationTag.shoppingArea, 'shoppingArea'),
          _location(LocationTag.bookstore, 'bookstore'),
          _location(LocationTag.convenienceStore, 'convenienceStore2'),
        ],
      ),
      RadialMenuNode(
        id: 'place.events',
        labelKey: 'radial.place.events',
        iconId: 'events',
        children: <RadialMenuNode>[
          _location(LocationTag.festival, 'festival'),
          _location(LocationTag.cosplayEvent, 'cosplayEvent'),
          _location(LocationTag.concert, 'concert'),
          _location(LocationTag.languageExchange, 'languageExchange'),
          _location(LocationTag.meetup, 'meetup'),
        ],
      ),
      RadialMenuNode(
        id: 'place.fitness',
        labelKey: 'radial.place.fitness',
        iconId: 'fitness',
        children: <RadialMenuNode>[
          _location(LocationTag.gym, 'gym'),
          _location(LocationTag.kickboxingClass, 'kickboxingClass'),
        ],
      ),
      RadialMenuNode(
        id: 'place.other',
        labelKey: 'radial.place.other',
        iconId: 'other',
        children: <RadialMenuNode>[
          _location(LocationTag.waitingLine, 'waitingLine'),
          _location(LocationTag.other, 'other'),
          const RadialMenuNode(
            id: 'place.searchAll',
            labelKey: 'radial.searchFullList',
            iconId: 'search',
            action: RunCommand(RadialCommand.openListFallback),
          ),
        ],
      ),
    ],
  );
}

// --- People ----------------------------------------------------------------

RadialMenuNode _people() {
  return RadialMenuNode(
    id: 'people',
    labelKey: 'radial.people',
    iconId: 'people',
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'people.count',
        labelKey: 'radial.people.count',
        iconId: 'peopleCount',
        children: <RadialMenuNode>[
          for (final value in GroupSize.values)
            RadialMenuNode(
              id: 'people.count.${value.name}',
              labelKey: 'groupSize.${value.name}',
              iconId: 'groupSize.${value.name}',
              action: SetGroupSize(value),
            ),
        ],
      ),
      RadialMenuNode(
        id: 'people.interaction',
        labelKey: 'radial.people.interaction',
        iconId: 'interaction',
        allowMultipleSelection: true,
        children: const <RadialMenuNode>[
          RadialMenuNode(
            id: 'people.interaction.eyeContact',
            labelKey: 'context.eyeContact',
            iconId: 'eyeContact',
            action: ToggleInteraction(InteractionFlag.eyeContact),
          ),
          RadialMenuNode(
            id: 'people.interaction.smile',
            labelKey: 'cue.smile',
            iconId: 'smile',
            action: ToggleCue(ObservableCue.smile),
          ),
          RadialMenuNode(
            id: 'people.interaction.conversation',
            labelKey: 'context.conversationStarted',
            iconId: 'conversation',
            action: ToggleInteraction(InteractionFlag.conversationStarted),
          ),
          RadialMenuNode(
            id: 'people.interaction.shared',
            labelKey: 'cue.sharedActivity',
            iconId: 'sharedActivity',
            action: ToggleCue(ObservableCue.sharedActivity),
          ),
        ],
      ),
    ],
  );
}

// --- Activity --------------------------------------------------------------

RadialMenuNode _activityLeaf(ActivityTag tag) => RadialMenuNode(
      id: 'activity.${tag.name}',
      labelKey: 'activity.${tag.name}',
      iconId: 'activity.${tag.name}',
      action: SetActivity(tag),
    );

RadialMenuNode _activity() {
  return RadialMenuNode(
    id: 'activity',
    labelKey: 'radial.activity',
    iconId: 'activity',
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'activity.stillness',
        labelKey: 'radial.activity.stillness',
        iconId: 'stillness',
        children: <RadialMenuNode>[
          _activityLeaf(ActivityTag.waiting),
          _activityLeaf(ActivityTag.resting),
          _activityLeaf(ActivityTag.reading),
        ],
      ),
      RadialMenuNode(
        id: 'activity.movement',
        labelKey: 'radial.activity.movement',
        iconId: 'movement',
        children: <RadialMenuNode>[
          _activityLeaf(ActivityTag.walking),
          _activityLeaf(ActivityTag.commuting),
          _activityLeaf(ActivityTag.exercising),
          _activityLeaf(ActivityTag.dancing),
        ],
      ),
      RadialMenuNode(
        id: 'activity.consuming',
        labelKey: 'radial.activity.consuming',
        iconId: 'consuming',
        children: <RadialMenuNode>[
          _activityLeaf(ActivityTag.eating),
          _activityLeaf(ActivityTag.drinking),
        ],
      ),
      RadialMenuNode(
        id: 'activity.browsingGroup',
        labelKey: 'radial.activity.browsingGroup',
        iconId: 'browsingGroup',
        children: <RadialMenuNode>[
          _activityLeaf(ActivityTag.browsing),
          _activityLeaf(ActivityTag.shopping),
        ],
      ),
      RadialMenuNode(
        id: 'activity.social',
        labelKey: 'radial.activity.social',
        iconId: 'social',
        children: <RadialMenuNode>[
          _activityLeaf(ActivityTag.socialising),
          _activityLeaf(ActivityTag.photographing),
        ],
      ),
      _activityLeaf(ActivityTag.other),
    ],
  );
}

// --- Observable cue --------------------------------------------------------

RadialMenuNode _cueLeaf(ObservableCue cue) => RadialMenuNode(
      id: 'cue.${cue.name}',
      labelKey: 'cue.${cue.name}',
      iconId: 'cue.${cue.name}',
      action: ToggleCue(cue),
    );

RadialMenuNode _cue() {
  return RadialMenuNode(
    id: 'cue',
    labelKey: 'radial.cue',
    iconId: 'cue',
    allowMultipleSelection: true,
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'cue.appearance',
        labelKey: 'radial.cue.appearance',
        iconId: 'appearance',
        allowMultipleSelection: true,
        children: <RadialMenuNode>[
          _cueLeaf(ObservableCue.distinctiveOutfit),
          _cueLeaf(ObservableCue.hairstyle),
          _cueLeaf(ObservableCue.nails),
          _cueLeaf(ObservableCue.cosplay),
          _cueLeaf(ObservableCue.characterMerchandise),
        ],
      ),
      RadialMenuNode(
        id: 'cue.object',
        labelKey: 'radial.cue.object',
        iconId: 'object',
        allowMultipleSelection: true,
        children: <RadialMenuNode>[
          _cueLeaf(ObservableCue.drink),
          _cueLeaf(ObservableCue.food),
          _cueLeaf(ObservableCue.book),
          _cueLeaf(ObservableCue.dog),
          _cueLeaf(ObservableCue.festivalItem),
          _cueLeaf(ObservableCue.sportsEquipment),
        ],
      ),
      RadialMenuNode(
        id: 'cue.shared',
        labelKey: 'radial.cue.shared',
        iconId: 'shared',
        allowMultipleSelection: true,
        children: <RadialMenuNode>[
          _cueLeaf(ObservableCue.weather),
          _cueLeaf(ObservableCue.waiting),
          _cueLeaf(ObservableCue.sharedActivity),
          _cueLeaf(ObservableCue.takingPhotographs),
          _cueLeaf(ObservableCue.music),
          _cueLeaf(ObservableCue.groupHavingFun),
        ],
      ),
      RadialMenuNode(
        id: 'cue.interactionGroup',
        labelKey: 'radial.cue.interactionGroup',
        iconId: 'interaction',
        allowMultipleSelection: true,
        children: <RadialMenuNode>[
          _cueLeaf(ObservableCue.eyeContact),
          _cueLeaf(ObservableCue.smile),
        ],
      ),
      _cueLeaf(ObservableCue.other),
    ],
  );
}

// --- Atmosphere ------------------------------------------------------------

RadialMenuNode _atmosphere() {
  return RadialMenuNode(
    id: 'atmosphere',
    labelKey: 'radial.atmosphere',
    iconId: 'atmosphere',
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'atmosphere.noise',
        labelKey: 'radial.atmosphere.noise',
        iconId: 'noise',
        children: <RadialMenuNode>[
          for (final value in NoiseLevel.values)
            RadialMenuNode(
              id: 'atmosphere.noise.${value.name}',
              labelKey: 'noiseLevel.${value.name}',
              iconId: 'noiseLevel.${value.name}',
              action: SetNoiseLevel(value),
            ),
        ],
      ),
      // Crowd level and general mood, which the brief also asks for, are not
      // here: `ContextSnapshot` has no field for either and the engine scores
      // neither. Adding an option the engine ignores would be a control that
      // does nothing. See docs/RADIAL_MENU.md.
    ],
  );
}

// --- Tone ------------------------------------------------------------------

RadialMenuNode _tone() {
  return RadialMenuNode(
    id: 'tone',
    labelKey: 'radial.tone',
    iconId: 'tone',
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'tone.register',
        labelKey: 'radial.tone.register',
        iconId: 'register',
        allowMultipleSelection: true,
        children: <RadialMenuNode>[
          for (final value in Tone.values)
            RadialMenuNode(
              id: 'tone.register.${value.name}',
              labelKey: 'tone.${value.name}',
              iconId: 'tone.${value.name}',
              action: ToggleTone(value),
            ),
        ],
      ),
      RadialMenuNode(
        id: 'tone.directness',
        labelKey: 'radial.tone.directness',
        iconId: 'directness',
        children: <RadialMenuNode>[
          for (var level = kMinDirectness; level <= kMaxDirectness; level++)
            RadialMenuNode(
              id: 'tone.directness.$level',
              labelKey: 'radial.directness.$level',
              iconId: 'directness.$level',
              action: SetDirectness(level),
            ),
        ],
      ),
    ],
  );
}

// --- Caution ---------------------------------------------------------------

RadialMenuNode _caution() {
  return RadialMenuNode(
    id: 'caution',
    labelKey: 'radial.caution',
    iconId: 'caution',
    allowMultipleSelection: true,
    children: <RadialMenuNode>[
      for (final value in ToggleCaution.settable)
        RadialMenuNode(
          id: 'caution.${value.name}',
          labelKey: 'avoid.${value.name}',
          iconId: 'avoid.${value.name}',
          action: ToggleCaution(value),
        ),
      const RadialMenuNode(
        id: 'caution.clear',
        labelKey: 'radial.caution.clear',
        iconId: 'clearDimension',
        action: RunCommand(RadialCommand.clearDimension),
      ),
    ],
  );
}

// --- Finish and presets ----------------------------------------------------

RadialMenuNode _finish() {
  return const RadialMenuNode(
    id: 'finish',
    labelKey: 'radial.finish',
    iconId: 'finish',
    children: <RadialMenuNode>[
      RadialMenuNode(
        id: 'finish.show',
        labelKey: 'radial.showLines',
        iconId: 'showLines',
        action: RunCommand(RadialCommand.showRecommendations),
      ),
      RadialMenuNode(
        id: 'finish.presets',
        labelKey: 'radial.presets',
        iconId: 'presets',
        action: RunCommand(RadialCommand.savedPresets),
      ),
      RadialMenuNode(
        id: 'finish.recent',
        labelKey: 'radial.recent',
        iconId: 'recent',
        action: RunCommand(RadialCommand.recentContexts),
      ),
      RadialMenuNode(
        id: 'finish.savePreset',
        labelKey: 'radial.savePreset',
        iconId: 'savePreset',
        action: RunCommand(RadialCommand.savePreset),
      ),
      RadialMenuNode(
        id: 'finish.useScan',
        labelKey: 'radial.useScanResult',
        iconId: 'useScan',
        action: RunCommand(RadialCommand.useScanResult),
      ),
      RadialMenuNode(
        id: 'finish.undo',
        labelKey: 'radial.undo',
        iconId: 'undo',
        action: RunCommand(RadialCommand.undo),
      ),
      RadialMenuNode(
        id: 'finish.clear',
        labelKey: 'radial.clearAll',
        iconId: 'clearAll',
        action: RunCommand(RadialCommand.clearAll),
      ),
      RadialMenuNode(
        id: 'finish.detailed',
        labelKey: 'radial.detailedEditor',
        iconId: 'detailedEditor',
        action: RunCommand(RadialCommand.detailedEditor),
      ),
    ],
  );
}
