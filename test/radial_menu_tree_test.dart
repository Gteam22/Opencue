// Tests for the radial menu tree and the shared context draft.
//
// The tree test's central claim is the one the brief cares most about: no
// domain option is unreachable. Every value of every dimension the menu
// covers must appear as a leaf, generated from the enum itself, so an enum
// value added later cannot silently be missing from the menu.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/context/context_draft.dart';
import 'package:opencue/domain/context/radial_menu_tree.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/context_snapshot.dart';
import 'package:opencue/domain/scan/venue_category.dart';

void main() {
  final tree = buildRadialMenuTree();
  final allNodes = tree.walk().toList();
  final leaves = allNodes.where((n) => n.isLeaf).toList();

  group('tree integrity', () {
    test('node ids are unique', () {
      final ids = allNodes.map((n) => n.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every node is a branch or a leaf, never both or neither', () {
      for (final node in allNodes) {
        expect(node.isBranch ^ node.isLeaf, isTrue,
            reason: '${node.id} must have exactly one of children/action');
      }
    });

    test('the root has eight sectors, including manual conversations', () {
      expect(
        tree.children.map((n) => n.labelKey),
        <String>[
          'radial.location',
          'radial.people',
          'radial.loudness',
          'radial.surroundings',
          'radial.action',
          'radial.other',
          'radial.directness',
          'radial.conversationLibrary',
        ],
      );
      // Still inside the eight-sector ceiling.
      expect(tree.children.length, lessThanOrEqualTo(8));
    });

    test('caution is the first child of Other, so it stays one drag away', () {
      final other = tree.pathTo('finish')!.last;
      expect(other.children.first.id, 'caution');
    });

    test('the tree reaches three hierarchical layers', () {
      // Root -> Place -> Food & drink -> Café is depth 3 below the root.
      final path = tree.pathTo('place.tag.cafe');
      expect(path, isNotNull);
      expect(path!.length, 4);
    });

    test('pathTo finds every node and returns null for nonsense', () {
      for (final node in allNodes) {
        final path = tree.pathTo(node.id);
        expect(path, isNotNull, reason: node.id);
        expect(path!.last.id, node.id);
      }
      expect(tree.pathTo('no.such.node'), isNull);
    });

    test('label keys never contain raw display text', () {
      // Localization discipline: keys are dotted identifiers, not sentences.
      for (final node in allNodes) {
        expect(node.labelKey, matches(RegExp(r'^[a-zA-Z0-9_.]+$')),
            reason: '${node.id} labelKey "${node.labelKey}"');
      }
    });
  });

  group('no domain option is unreachable', () {
    Set<T> reachable<T>(Iterable<T?> values) =>
        values.whereType<T>().toSet();

    test('every LocationTag has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is SetLocation ? a.value : null));
      expect(covered, LocationTag.values.toSet());
    });

    test('every ActivityTag has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is SetActivity ? a.value : null));
      expect(covered, ActivityTag.values.toSet());
    });

    test('every GroupSize has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is SetGroupSize ? a.value : null));
      expect(covered, GroupSize.values.toSet());
    });

    test('every NoiseLevel has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is SetNoiseLevel ? a.value : null));
      expect(covered, NoiseLevel.values.toSet());
    });

    test('every ObservableCue has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is ToggleCue ? a.value : null));
      expect(covered, ObservableCue.values.toSet());
    });

    test('every Tone has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is ToggleTone ? a.value : null));
      expect(covered, Tone.values.toSet());
    });

    test('every directness level has a leaf', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is SetDirectness ? a.value : null));
      expect(covered,
          {for (var d = kMinDirectness; d <= kMaxDirectness; d++) d});
    });

    test('all five settable cautions have leaves, and only those five', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is ToggleCaution ? a.value : null));
      expect(covered, ToggleCaution.settable.toSet());
    });

    test('both interaction flags have leaves', () {
      final covered = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is ToggleInteraction ? a.value : null));
      expect(covered, InteractionFlag.values.toSet());
    });

    test('the Finish sector exposes the required commands', () {
      final commands = reachable(leaves
          .map((n) => n.action)
          .map((a) => a is RunCommand ? a.command : null));
      expect(
        commands,
        containsAll(<RadialCommand>[
          RadialCommand.showRecommendations,
          RadialCommand.clearAll,
          RadialCommand.useScanResult,
          RadialCommand.recentContexts,
          RadialCommand.savedPresets,
          RadialCommand.savePreset,
          RadialCommand.detailedEditor,
          RadialCommand.undo,
        ]),
      );
    });
  });

  group('multi-select marking', () {
    test('cue and caution branches allow multiple selection', () {
      bool allows(String id) =>
          tree.pathTo(id)!.last.allowMultipleSelection;
      expect(allows('cue'), isTrue);
      expect(allows('cue.object'), isTrue);
      expect(allows('caution'), isTrue);
      expect(allows('tone.register'), isTrue);
    });

    test('toggle actions report multi-select; setters do not', () {
      expect(const ToggleCue(ObservableCue.drink).isMultiSelect, isTrue);
      expect(const ToggleTone(Tone.playful).isMultiSelect, isTrue);
      expect(
        const ToggleCaution(AvoidCondition.personWorking).isMultiSelect,
        isTrue,
      );
      expect(const SetLocation(LocationTag.cafe).isMultiSelect, isFalse);
      expect(const SetGroupSize(GroupSize.alone).isMultiSelect, isFalse);
    });
  });

  group('context draft', () {
    test('applying selections accumulates dimensions', () {
      var draft = ContextDraft.empty(defaultDirectness: 2);
      draft = draft.apply(const SetLocation(LocationTag.cafe));
      draft = draft.apply(const SetGroupSize(GroupSize.alone));
      draft = draft.apply(const ToggleCue(ObservableCue.drink));
      draft = draft.apply(const ToggleTone(Tone.friendly));

      expect(draft.location, LocationTag.cafe);
      expect(draft.groupSize, GroupSize.alone);
      expect(draft.cues, <ObservableCue>{ObservableCue.drink});
      expect(draft.preferredTones, <Tone>{Tone.friendly});
      expect(draft.originOf(ContextDimension.location), DraftOrigin.fromUser);
    });

    test('multiple cues and multiple cautions combine', () {
      var draft = ContextDraft.empty();
      draft = draft.apply(const ToggleCue(ObservableCue.drink));
      draft = draft.apply(const ToggleCue(ObservableCue.book));
      draft = draft.apply(
        const ToggleCaution(AvoidCondition.personWorking),
      );
      draft = draft.apply(const ToggleCaution(AvoidCondition.headphonesOn));

      expect(draft.cues,
          <ObservableCue>{ObservableCue.drink, ObservableCue.book});
      expect(draft.cautions, <AvoidCondition>{
        AvoidCondition.personWorking,
        AvoidCondition.headphonesOn,
      });
    });

    test('toggling twice removes', () {
      var draft = ContextDraft.empty();
      draft = draft.apply(const ToggleCue(ObservableCue.drink));
      draft = draft.apply(const ToggleCue(ObservableCue.drink));
      expect(draft.cues, isEmpty);
    });

    test('cautions round-trip into snapshot flags and raise the advisory',
        () {
      var draft = ContextDraft.empty();
      draft = draft.apply(const SetLocation(LocationTag.cafe));
      draft = draft.apply(const ToggleCaution(AvoidCondition.personWorking));
      draft = draft.apply(const ToggleCaution(AvoidCondition.headphonesOn));

      final snapshot = draft.toSnapshot();
      expect(snapshot.isWorking, isTrue);
      expect(snapshot.isUsingHeadphones, isTrue);
      expect(snapshot.discouragesApproach, isTrue);
      expect(
        snapshot.activeAvoidConditions,
        containsAll(<AvoidCondition>[
          AvoidCondition.personWorking,
          AvoidCondition.headphonesOn,
        ]),
      );
    });

    test('venue subtype is preserved alongside the broad location', () {
      var draft = ContextDraft.empty();
      draft = draft.apply(const SetLocation(
        LocationTag.trainStation,
        venue: VenueCategory.trainPlatform,
      ));
      expect(draft.location, LocationTag.trainStation);
      expect(draft.venue, VenueCategory.trainPlatform);
      // The engine still sees only the broad tag.
      expect(draft.toSnapshot().location, LocationTag.trainStation);

      // Selecting a plain location clears the stale subtype.
      draft = draft.apply(const SetLocation(LocationTag.cafe));
      expect(draft.venue, isNull);
    });

    test('isSelected reflects the draft for every action kind', () {
      var draft = ContextDraft.empty(defaultDirectness: 3);
      draft = draft.apply(const SetLocation(LocationTag.bar));
      draft = draft.apply(const SetActivity(ActivityTag.drinking));
      draft = draft.apply(const SetNoiseLevel(NoiseLevel.loud));
      draft = draft.apply(
        const ToggleInteraction(InteractionFlag.eyeContact),
      );

      expect(draft.isSelected(const SetLocation(LocationTag.bar)), isTrue);
      expect(draft.isSelected(const SetLocation(LocationTag.cafe)), isFalse);
      expect(
          draft.isSelected(const SetActivity(ActivityTag.drinking)), isTrue);
      expect(draft.isSelected(const SetNoiseLevel(NoiseLevel.loud)), isTrue);
      expect(draft.isSelected(const SetDirectness(3)), isTrue);
      expect(
        draft.isSelected(
          const ToggleInteraction(InteractionFlag.eyeContact),
        ),
        isTrue,
      );
      expect(
        draft.isSelected(
          const ToggleInteraction(InteractionFlag.conversationStarted),
        ),
        isFalse,
      );
    });

    test('scan values preselect with fromScan and survive a correction', () {
      final scanned = ContextSnapshot(
        location: LocationTag.trainStation,
        groupSize: GroupSize.alone,
        source: ContextSource.cameraScan,
      );
      var draft = ContextDraft.fromSnapshot(
        scanned,
        venue: VenueCategory.trainPlatform,
      );

      expect(draft.originOf(ContextDimension.location), DraftOrigin.fromScan);
      expect(draft.originOf(ContextDimension.groupSize), DraftOrigin.fromScan);
      expect(draft.originOf(ContextDimension.activity), DraftOrigin.unset);
      expect(draft.venue, VenueCategory.trainPlatform);

      // The subway-correction acceptance case: user adds two people.
      draft = draft.apply(const SetGroupSize(GroupSize.withOneFriend));
      expect(draft.groupSize, GroupSize.withOneFriend);
      expect(draft.originOf(ContextDimension.groupSize), DraftOrigin.fromUser);
      // The uncorrected scan value keeps its provenance.
      expect(draft.originOf(ContextDimension.location), DraftOrigin.fromScan);
      // The corrected draft still round-trips through the engine's snapshot.
      expect(draft.toSnapshot().groupSize, GroupSize.withOneFriend);
      expect(draft.toSnapshot().source, ContextSource.cameraScan);
    });

    test('clearDimension resets one dimension and unsets its origin', () {
      var draft = ContextDraft.empty();
      draft = draft.apply(const SetLocation(
        LocationTag.trainStation,
        venue: VenueCategory.trainPlatform,
      ));
      draft = draft.apply(const ToggleCue(ObservableCue.waiting));

      draft = draft.clearDimension(ContextDimension.location);
      expect(draft.location, LocationTag.other);
      expect(draft.venue, isNull);
      expect(draft.originOf(ContextDimension.location), DraftOrigin.unset);
      // The other dimension is untouched.
      expect(draft.cues, <ObservableCue>{ObservableCue.waiting});
    });

    test('empty draft keeps saved tone and directness defaults', () {
      final draft = ContextDraft.empty(
        defaultTones: <Tone>{Tone.playful},
        defaultDirectness: 4,
      );
      expect(draft.preferredTones, <Tone>{Tone.playful});
      expect(draft.directness, 4);
      expect(draft.originOf(ContextDimension.tones), DraftOrigin.fromDefaults);
      expect(
        draft.originOf(ContextDimension.directness),
        DraftOrigin.fromDefaults,
      );
    });

    test('RunCommand leaves the draft untouched', () {
      final draft = ContextDraft.empty()
          .apply(const RunCommand(RadialCommand.showRecommendations));
      expect(draft.establishedDimensionCount, 1); // only the default marker
    });

    test('directness is clamped', () {
      final draft = ContextDraft.empty().apply(const SetDirectness(99));
      expect(draft.directness, kMaxDirectness);
    });
  });
}
