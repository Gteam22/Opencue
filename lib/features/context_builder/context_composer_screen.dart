import 'package:flutter/material.dart';

import '../../domain/context/context_draft.dart';
import '../../domain/context/radial_menu_tree.dart';
import '../../domain/models/context_preset.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_scope.dart';
import 'context_builder_screen.dart';
import 'context_chips.dart';
import 'radial_context_menu.dart';

/// The radial context composer.
///
/// Opened from the home screen's *Choose situation* action and from the
/// *Adjust* button on the recommendations and scan-confirmation screens. It
/// hosts [ContextRadialMenu] over a chip summary and a preset strip; all three
/// write to the same [RadialMenuController.draft], and nothing is committed to
/// [AppState] until the user applies.
///
/// Returns the applied [ContextDraft], or null when cancelled.
class ContextComposerScreen extends StatefulWidget {
  const ContextComposerScreen({
    super.key,
    required this.initialDraft,
    this.openAtBranchId,
    this.scanDraft,
  });

  final ContextDraft initialDraft;

  /// Opens the menu already descended to a branch, for chip taps.
  final String? openAtBranchId;

  /// The draft as the scan produced it, so *Use scan* can restore it after
  /// the user has made corrections they want to undo wholesale.
  final ContextDraft? scanDraft;

  static Future<ContextDraft?> push(
    BuildContext context, {
    required ContextDraft initialDraft,
    String? openAtBranchId,
    ContextDraft? scanDraft,
  }) {
    return Navigator.of(context).push<ContextDraft>(
      MaterialPageRoute<ContextDraft>(
        builder: (_) => ContextComposerScreen(
          initialDraft: initialDraft,
          openAtBranchId: openAtBranchId,
          scanDraft: scanDraft,
        ),
      ),
    );
  }

  @override
  State<ContextComposerScreen> createState() => _ContextComposerScreenState();
}

class _ContextComposerScreenState extends State<ContextComposerScreen> {
  late final RadialMenuController _controller =
      RadialMenuController(draft: widget.initialDraft)
        ..addListener(_onControllerChanged);

