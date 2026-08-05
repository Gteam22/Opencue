import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/context/context_draft.dart';
import '../../domain/context/radial_geometry.dart';
import '../../domain/context/radial_menu_tree.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_scope.dart';

/// The radial context menu.
///
/// One widget, two interaction modes over the same tree:
///
/// * **Hold-and-drag** — press the trigger, the ring opens under the thumb,
///   drag outward into a sector to descend, release on a leaf to select,
///   release in the central dead zone to cancel.
/// * **Pinned** — tap the trigger, the menu stays open, tap sectors to
///   navigate, tap the centre to finish. Drag inward or press the back
///   affordance to go up a layer.
///
/// The widget owns no context state. It reads and writes a [ContextDraft]
/// through [RadialMenuController], which the scan-correction sheet, the
/// detailed editor and the list fallback share, so there is exactly one draft
/// no matter which surface edits it.
///
/// Rendering is a single [CustomPaint] behind a [RepaintBoundary]; pointer
/// movement invalidates only that painter via the controller's
/// [Listenable], never the surrounding tree, and no database work happens on
/// any pointer event.

// ---------------------------------------------------------------------------
// Icon resolution
// ---------------------------------------------------------------------------

/// Maps the tree's icon identifiers to Material icons.
///
/// The tree stores strings so `lib/domain` stays Flutter-free; this is the
/// one place they become [IconData]. Unknown identifiers fall back to a
/// category glyph rather than throwing, so adding a node before an icon does
/// not crash the menu.
abstract final class RadialIcons {
  static const Map<String, IconData> _byId = <String, IconData>{
    'root': Icons.explore_outlined,
    'place': Icons.place_outlined,
    'people': Icons.people_outlined,
    'activity': Icons.directions_walk,
    'cue': Icons.visibility_outlined,
    'atmosphere': Icons.waves_outlined,
    'tone': Icons.record_voice_over_outlined,
    'caution': Icons.report_problem_outlined,
    'finish': Icons.check_circle_outlined,
    // Place groups and venues.
    'foodDrink': Icons.local_cafe_outlined,
    'nightlife': Icons.nightlife,
    'transit': Icons.train_outlined,
    'outdoors': Icons.park_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'events': Icons.celebration_outlined,
    'fitness': Icons.fitness_center,
    'other': Icons.more_horiz,
    'cafe': Icons.local_cafe_outlined,
    'restaurant': Icons.restaurant_outlined,
    'convenienceStore': Icons.storefront_outlined,
    'convenienceStore2': Icons.storefront_outlined,
    'bar': Icons.local_bar_outlined,
    'standingBar': Icons.sports_bar_outlined,
    'club': Icons.music_note_outlined,
    'party': Icons.cake_outlined,
    'station': Icons.train_outlined,
    'platform': Icons.railway_alert_outlined,
    'concourse': Icons.transfer_within_a_station,
    'gate': Icons.door_sliding_outlined,
    'trainInterior': Icons.airline_seat_recline_normal_outlined,
    'busStop': Icons.directions_bus_outlined,
    'publicTransport': Icons.commute_outlined,
    'street': Icons.signpost_outlined,
    'park': Icons.park_outlined,
    'waterfront': Icons.water_outlined,
    'shoppingArea': Icons.shopping_bag_outlined,
    'bookstore': Icons.menu_book_outlined,
    'festival': Icons.festival_outlined,
    'cosplayEvent': Icons.theater_comedy_outlined,
    'concert': Icons.mic_external_on_outlined,
    'languageExchange': Icons.translate,
    'meetup': Icons.groups_outlined,
    'gym': Icons.fitness_center,
    'kickboxingClass': Icons.sports_mma_outlined,
    'waitingLine': Icons.linear_scale,
    'search': Icons.search,
    // People.
    'peopleCount': Icons.tag,
    'interaction': Icons.sync_alt,
    'eyeContact': Icons.remove_red_eye_outlined,
    'smile': Icons.sentiment_satisfied_alt_outlined,
    'conversation': Icons.forum_outlined,
    'sharedActivity': Icons.handshake_outlined,
    // Activity groups.
    'stillness': Icons.airline_seat_recline_normal_outlined,
    'movement': Icons.directions_walk,
    'consuming': Icons.restaurant_outlined,
    'browsingGroup': Icons.storefront_outlined,
    'social': Icons.groups_outlined,
    // Cue groups.
    'appearance': Icons.checkroom_outlined,
    'object': Icons.category_outlined,
    'shared': Icons.public,
    // Atmosphere.
    'noise': Icons.graphic_eq,
    // Tone.
    'register': Icons.record_voice_over_outlined,
    'directness': Icons.speed_outlined,
    // Finish.
    'showLines': Icons.play_arrow_rounded,
    'presets': Icons.bookmarks_outlined,
    'recent': Icons.history,
    'savePreset': Icons.bookmark_add_outlined,
    'useScan': Icons.center_focus_strong_outlined,
    'undo': Icons.undo,
    'clearAll': Icons.backspace_outlined,
    'clearDimension': Icons.layers_clear_outlined,
    'detailedEditor': Icons.tune,
  };

