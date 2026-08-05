import 'package:flutter/material.dart';

import '../../domain/context/context_draft.dart';
import '../../domain/context/radial_menu_tree.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_scope.dart';

/// One established dimension of the draft, rendered as a chip.
///
/// Chips are the readable summary of a context and the shortcut into the
/// radial menu: tapping one opens the menu already descended to that
/// dimension's branch, so amending a context never starts from the root.
class ContextChipData {
  const ContextChipData({
    required this.dimension,
    required this.label,
    required this.branchId,
    required this.origin,
  });

  final ContextDimension dimension;
  final String label;

  /// The node the radial menu should open at when this chip is tapped.
  final String branchId;

  final DraftOrigin origin;
}

/// Builds the chip list for a draft. Only established dimensions appear;
/// an unset dimension is absent rather than shown as "unknown".
List<ContextChipData> contextChipsFor(
  ContextDraft draft,
  AppLocalizations strings,
) {
  final chips = <ContextChipData>[];

  void add(
    ContextDimension dimension,
    String label,
    String branchId,
  ) {
    if (draft.originOf(dimension) == DraftOrigin.unset) return;
    chips.add(ContextChipData(
      dimension: dimension,
      label: label,
      branchId: branchId,
      origin: draft.originOf(dimension),
    ));
  }

  // The venue subtype, when there is one, replaces the broad location on the
  // chip: "Platform" is more use than "Train station" when the user chose it.
  final venue = draft.venue;
  if (venue != null &&
      draft.originOf(ContextDimension.venue) != DraftOrigin.unset) {
    chips.add(ContextChipData(
      dimension: ContextDimension.venue,
      label: strings.t('venue.${venue.name}'),
      branchId: 'place.transit',
      origin: draft.originOf(ContextDimension.venue),
    ));
  } else {
    add(
      ContextDimension.location,
      strings.location(draft.location),
      'place',
    );
  }

  add(
    ContextDimension.groupSize,
    strings.groupSize(draft.groupSize),
    'people.count',
  );
  final activity = draft.activity;
  if (activity != null) {
    add(ContextDimension.activity, strings.activity(activity), 'activity');
  }
  add(
    ContextDimension.noiseLevel,
    strings.noiseLevel(draft.noiseLevel),
    'atmosphere.noise',
  );
  for (final cue in draft.cues) {
    chips.add(ContextChipData(
      dimension: ContextDimension.cues,
      label: strings.cue(cue),
      branchId: 'cue',
      origin: draft.originOf(ContextDimension.cues),
    ));
  }
  for (final tone in draft.preferredTones) {
    chips.add(ContextChipData(
      dimension: ContextDimension.tones,
      label: strings.tone(tone),
      branchId: 'tone.register',
      origin: draft.originOf(ContextDimension.tones),
    ));
  }
  for (final caution in draft.cautions) {
    chips.add(ContextChipData(
      dimension: ContextDimension.caution,
      label: strings.t('avoid.${caution.name}'),
      branchId: 'caution',
      origin: draft.originOf(ContextDimension.caution),
    ));
  }
  if (draft.eyeContact) {
    add(
      ContextDimension.eyeContact,
      strings.t('context.eyeContact'),
      'people.interaction',
    );
  }
  if (draft.conversationStarted) {
    add(
      ContextDimension.conversationStarted,
      strings.t('context.conversationStarted'),
      'people.interaction',
    );
  }
  return chips;
}

/// A horizontal, individually tappable row of context chips.
class ContextChipRow extends StatelessWidget {
  const ContextChipRow({
    super.key,
    required this.draft,
    this.onChipTap,
    this.onChipClear,
  });

  final ContextDraft draft;

  /// Called with the branch id the radial menu should open at.
  final ValueChanged<String>? onChipTap;

  final ValueChanged<ContextDimension>? onChipClear;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final chips = contextChipsFor(draft, strings);

