import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models/opener_line.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';
import 'line_editor_screen.dart';

/// Everything recorded about one line, plus edit, duplicate and delete.
///
/// Reads the line from state by id rather than taking a snapshot, so an edit
/// made here is reflected the moment it is saved.
class LineDetailScreen extends StatelessWidget {
  const LineDetailScreen({required this.lineId, super.key});

  final String lineId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final line = state.lineById(lineId);

    if (line == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.help_outline,
          title: strings.t('history.lineDeleted'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.category(line.category)),
        actions: <Widget>[
          IconButton(
            tooltip: line.isFavorite
                ? strings.t('action.unfavorite')
                : strings.t('action.favorite'),
            onPressed: () => state.toggleFavorite(line),
            icon: Icon(line.isFavorite ? Icons.star : Icons.star_outline),
          ),
          IconButton(
            tooltip: strings.t('action.duplicate'),
            onPressed: () => _duplicate(context, line),
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: strings.t('action.edit'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LineEditorScreen(existing: line),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: strings.t('action.delete'),
            onPressed: () => _delete(context, line),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: LineText(
                      line: line,
                      japaneseStyle: AppTheme.japaneseDisplay(context),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('rec.conditions'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ConditionList(
                        title: strings.t('rec.conditions'),
                        items: useConditionLabels(strings, line),
                        icon: Icons.check_circle_outline,
                      ),
                      if (line.conditions.isNotEmpty)
                        const SizedBox(height: 12),
                      ConditionList(
                        title: strings.t('rec.avoidConditions'),
                        items: avoidConditionLabels(strings, line),
                        icon: Icons.do_not_disturb_on_outlined,
                        isWarning: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('library.filters'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _TagRow(
                        label: strings.t('editor.locations'),
                        values: line.locations.map(strings.location).toList(),
                        emptyLabel: strings.t('category.universal'),
                      ),
                      _TagRow(
                        label: strings.t('editor.cues'),
                        values:
                            line.observableCues.map(strings.cue).toList(),
                      ),
                      _TagRow(
                        label: strings.t('editor.groupSizes'),
                        values: line.groupSizes.map(strings.groupSize).toList(),
                      ),
                      _TagRow(
                        label: strings.t('editor.noiseLevels'),
                        values:
                            line.noiseLevels.map(strings.noiseLevel).toList(),
                      ),
                      _TagRow(
                        label: strings.t('editor.activities'),
                        values: line.activities.map(strings.activity).toList(),
                      ),
                      _TagRow(
                        label: strings.t('editor.tones'),
                        values: line.tones.map(strings.tone).toList(),
                      ),
                      _TagRow(
                        label: strings.t('editor.directness'),
                        values: <String>[
                          '${line.directness} · '
                              '${strings.directnessLabel(line.directness)}',
                        ],
                      ),
                    ],
                  ),
                ),

                if (line.followUpSuggestion != null ||
                    line.notes != null) ...<Widget>[
                  const SizedBox(height: AppTheme.gap),
                  SectionCard(
                    title: strings.t('rec.notes'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (line.notes != null)
                          Text(line.notes!),
                        if (line.notes != null &&
                            line.followUpSuggestion != null)
                          const SizedBox(height: 12),
                        if (line.followUpSuggestion != null) ...<Widget>[
                          Text(
                            strings.t('rec.followUp'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(line.followUpSuggestion!),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.gap),
                _HistoryCard(line: line),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicate(BuildContext context, OpenerLine line) async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final copy = await state.duplicateLine(line);
    if (!context.mounted) return;
    showBriefMessage(context, strings.t('library.duplicated'));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LineEditorScreen(existing: copy),
      ),
    );
  }

  Future<void> _delete(BuildContext context, OpenerLine line) async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final confirmed = await confirmAction(
      context,
      title: strings.t('library.deleteTitle'),
      body: strings.t('library.deleteBody'),
      extraNote:
          line.isUserCreated ? null : strings.t('library.deleteSeedNote'),
      confirmLabel: strings.t('action.delete'),
    );
    if (!confirmed) return;
    await state.deleteLine(line.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.label,
    required this.values,
    this.emptyLabel,
  });

  final String label;
  final List<String> values;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty && emptyLabel == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final shown = values.isEmpty ? <String>[emptyLabel!] : values;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[for (final value in shown) MetaTag(value)],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.line});

  final OpenerLine line;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    return SectionCard(
      title: strings.t('history.title'),
      child: line.timesUsed == 0 && line.timesShown == 0
          ? Text(
              strings.t('library.neverUsed'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                MetaTag(
                  strings.f(
                    'library.shownCount',
                    <Object?>[line.timesShown],
                  ),
                ),
                MetaTag(
                  strings.f('library.usedCount', <Object?>[line.timesUsed]),
                ),
                if (line.positiveResults > 0)
                  MetaTag('${strings.t('outcome.positive')} '
                      '${line.positiveResults}'),
                if (line.neutralResults > 0)
                  MetaTag('${strings.t('outcome.neutral')} '
                      '${line.neutralResults}'),
                if (line.negativeResults > 0)
                  MetaTag('${strings.t('outcome.unreceptive')} '
                      '${line.negativeResults}'),
              ],
            ),
    );
  }
}