  static const Map<String, IconData> _byPrefix = <String, IconData>{
    'groupSize': Icons.people_outlined,
    'activity': Icons.directions_walk,
    'cue': Icons.visibility_outlined,
    'noiseLevel': Icons.graphic_eq,
    'tone': Icons.record_voice_over_outlined,
    'avoid': Icons.report_problem_outlined,
    'directness': Icons.speed_outlined,
  };

  static IconData resolve(String iconId) {
    final direct = _byId[iconId];
    if (direct != null) return direct;
    final dot = iconId.indexOf('.');
    if (dot > 0) {
      final byPrefix = _byPrefix[iconId.substring(0, dot)];
      if (byPrefix != null) return byPrefix;
    }
    return Icons.circle_outlined;
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// How the menu was opened, which decides what release does.
enum RadialMode { closed, held, pinned }

/// Owns the open path into the tree, the current page, the highlight, the
/// draft and its undo stack.
///
/// All geometry decisions delegate to [RadialGeometry], which is pure Dart
/// and separately tested; the controller's job is only to hold state and
/// translate hits into navigation or selection.
class RadialMenuController extends ChangeNotifier {
  RadialMenuController({
    RadialMenuNode? tree,
    ContextDraft? draft,
    this.maxSectorsPerRing = 8,
  })  : _tree = tree ?? buildRadialMenuTree(),
        _draft = draft ?? ContextDraft.empty();

  final int maxSectorsPerRing;
  final RadialMenuNode _tree;

  RadialMenuNode get tree => _tree;

  ContextDraft _draft;
  ContextDraft get draft => _draft;

  final List<ContextDraft> _undoStack = <ContextDraft>[];

  RadialMode _mode = RadialMode.closed;
  RadialMode get mode => _mode;
  bool get isOpen => _mode != RadialMode.closed;

  /// The branch nodes from the root down to the layer being shown. Always at
  /// least `[tree]` while open.
  final List<RadialMenuNode> _path = <RadialMenuNode>[];
  List<RadialMenuNode> get path => List.unmodifiable(_path);
  RadialMenuNode get currentBranch => _path.isEmpty ? _tree : _path.last;

  /// Zero-based page within the current layer, when it has more children
  /// than [maxSectorsPerRing].
  int _page = 0;
  int get page => _page;

  /// Index of the highlighted sector on the current page, or -1.
  int _highlight = -1;
  int get highlight => _highlight;

  /// The command the host should run, set on selection and consumed by the
  /// widget's callback. Kept out of the draft because commands are effects.
  RadialCommand? _pendingCommand;
  RadialCommand? takePendingCommand() {
    final command = _pendingCommand;
    _pendingCommand = null;
    return command;
  }

  // --- The visible sectors -------------------------------------------------

  /// The children of the current branch shown on the current page. When the
  /// layer pages, the final sector of each page is a synthetic "more" node.
  List<RadialMenuNode> get visibleSectors {
    final children = currentBranch.children;
    if (children.length <= maxSectorsPerRing) return children;
    final usable = maxSectorsPerRing - 1;
    final start = _page * usable;
    final slice = children.sublist(
      start,
      math.min(start + usable, children.length),
    );
    return <RadialMenuNode>[...slice, _moreNode];
  }

  static const RadialMenuNode _moreNode = RadialMenuNode(
    id: '_more',
    labelKey: 'radial.pageMore',
    iconId: 'other',
    // A leaf so hit-testing treats it uniformly; handled specially below.
    action: RunCommand(RadialCommand.openListFallback),
  );

  int get pageCount =>
      radialPageCount(currentBranch.children.length,
          maxPerPage: maxSectorsPerRing);

  // --- Opening and closing -------------------------------------------------

  void open({required bool pinned}) {
    _mode = pinned ? RadialMode.pinned : RadialMode.held;
    _path
      ..clear()
      ..add(_tree);
    _page = 0;
    _highlight = -1;
    notifyListeners();
  }

  /// Opens the menu already descended to the branch with [nodeId], for chips
  /// that jump straight to their own dimension.
  void openAt(String nodeId, {required bool pinned}) {
    final target = _tree.pathTo(nodeId);
    _mode = pinned ? RadialMode.pinned : RadialMode.held;
    _path
      ..clear()
      ..addAll(
        target == null
            ? <RadialMenuNode>[_tree]
            : target.where((n) => n.isBranch),
      );
    if (_path.isEmpty) _path.add(_tree);
    _page = 0;
    _highlight = -1;
    notifyListeners();
  }

  void close() {
    _mode = RadialMode.closed;
    _highlight = -1;
    notifyListeners();
  }

  // --- Navigation ----------------------------------------------------------

  void setHighlight(int index) {
    if (index == _highlight) return;
    _highlight = index;
    notifyListeners();
  }

  /// Descends into the highlighted branch, or pages when the highlighted
  /// sector is the synthetic "more" node. Returns true when something
  /// changed, so the gesture layer knows to fire a haptic.
  bool enterHighlighted() {
    if (_highlight < 0 || _highlight >= visibleSectors.length) return false;
    final node = visibleSectors[_highlight];
    if (identical(node, _moreNode)) {
      _page = (_page + 1) % pageCount;
      _highlight = -1;
      notifyListeners();
      return true;
    }
    if (!node.isBranch) return false;
    _path.add(node);
    _page = 0;
    _highlight = -1;
    notifyListeners();
    return true;
  }

  /// Goes up one layer. Returns false at the root, where the caller decides
  /// whether that closes the menu.
  bool back() {
    if (_path.length <= 1) return false;
    _path.removeLast();
    _page = 0;
    _highlight = -1;
    notifyListeners();
    return true;
  }

  // --- Selection -----------------------------------------------------------

  /// Applies the highlighted leaf to the draft. Returns the node selected, or
  /// null when the highlight was not a selectable leaf.
  RadialMenuNode? selectHighlighted() {
    if (_highlight < 0 || _highlight >= visibleSectors.length) return null;
    final node = visibleSectors[_highlight];
    if (identical(node, _moreNode)) {
      _page = (_page + 1) % pageCount;
      _highlight = -1;
      notifyListeners();
      return null;
    }
    final action = node.action;
    if (action == null) return null;
    if (action is RunCommand) {
      _runCommand(action.command);
    } else {
      _pushUndo();
      _draft = _draft.apply(action);
    }
    notifyListeners();
    return node;
  }

  void _runCommand(RadialCommand command) {
    switch (command) {
      case RadialCommand.undo:
        undo();
      case RadialCommand.clearAll:
        _pushUndo();
        _draft = ContextDraft.empty(
          defaultTones: _draft.preferredTones,
          defaultDirectness: _draft.directness,
        );
      case RadialCommand.clearDimension:
        _pushUndo();
        _draft = _draft.clearDimension(ContextDimension.caution);
      // Everything else is an effect the host performs: navigation to the
      // results screen, sheets, the detailed editor. Handed out through
      // takePendingCommand.
      case RadialCommand.showRecommendations:
      case RadialCommand.useScanResult:
      case RadialCommand.restoreDefaults:
      case RadialCommand.recentContexts:
      case RadialCommand.savedPresets:
      case RadialCommand.savePreset:
      case RadialCommand.detailedEditor:
      case RadialCommand.openListFallback:
        _pendingCommand = command;
    }
  }

  void _pushUndo() {
    _undoStack.add(_draft);
    // Bounded so a long session cannot grow without limit.
    if (_undoStack.length > 32) _undoStack.removeAt(0);
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _draft = _undoStack.removeLast();
    notifyListeners();
  }

  /// Replaces the draft wholesale — used by the scan sheet, presets and the
  /// detailed editor, which all edit this same controller.
  void setDraft(ContextDraft draft, {bool recordUndo = true}) {
    if (recordUndo) _pushUndo();
    _draft = draft;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// The widget
// ---------------------------------------------------------------------------

class ContextRadialMenu extends StatefulWidget {
  const ContextRadialMenu({
    super.key,
    required this.controller,
    required this.onApply,
    this.onCommand,
    this.handedness = RadialHandedness.automatic,
    this.hapticsEnabled = true,
    this.triggerBuilder,
  });

  final RadialMenuController controller;

  /// Called when the user finishes — centre tap in pinned mode, or the Show
  /// lines leaf. Receives the applied draft; the host converts it to a
  /// snapshot and recalculates.
  final ValueChanged<ContextDraft> onApply;

  /// Called for commands the host must perform (presets sheet, detailed
  /// editor, list fallback, use-scan).
  final ValueChanged<RadialCommand>? onCommand;

  final RadialHandedness handedness;
  final bool hapticsEnabled;

  /// Builds the trigger button. Defaults to a FAB-like circle. The trigger
  /// receives the gesture callbacks; hold opens held mode, tap opens pinned.
  final Widget Function(BuildContext, VoidCallback onTap)? triggerBuilder;

  @override
  State<ContextRadialMenu> createState() => _ContextRadialMenuState();
}

class _ContextRadialMenuState extends State<ContextRadialMenu>
    with SingleTickerProviderStateMixin {
  RadialMenuController get _controller => widget.controller;

  late final AnimationController _openAnimation;

  /// Menu centre in the local coordinates of the overlay area.
  Offset _centre = Offset.zero;
  RadialGeometry _geometry = const RadialGeometry(sectorCount: 8);
  RadialPlacement? _placement;

  /// Set while the finger is beyond the expand threshold, which is what makes
  /// the current highlight's children a live child ring.
  bool _childLayerOpen = false;

  /// Last sector a haptic fired for, so each transition clicks once rather
  /// than every pointer move.
  int _lastHapticIndex = -1;

  /// Focus for keyboard navigation on desktop.
  final FocusNode _focusNode = FocusNode(debugLabel: 'radialMenu');

  @override
  void initState() {
    super.initState();
    _openAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _openAnimation.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _haptic(void Function() feedback) {
    if (!widget.hapticsEnabled) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return; // Never on Windows; keeps the desktop build path inert.
    }
    feedback();
  }

  // --- Opening -------------------------------------------------------------

  void _openMenu({required bool pinned, required Offset globalPosition}) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    final padding = MediaQuery.of(context).padding;

    final placement = RadialPlacement.solve(
      requestedX: local.dx,
      requestedY: local.dy,
      width: size.width,
      height: size.height,
      radius: _geometry.childOuterRadius + 28,
      safeLeft: padding.left,
      safeTop: padding.top,
      safeRight: padding.right,
      safeBottom: padding.bottom,
      handedness: widget.handedness,
    );

    setState(() {
      _placement = placement;
      _centre = Offset(placement.centreX, placement.centreY);
      _childLayerOpen = false;
      _lastHapticIndex = -1;
    });
    _controller.open(pinned: pinned);
    _syncGeometry();
    if (_reduceMotion) {
      _openAnimation.value = 1;
    } else {
      _openAnimation.forward(from: 0);
    }
    _haptic(HapticFeedback.selectionClick);
    if (pinned) _focusNode.requestFocus();
  }

  void _syncGeometry() {
    final placement = _placement;
    _geometry = RadialGeometry(
      sectorCount: math.max(1, _controller.visibleSectors.length),
      startAngle: placement?.startAngle ?? 0,
      sweep: placement?.sweep ?? 2 * math.pi,
    );
  }

  void _closeMenu({bool cancelled = false}) {
    if (cancelled) _haptic(HapticFeedback.lightImpact);
    _controller.close();
    _openAnimation.value = 0;
  }

  // --- Held-mode pointer handling ------------------------------------------

  void _onDragUpdate(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final hit = _geometry.hitTest(
      local.dx - _centre.dx,
      local.dy - _centre.dy,
      childLayerOpen: _childLayerOpen,
    );

    if (hit.zone == RadialZone.deadZone) {
      // Drawn back to the centre: close the child layer, then step up a
      // layer if drawn back again after the collapse settles.
      if (_childLayerOpen &&
          _geometry.crossesCollapseThreshold(hit.distance)) {
        setState(() => _childLayerOpen = false);
        _controller.back();
        _syncGeometry();
        _haptic(HapticFeedback.selectionClick);
      }
      _controller.setHighlight(-1);
    } else if (hit.index >= 0) {
      if (hit.index != _controller.highlight) {
        _controller.setHighlight(hit.index);
        if (hit.index != _lastHapticIndex) {
          _lastHapticIndex = hit.index;
          _haptic(HapticFeedback.selectionClick);
        }
      }
      // Crossing outward over the threshold opens the highlighted branch.
      if (!_childLayerOpen &&
          _geometry.crossesExpandThreshold(hit.distance)) {
        final node = _controller.visibleSectors[hit.index];
        if (node.isBranch) {
          if (_controller.enterHighlighted()) {
            setState(() => _childLayerOpen = false);
            _syncGeometry();
            _haptic(HapticFeedback.mediumImpact);
          }
        }
      }
    }
  }

  void _onDragEnd(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      _closeMenu(cancelled: true);
      return;
    }
    final local = box.globalToLocal(globalPosition);
    final hit = _geometry.hitTest(
      local.dx - _centre.dx,
      local.dy - _centre.dy,
      childLayerOpen: _childLayerOpen,
    );

    if (!hit.selectsSomething) {
      // Release in the dead zone or off a partial fan: cancel, select
      // nothing. The draft is untouched, as the brief requires.
      _closeMenu(cancelled: true);
      return;
    }

    _controller.setHighlight(hit.index);
    final node = _controller.visibleSectors[hit.index];
    if (node.isBranch) {
      // Released on a branch: reopen pinned at that branch rather than
      // guessing a child, so a short gesture cannot select by accident.
      _controller.enterHighlighted();
      _controller._mode = RadialMode.pinned;
      _syncGeometry();
      setState(() {});
      return;
    }
    final selected = _controller.selectHighlighted();
    if (selected != null) _haptic(HapticFeedback.mediumImpact);
    _afterSelection(selected);
  }

  void _afterSelection(RadialMenuNode? selected) {
    final command = _controller.takePendingCommand();
    if (command != null) {
      _closeMenu();
      if (command == RadialCommand.showRecommendations) {
        widget.onApply(_controller.draft);
      } else {
        widget.onCommand?.call(command);
      }
      return;
    }
    if (selected == null) return;
    final action = selected.action;
    if (_controller.mode == RadialMode.held) {
      // One continuous gesture ends at the selection.
      _closeMenu();
      widget.onApply(_controller.draft);
    } else if (action != null && !action.isMultiSelect) {
      // Pinned single-select: step back up so the next dimension is one tap
      // away. Multi-select layers stay open for further toggles.
      _controller.back();
      _syncGeometry();
    }
  }

  // --- Pinned-mode taps ----------------------------------------------------

  void _onPinnedTap(Offset localPosition) {
    final hit = _geometry.hitTest(
      localPosition.dx - _centre.dx,
      localPosition.dy - _centre.dy,
    );
    if (hit.zone == RadialZone.deadZone) {
      // Centre tap finishes.
      _closeMenu();
      widget.onApply(_controller.draft);
      return;
    }
    if (hit.index < 0) return;
    _controller.setHighlight(hit.index);
    final node = _controller.visibleSectors[hit.index];
    if (node.isBranch) {
      _controller.enterHighlighted();
      _syncGeometry();
      _haptic(HapticFeedback.selectionClick);
    } else {
      final selected = _controller.selectHighlighted();
      if (selected != null) _haptic(HapticFeedback.mediumImpact);
      _afterSelection(selected);
    }
  }

  // --- Keyboard (Windows) --------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_controller.isOpen || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final count = _controller.visibleSectors.length;
    final current = _controller.highlight;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      _controller.setHighlight((current + 1) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      _controller.setHighlight((current - 1 + count) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      final nodeUnder = current >= 0 && current < count
          ? _controller.visibleSectors[current]
          : null;
      if (nodeUnder == null) return KeyEventResult.handled;
      if (nodeUnder.isBranch) {
        _controller.enterHighlighted();
        _syncGeometry();
      } else {
        _afterSelection(_controller.selectHighlighted());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (!_controller.back()) _closeMenu(cancelled: true);
      _syncGeometry();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (!_controller.back()) {
        _closeMenu(cancelled: true);
      } else {
        _syncGeometry();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final open = _controller.isOpen;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Stack(
        children: <Widget>[
          if (open) ...<Widget>[
            // Scrim. Tapping it in pinned mode cancels.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _controller.mode == RadialMode.pinned
                    ? () => _closeMenu(cancelled: true)
                    : null,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32),
                ),
              ),
            ),
            Positioned.fill(
              child: _buildMenuSurface(strings),
            ),
          ],
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildTrigger(context, strings),
          ),
        ],
      ),
    );
  }

  Widget _buildTrigger(BuildContext context, AppLocalizations strings) {
    if (widget.triggerBuilder != null) {
      return widget.triggerBuilder!(
        context,
        () => _openMenu(
          pinned: true,
          globalPosition: _triggerGlobalCentre(context),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: strings.t('radial.hint.holdDrag'),
      hint: strings.t('radial.hint.tapToPin'),
      child: GestureDetector(
        onTap: () => _openMenu(
          pinned: true,
          globalPosition: _triggerGlobalCentre(context),
        ),
        onLongPressStart: (details) =>
            _openMenu(pinned: false, globalPosition: details.globalPosition),
        onLongPressMoveUpdate: (details) =>
            _onDragUpdate(details.globalPosition),
        onLongPressEnd: (details) => _onDragEnd(details.globalPosition),
        child: Material(
          color: scheme.primaryContainer,
          elevation: 3,
          shape: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Icon(Icons.explore_outlined,
                color: scheme.onPrimaryContainer, size: 28),
          ),
        ),
      ),
    );
  }

  Offset _triggerGlobalCentre(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final size = box.size;
    return box.localToGlobal(
      Offset(size.width - 16 - 32, size.height - 16 - 32),
    );
  }

  Widget _buildMenuSurface(AppLocalizations strings) {
    final theme = Theme.of(context);
    final sectors = _controller.visibleSectors;
    _syncGeometry();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _controller.mode == RadialMode.pinned
          ? (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              _onPinnedTap(box.globalToLocal(details.globalPosition));
            }
          : null,
      onPanUpdate: _controller.mode == RadialMode.held
          ? (details) => _onDragUpdate(details.globalPosition)
          : null,
      onPanEnd: _controller.mode == RadialMode.held
          ? (details) => _onDragEnd(details.globalPosition)
          : null,
      child: Semantics(
        label: strings.t('radial.root'),
        explicitChildNodes: true,
        child: Stack(
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _RadialPainter(
                  controller: _controller,
                  geometry: _geometry,
                  centre: _centre,
                  colorScheme: theme.colorScheme,
                  textTheme: theme.textTheme,
                  strings: strings,
                  progress: _reduceMotion
                      ? const AlwaysStoppedAnimation<double>(1)
                      : _openAnimation,
                  draft: _controller.draft,
                ),
              ),
            ),
            // Invisible but focusable semantic targets, one per sector, so a
            // screen reader can reach every option without the painter.
            for (var i = 0; i < sectors.length; i++)
              _semanticSectorTarget(i, sectors[i], strings),
            _breadcrumb(strings, theme),
            _centreLabel(strings, theme),
          ],
        ),
      ),
    );
  }

  Widget _semanticSectorTarget(
      int index, RadialMenuNode node, AppLocalizations strings) {
    final angle = _geometry.centreAngleOf(index);
    final radius = (_geometry.innerRadius + _geometry.outerRadius) / 2;
    final dx = _centre.dx + radius * math.sin(angle);
    final dy = _centre.dy - radius * math.cos(angle);
    final selected = node.action != null &&
        _controller.draft.isSelected(node.action!);
    return Positioned(
      left: dx - 24,
      top: dy - 24,
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        selected: selected,
        label: strings.t(node.labelKey),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _controller.mode == RadialMode.pinned
              ? () {
                  _controller.setHighlight(index);
                  if (node.isBranch) {
                    _controller.enterHighlighted();
                    _syncGeometry();
                  } else {
                    _afterSelection(_controller.selectHighlighted());
                  }
                }
              : null,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _breadcrumb(AppLocalizations strings, ThemeData theme) {
    final path = _controller.path;
    if (path.length <= 1) return const SizedBox.shrink();
    final labels = path.skip(1).map((n) => strings.t(n.labelKey)).join(' › ');
    return Positioned(
      left: 16,
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: strings.t('radial.back'),
            onPressed: () {
              if (!_controller.back()) _closeMenu(cancelled: true);
              _syncGeometry();
            },
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
          Expanded(
            child: Text(
              labels,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
          Text(
            strings.f(
              'radial.selectedCount',
              <Object?>[_controller.draft.establishedDimensionCount],
            ),
            style:
                theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _centreLabel(AppLocalizations strings, ThemeData theme) {
    final pinned = _controller.mode == RadialMode.pinned;
    return Positioned(
      left: _centre.dx - _geometry.deadZoneRadius,
      top: _centre.dy - _geometry.deadZoneRadius,
      width: _geometry.deadZoneRadius * 2,
      height: _geometry.deadZoneRadius * 2,
      child: Semantics(
        button: pinned,
        label: pinned
            ? strings.t('radial.done')
            : strings.t('radial.cancel'),
        child: IgnorePointer(
          // In pinned mode the surface's onTapUp handles the centre tap; this
          // is presentation only.
          child: Center(
            child: Text(
              pinned ? strings.t('radial.done') : strings.t('radial.cancel'),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _RadialPainter extends CustomPainter {
  _RadialPainter({
    required this.controller,
    required this.geometry,
    required this.centre,
    required this.colorScheme,
    required this.textTheme,
    required this.strings,
    required this.progress,
    required this.draft,
  }) : super(repaint: Listenable.merge(<Listenable>[controller, progress]));

  final RadialMenuController controller;
  final RadialGeometry geometry;
  final Offset centre;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations strings;
  final Animation<double> progress;
  final ContextDraft draft;

  // Label painters are cached per node id; pointer movement repaints arcs but
  // never re-lays-out text.
  static final Map<String, TextPainter> _labelCache = <String, TextPainter>{};

  /// The scheme the cache was built against. A theme change rebuilds every
  /// label rather than leaving light-mode text on a dark ring.
  static ColorScheme? _cacheScheme;

  /// A laid-out label, cached.
  ///
  /// [variant] discriminates the three foreground colours a sector can have,
  /// because a TextPainter bakes its colour into the span. Three short strings
  /// beat keying on the colour itself, which would tie the cache to whichever
  /// `Color` int accessor is current.
  TextPainter _label(RadialMenuNode node, Color color, String variant) {
    if (_cacheScheme != colorScheme) {
      _labelCache.clear();
      _cacheScheme = colorScheme;
    }
    final key = '${node.id}|${strings.mode.name}|$variant';
    final cached = _labelCache[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: strings.t(node.labelKey),
        style: textTheme.labelSmall?.copyWith(color: color, height: 1.1),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 72);
    // Bounded: the tree is finite and small.
    if (_labelCache.length > 512) _labelCache.clear();
    return _labelCache[key] = painter;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sectors = controller.visibleSectors;
    if (sectors.isEmpty) return;
    final t = Curves.easeOutCubic.transform(progress.value);
    final inner = geometry.innerRadius * t;
    final outer = geometry.outerRadius * t;

    final basePaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.6);

    for (var i = 0; i < sectors.length; i++) {
      final node = sectors[i];
      final highlighted = i == controller.highlight;
      final selected =
          node.action != null && draft.isSelected(node.action!);

      // Highlighted sector grows slightly, as the brief asks.
      final sectorOuter = highlighted ? outer + 8 : outer;
      final start = geometry.startAngleOf(i);
      final sweep = geometry.sectorSweep;

      basePaint.color = highlighted
          ? colorScheme.primary
          : selected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHigh.withValues(alpha: 0.96);

      final path = _sectorPath(start, sweep, inner, sectorOuter);
      canvas.drawShadow(path, Colors.black, highlighted ? 6.0 : 3.0, true);
      canvas.drawPath(path, basePaint);
      canvas.drawPath(path, strokePaint);

      // Icon + label at the sector centre.
      final mid = geometry.centreAngleOf(i);
      final labelRadius = (inner + sectorOuter) / 2;
      final cx = centre.dx + labelRadius * math.sin(mid);
      final cy = centre.dy - labelRadius * math.cos(mid);

      final (Color foreground, String variant) = highlighted
          ? (colorScheme.onPrimary, 'highlighted')
          : selected
              ? (colorScheme.onSecondaryContainer, 'selected')
              : (colorScheme.onSurface, 'base');

      _paintIcon(canvas, node, Offset(cx, cy - 12), foreground);
      final label = _label(node, foreground, variant);
      label.paint(
        canvas,
        Offset(cx - label.width / 2, cy + 2),
      );

      // Selection state is never colour alone: a checkmark for selected, a
      // scan glyph when the value came from a scan and is uncorrected.
      if (selected) {
        final dimension = _dimensionOf(node.action!);
        final origin = dimension == null
            ? DraftOrigin.fromUser
            : draft.originOf(dimension);
        final marker = origin == DraftOrigin.fromScan
            ? Icons.auto_awesome
            : Icons.check;
        _paintIconData(
          canvas,
          marker,
          Offset(cx + 22, cy - 22),
          14,
          foreground,
        );
      }

      // A subtle outward chevron on branches, so depth is discoverable.
      if (node.isBranch) {
        _paintIconData(
          canvas,
          Icons.chevron_right,
          Offset(
            centre.dx + (sectorOuter - 10) * math.sin(mid),
            centre.dy - (sectorOuter - 10) * math.cos(mid),
          ),
          14,
          foreground.withValues(alpha: 0.7),
        );
      }
    }

    // Dead zone disc.
    final centrePaint = Paint()
      ..color = colorScheme.surface.withValues(alpha: 0.95);
    canvas.drawCircle(centre, geometry.deadZoneRadius * t, centrePaint);
    canvas.drawCircle(
      centre,
      geometry.deadZoneRadius * t,
      strokePaint,
    );
  }

  ContextDimension? _dimensionOf(RadialSelectionAction action) {
    return switch (action) {
      SetLocation() => ContextDimension.location,
      SetActivity() => ContextDimension.activity,
      SetGroupSize() => ContextDimension.groupSize,
      SetNoiseLevel() => ContextDimension.noiseLevel,
      ToggleCue() => ContextDimension.cues,
      ToggleTone() => ContextDimension.tones,
      SetDirectness() => ContextDimension.directness,
      ToggleCaution() => ContextDimension.caution,
      ToggleInteraction(:final value) => switch (value) {
          InteractionFlag.eyeContact => ContextDimension.eyeContact,
          InteractionFlag.conversationStarted =>
            ContextDimension.conversationStarted,
        },
      RunCommand() => null,
    };
  }

  Path _sectorPath(
      double startAngle, double sweep, double inner, double outer) {
    // Convert clockwise-from-twelve to canvas radians (anticlockwise from
    // three o'clock is the canvas default; drawArc takes clockwise-positive
    // sweep from the +x axis).
    double canvasAngle(double a) => a - math.pi / 2;
    const gap = 0.02; // Small angular gap between sectors.
    final a0 = canvasAngle(startAngle) + gap;
    final a1 = canvasAngle(startAngle + sweep) - gap;
    final rect = Rect.fromCircle(center: centre, radius: outer);
    final innerRect = Rect.fromCircle(center: centre, radius: inner);
    return Path()
      ..arcStart(rect, a0)
      ..arcTo(rect, a0, a1 - a0, false)
      ..arcTo(innerRect, a1, a0 - a1, false)
      ..close();
  }

  void _paintIcon(
      Canvas canvas, RadialMenuNode node, Offset at, Color color) {
    _paintIconData(canvas, RadialIcons.resolve(node.iconId), at, 20, color);
  }

  void _paintIconData(
      Canvas canvas, IconData icon, Offset at, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_RadialPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.centre != centre ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.draft != draft;
  }
}

/// `Path` has no arcStart; this extension gives the painter a readable way to
/// begin at a point on an arc.
extension on Path {
  void arcStart(Rect rect, double angle) {
    moveTo(
      rect.center.dx + rect.width / 2 * math.cos(angle),
      rect.center.dy + rect.height / 2 * math.sin(angle),
    );
  }
}