  @override
  void initState() {
    super.initState();
    final branch = widget.openAtBranchId;
    if (branch != null) {
      // Deferred so the first frame has a size for the placement solver.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.openAt(branch, pinned: true);
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _apply(ContextDraft draft) {
    AppScope.read(context).applyDraft(draft);
    Navigator.of(context).pop(draft);
  }

  Future<void> _handleCommand(RadialCommand command) async {
    final state = AppScope.read(context);
    switch (command) {
      case RadialCommand.detailedEditor:
      case RadialCommand.openListFallback:
        await _openFallback();
      case RadialCommand.savedPresets:
      case RadialCommand.recentContexts:
        await _openPresets(recentOnly: command == RadialCommand.recentContexts);
      case RadialCommand.savePreset:
        await _savePreset();
      case RadialCommand.useScanResult:
        final scan = widget.scanDraft;
        if (scan != null) _controller.setDraft(scan);
      case RadialCommand.restoreDefaults:
        _controller.setDraft(
          ContextDraft.empty(
            defaultDirectness: state.settings.defaultDirectness,
          ),
        );
      case RadialCommand.showRecommendations:
      case RadialCommand.clearAll:
      case RadialCommand.clearDimension:
      case RadialCommand.undo:
        // Handled inside the controller.
        break;
    }
  }

  Future<void> _openFallback({String? branchId}) async {
    final applied = await ContextListFallback.show(
      context,
      draft: _controller.draft,
      initialBranchId: branchId,
    );
    if (applied != null) _controller.setDraft(applied);
  }

  Future<void> _openDetailedEditor() async {
    // The conventional multi-page editor stays available and edits the same
    // draft; it is not a lesser path.
    final result = await Navigator.of(context).push<ContextDraft>(
      MaterialPageRoute<ContextDraft>(
        builder: (_) => ContextBuilderScreen(
          initialDraft: _controller.draft,
          returnsDraft: true,
        ),
      ),
    );
    if (result != null) _controller.setDraft(result);
  }

  Future<void> _savePreset() async {
    final strings = AppScope.strings(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('preset.save')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: strings.t('preset.nameHint'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.t('action.cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(strings.t('action.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final state = AppScope.read(context);
    state.setDraft(_controller.draft);
    await state.saveCurrentAsPreset(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppScope.strings(context).t('preset.saved'))),
    );
  }

  Future<void> _openPresets({required bool recentOnly}) async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final presets = recentOnly ? state.recentPresets : state.presets;
    final chosen = await showModalBottomSheet<ContextPreset>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => _PresetSheet(
        presets: presets,
        strings: strings,
        title: strings
            .t(recentOnly ? 'preset.recent' : 'preset.title'),
      ),
    );
    if (chosen == null || !mounted) return;
    _controller.setDraft(chosen.draft);
    await AppScope.read(context).applyPreset(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final state = AppScope.of(context);
    final handedness = state.settings.radialHandedness;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('context.chooseSituation')),
        actions: <Widget>[
          IconButton(
            tooltip: strings.t('radial.undo'),
            onPressed: _controller.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: strings.t('radial.openAsList'),
            onPressed: () => _openFallback(),
            icon: const Icon(Icons.list),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ContextChipRow(
                draft: _controller.draft,
                onChipTap: (branchId) =>
                    _controller.openAt(branchId, pinned: true),
                onChipClear: (dimension) => _controller.setDraft(
                  _controller.draft.clearDimension(dimension),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _PresetStrip(
                  presets: state.presets,
                  strings: strings,
                  onTap: (preset) async {
                    _controller.setDraft(preset.draft);
                    await AppScope.read(context).applyPreset(preset);
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: _openDetailedEditor,
                        icon: const Icon(Icons.tune),
                        label: Text(strings.t('context.openDetailed')),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => _apply(_controller.draft),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(strings.t('context.applyAndShow')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // The menu overlays everything, and its own trigger sits bottom
          // right within the thumb arc.
          Positioned.fill(
            child: ContextRadialMenu(
              controller: _controller,
              handedness: handedness,
              hapticsEnabled: state.settings.radialHapticsEnabled,
              onApply: _apply,
              onCommand: (command) => _handleCommand(command),
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal strip of saved contexts, shown behind the radial trigger.
class _PresetStrip extends StatelessWidget {
  const _PresetStrip({
    required this.presets,
    required this.strings,
    required this.onTap,
  });

  final List<ContextPreset> presets;
  final AppLocalizations strings;
  final ValueChanged<ContextPreset> onTap;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            strings.t('preset.none'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        Text(
          strings.t('preset.title'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final preset in presets)
              ActionChip(
                avatar: preset.isFavorite
                    ? const Icon(Icons.star, size: 16)
                    : null,
                label: Text(_nameOf(preset, strings)),
                onPressed: () => onTap(preset),
              ),
          ],
        ),
      ],
    );
  }
}

/// Starter presets carry a localization key; user presets carry literal text.
String _nameOf(ContextPreset preset, AppLocalizations strings) =>
    preset.nameIsLocalizationKey ? strings.t(preset.name) : preset.name;

class _PresetSheet extends StatelessWidget {
  const _PresetSheet({
    required this.presets,
    required this.strings,
    required this.title,
  });

  final List<ContextPreset> presets;
  final AppLocalizations strings;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (presets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(strings.t('preset.none')),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: presets.length,
                itemBuilder: (_, index) {
                  final preset = presets[index];
                  return ListTile(
                    leading: preset.isFavorite
                        ? const Icon(Icons.star)
                        : const Icon(Icons.bookmark_outline),
                    title: Text(_nameOf(preset, strings)),
                    onTap: () => Navigator.of(context).pop(preset),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
