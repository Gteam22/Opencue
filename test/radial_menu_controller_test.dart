// Tests for RadialMenuController: the navigation, paging, selection, undo
// and cancel behaviour behind both gesture modes. The controller is plain
// state over the tree, so these run without pumping a widget; the gesture
// layer's own behaviour is covered in radial_menu_widget_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/context/context_draft.dart';
import 'package:opencue/domain/context/radial_menu_tree.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/features/context_builder/radial_context_menu.dart';

void main() {
  RadialMenuController controller() => RadialMenuController();

  int indexOf(RadialMenuController c, String id) =>
      c.visibleSectors.indexWhere((n) => n.id == id);

  group('opening and closing', () {
    test('opens at the root in either mode', () {
      final c = controller();
      expect(c.isOpen, isFalse);
      c.open(pinned: false);
      expect(c.mode, RadialMode.held);
      expect(c.currentBranch.id, 'root');
      c.close();
      expect(c.isOpen, isFalse);

      c.open(pinned: true);
      expect(c.mode, RadialMode.pinned);
    });

    test('openAt descends straight to a branch, for chip taps', () {
      final c = controller();
      c.openAt('place.foodDrink', pinned: true);
      expect(c.currentBranch.id, 'place.foodDrink');
      expect(c.path.map((n) => n.id), <String>['root', 'place',
          'place.foodDrink']);
    });

    test('openAt on a leaf opens its parent branch', () {
      final c = controller();
      c.openAt('place.tag.cafe', pinned: true);
      // The leaf itself is not a layer; the deepest branch above it is.
      expect(c.currentBranch.id, 'place.foodDrink');
    });

    test('openAt with an unknown id falls back to the root', () {
      final c = controller();
      c.openAt('nonsense', pinned: true);
      expect(c.currentBranch.id, 'root');
    });
  });

  group('navigation', () {
    test('entering a branch descends; back ascends; back at root refuses',
        () {
      final c = controller()..open(pinned: true);
      c.setHighlight(indexOf(c, 'place'));
      expect(c.enterHighlighted(), isTrue);
      expect(c.currentBranch.id, 'place');

      expect(c.back(), isTrue);
      expect(c.currentBranch.id, 'root');
      expect(c.back(), isFalse);
    });

    test('entering a leaf is refused', () {
      final c = controller()..open(pinned: true);
      c.setHighlight(indexOf(c, 'place'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'place.other'));
      c.enterHighlighted();
      // place.other is a branch; go one deeper to a leaf.
      c.setHighlight(indexOf(c, 'place.tag.waitingLine'));
      expect(c.enterHighlighted(), isFalse);
    });

    test('rapid open and close does not corrupt the path', () {
      final c = controller();
      for (var i = 0; i < 50; i++) {
        c.open(pinned: i.isEven);
        c.setHighlight(0);
        c.enterHighlighted();
        c.close();
      }
      c.open(pinned: true);
      expect(c.currentBranch.id, 'root');
      expect(c.path, hasLength(1));
    });
  });

  group('paging when a layer exceeds eight options', () {
    test('the Finish layer of eight fits one page with no more-node', () {
      final c = controller()..open(pinned: true);
      c.setHighlight(indexOf(c, 'finish'));
      c.enterHighlighted();
      expect(c.pageCount, 1);
      expect(c.visibleSectors.any((n) => n.id == '_more'), isFalse);
    });

    test('a layer of more than eight pages with a synthetic more-node', () {
      // The largest real layers currently hold eight or fewer, so page the
      // root of a synthetic tree to prove the mechanism.
      final wide = RadialMenuNode(
        id: 'wide',
        labelKey: 'radial.root',
        iconId: 'root',
        children: <RadialMenuNode>[
          for (var i = 0; i < 11; i++)
            RadialMenuNode(
              id: 'leaf$i',
              labelKey: 'radial.root',
              iconId: 'other',
              action: SetDirectness(1 + i % 5),
            ),
        ],
      );
      final c = RadialMenuController(tree: wide)..open(pinned: true);
      expect(c.pageCount, 2);
      expect(c.visibleSectors, hasLength(8));
      expect(c.visibleSectors.last.id, '_more');

      // Selecting the more-node advances the page and selects nothing.
      c.setHighlight(7);
      expect(c.selectHighlighted(), isNull);
      expect(c.page, 1);
      expect(c.visibleSectors.first.id, 'leaf7');
      // Second page also ends in "more", which wraps to page 0.
      c.setHighlight(c.visibleSectors.length - 1);
      c.selectHighlighted();
      expect(c.page, 0);
    });
  });

  group('selection', () {
    test('selecting a leaf applies it to the draft', () {
      final c = controller()..open(pinned: true);
      c.setHighlight(indexOf(c, 'place'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'place.foodDrink'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'place.tag.cafe'));
      final node = c.selectHighlighted();
      expect(node, isNotNull);
      expect(c.draft.location, LocationTag.cafe);
    });

    test('selecting with no highlight selects nothing', () {
      final c = controller()..open(pinned: true);
      c.setHighlight(-1);
      expect(c.selectHighlighted(), isNull);
      expect(c.draft.establishedDimensionCount,
          ContextDraft.empty().establishedDimensionCount);
    });

    test('show-recommendations surfaces as a pending command', () {
      final c = controller()..open(pinned: true);
      c.setHighlight(indexOf(c, 'finish'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'finish.show'));
      c.selectHighlighted();
      expect(c.takePendingCommand(), RadialCommand.showRecommendations);
      // Consumed exactly once.
      expect(c.takePendingCommand(), isNull);
    });
  });

  group('undo, clear and restore', () {
    test('undo pops exactly one selection', () {
      final c = controller()..open(pinned: true);
      c.setHighlight(indexOf(c, 'place'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'place.foodDrink'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'place.tag.cafe'));
      c.selectHighlighted();
      c.setHighlight(indexOf(c, 'place.tag.restaurant'));
      c.selectHighlighted();

      expect(c.draft.location, LocationTag.restaurant);
      c.undo();
      expect(c.draft.location, LocationTag.cafe);
      c.undo();
      expect(c.draft.location, LocationTag.other);
      expect(c.canUndo, isFalse);
      c.undo(); // A further undo on an empty stack is a no-op, not a throw.
      expect(c.draft.location, LocationTag.other);
    });

    test('clear-all resets values but keeps tone and directness defaults',
        () {
      final c = RadialMenuController(
        draft: ContextDraft.empty(
          defaultTones: <Tone>{Tone.playful},
          defaultDirectness: 4,
        ),
      )..open(pinned: true);
      c.setDraft(c.draft.apply(const SetLocation(LocationTag.bar)),
          recordUndo: false);

      c.setHighlight(indexOf(c, 'finish'));
      c.enterHighlighted();
      c.setHighlight(indexOf(c, 'finish.clear'));
      c.selectHighlighted();

      expect(c.draft.location, LocationTag.other);
      expect(c.draft.preferredTones, <Tone>{Tone.playful});
      expect(c.draft.directness, 4);
      // And clear-all itself is undoable.
      c.undo();
      expect(c.draft.location, LocationTag.bar);
    });

    test('setDraft is how scan and presets hand a draft in, undoably', () {
      final c = controller();
      final before = c.draft;
      final scanned =
          ContextDraft.empty().apply(const SetLocation(LocationTag.park));
      c.setDraft(scanned);
      expect(c.draft.location, LocationTag.park);
      c.undo();
      expect(c.draft, same(before));
    });
  });
}