    if (chips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          strings.t('context.chipsEmpty'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          for (final chip in chips) ...<Widget>[
            _chip(context, chip, strings, theme),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    ContextChipData chip,
    AppLocalizations strings,
    ThemeData theme,
  ) {
    // Provenance is shown with a glyph, never colour alone: a spark for a
    // value a scan suggested and the user has not corrected, a pencil for a
    // correction, a dot for a value that came from saved defaults.
    final (IconData? icon, String? semanticSuffix) = switch (chip.origin) {
      DraftOrigin.fromScan => (
          Icons.auto_awesome,
          strings.t('radial.fromScan'),
        ),
      DraftOrigin.fromUser => (Icons.edit_outlined, null),
      DraftOrigin.fromDefaults => (
          Icons.circle,
          strings.t('radial.defaultValue'),
        ),
      DraftOrigin.fromPreset => (Icons.bookmark_outline, null),
      DraftOrigin.unset => (null, null),
    };

    return Semantics(
      button: onChipTap != null,
      label: semanticSuffix == null
          ? chip.label
          : '${chip.label}, $semanticSuffix',
      child: InputChip(
        avatar: icon == null
            ? null
            : Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        label: Text(chip.label),
        tooltip: strings.t('context.tapChipToEdit'),
        onPressed:
            onChipTap == null ? null : () => onChipTap!(chip.branchId),
        onDeleted: onChipClear == null
            ? null
            : () => onChipClear!(chip.dimension),
      ),
    );
  }
}

/// The complete linear equivalent of the radial menu.
///
/// Required, not optional: a radial menu cannot be the only way to operate the
/// app. This walks the **same tree** the radial menu walks, so an option
/// reachable in one is reachable in the other by construction — there is no
/// second list to keep in step.
class ContextListFallback extends StatefulWidget {
  const ContextListFallback({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onApply,
    this.initialBranchId,
  });

  final ContextDraft draft;
  final ValueChanged<ContextDraft> onChanged;
  final ValueChanged<ContextDraft> onApply;

  /// Opens the list already scrolled into a branch, matching the chip tap
  /// behaviour of the radial menu.
  final String? initialBranchId;

  /// Shows the fallback as a modal sheet and returns the applied draft, or
  /// null when the user cancelled.
  static Future<ContextDraft?> show(
    BuildContext context, {
    required ContextDraft draft,
    String? initialBranchId,
  }) {
    return showModalBottomSheet<ContextDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var working = draft;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, scrollController) => ContextListFallback(
            draft: working,
            initialBranchId: initialBranchId,
            onChanged: (next) => working = next,
            onApply: (next) => Navigator.of(sheetContext).pop(next),
          ),
        );
      },
    );
  }

  @override
  State<ContextListFallback> createState() => _ContextListFallbackState();
}

class _ContextListFallbackState extends State<ContextListFallback> {
  late ContextDraft _draft = widget.draft;
  late final RadialMenuNode _tree = buildRadialMenuTree();
  late List<RadialMenuNode> _path;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBranchId;
    final resolved = initial == null ? null : _tree.pathTo(initial);
    _path = resolved == null
        ? <RadialMenuNode>[_tree]
        : resolved.where((n) => n.isBranch).toList();
    if (_path.isEmpty) _path = <RadialMenuNode>[_tree];
  }

  RadialMenuNode get _branch => _path.last;

  void _update(ContextDraft next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: <Widget>[
              if (_path.length > 1)
                IconButton(
                  tooltip: strings.t('radial.back'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _path.removeLast()),
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _path.length > 1
                      ? _path.skip(1).map((n) => strings.t(n.labelKey))
                          .join(' › ')
                      : strings.t('radial.root'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => widget.onApply(_draft),
                child: Text(strings.t('radial.done')),
              ),
            ],
          ),
        ),
        ContextChipRow(
          draft: _draft,
          onChipClear: (dimension) =>
              _update(_draft.clearDimension(dimension)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _branch.children.length,
            itemBuilder: (_, index) {
              final node = _branch.children[index];
              return _tile(node, strings);
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(RadialMenuNode node, AppLocalizations strings) {
    final label = strings.t(node.labelKey);
    if (node.isBranch) {
      return ListTile(
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _path.add(node)),
      );
    }
    final action = node.action!;
    if (action is RunCommand) {
      // Commands are effects; the list offers only the ones that make sense
      // without a gesture surface.
      if (action.command != RadialCommand.clearAll &&
          action.command != RadialCommand.clearDimension) {
        return const SizedBox.shrink();
      }
      return ListTile(
        title: Text(label),
        leading: const Icon(Icons.backspace_outlined),
        onTap: () => _update(
          action.command == RadialCommand.clearAll
              ? ContextDraft.empty(
                  defaultTones: _draft.preferredTones,
                  defaultDirectness: _draft.directness,
                )
              : _draft.clearDimension(ContextDimension.caution),
        ),
      );
    }
    final selected = _draft.isSelected(action);
    return CheckboxListTile(
      // Checkbox rather than a highlight, so selection is never conveyed by
      // colour alone and a screen reader announces the state.
      value: selected,
      title: Text(label),
      controlAffinity: ListTileControlAffinity.trailing,
      onChanged: (_) => _update(_draft.apply(action)),
    );
  }
}
