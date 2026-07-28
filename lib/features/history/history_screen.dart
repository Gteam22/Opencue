import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/statistics_service.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/interaction_record.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// The log of recorded interactions, plus restrained aggregate numbers.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final stats = state.computeStatistics();

    if (state.history.isEmpty && stats.isEmpty) {
      return EmptyState(
        icon: Icons.insights_outlined,
        title: strings.t('history.empty'),
        hint: strings.t('history.emptyHint'),
      );
    }

    return ListView(
      children: <Widget>[
        ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Totals(stats: stats),
              const SizedBox(height: AppTheme.gap),
              _Outcomes(stats: stats),
              const SizedBox(height: AppTheme.gap),
              _Tallies(stats: stats),
              if (stats.bestLines.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppTheme.gap),
                _BestLines(stats: stats),
              ],
              const SizedBox(height: AppTheme.gap),
              _Log(records: state.history),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.stats});

  final LibraryStatistics stats;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return SectionCard(
      title: strings.t('history.statistics'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Figure(
              value: '${stats.totalSuggestionsViewed}',
              label: strings.t('history.suggestionsViewed'),
            ),
          ),
          Expanded(
            child: _Figure(
              value: '${stats.totalLinesUsed}',
              label: strings.t('history.linesUsed'),
            ),
          ),
          Expanded(
            child: _Figure(
              value: '${stats.recordedOutcomeCount}',
              label: strings.t('history.recorded'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Outcomes extends StatelessWidget {
  const _Outcomes({required this.stats});

  final LibraryStatistics stats;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final total = stats.recordedOutcomeCount;

    return SectionCard(
      title: strings.t('history.outcomes'),
      subtitle: stats.hasEnoughForRates
          ? null
          : strings.t('history.notEnoughData'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final outcome in InteractionOutcome.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 160,
                    child: Text(
                      strings.outcome(outcome),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: _Bar(
                      // The bar is scaled against the largest bucket so it is
                      // readable, and never presented as a percentage unless
                      // the sample supports one.
                      fraction: total == 0
                          ? 0
                          : (stats.outcomeCounts[outcome] ?? 0) / total,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _label(outcome, stats),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _label(InteractionOutcome outcome, LibraryStatistics stats) {
    final count = stats.outcomeCounts[outcome] ?? 0;
    final rate = stats.rateFor(outcome);
    if (rate == null) return '$count';
    return '$count  ·  ${(rate * 100).round()}%';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _Tallies extends StatelessWidget {
  const _Tallies({required this.stats});

  final LibraryStatistics stats;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    if (stats.topLocations.isEmpty && stats.topTones.isEmpty) {
      return SectionCard(
        title: strings.t('history.patterns'),
        child: Text(
          strings.t('history.patternsEmpty'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SectionCard(
      title: strings.t('history.patterns'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (stats.topLocations.isNotEmpty) ...<Widget>[
            Text(
              strings.t('history.topLocations'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final entry in stats.topLocations)
                  MetaTag('${strings.location(entry.key)} · ${entry.count}'),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (stats.topTones.isNotEmpty) ...<Widget>[
            Text(
              strings.t('history.topTones'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final entry in stats.topTones)
                  MetaTag('${strings.tone(entry.key)} · ${entry.count}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BestLines extends StatelessWidget {
  const _BestLines({required this.stats});

  final LibraryStatistics stats;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return SectionCard(
      title: strings.t('history.bestLines'),
      subtitle: strings.t('history.bestLinesNote'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final line in stats.bestLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: LineText(line: line)),
                  const SizedBox(width: 12),
                  MetaTag(
                    strings.f(
                      'library.usedCount',
                      <Object?>[line.timesUsed],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Log extends StatelessWidget {
  const _Log({required this.records});

  final List<InteractionRecord> records;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);

    return SectionCard(
      title: strings.t('history.log'),
      child: records.isEmpty
          ? Text(
              strings.t('history.empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final record in records) ...<Widget>[
                  _LogRow(record: record),
                  if (record != records.last) const Divider(height: 20),
                ],
              ],
            ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record});

  final InteractionRecord record;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);
    final line = state.lineById(record.openerLineId);
    final snapshot = record.contextSnapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: line == null
                  ? Text(
                      strings.t('history.lineDeleted'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : LineText(line: line),
            ),
            const SizedBox(width: 12),
            MetaTag(strings.outcome(record.outcome), emphasised: true),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            MetaTag(_formatDate(record.dateUsed)),
            if (snapshot?.location != null)
              MetaTag(strings.location(snapshot!.location!)),
            if (snapshot?.groupSize != null)
              MetaTag(strings.groupSize(snapshot!.groupSize!)),
            if (snapshot != null && snapshot.source != ContextSource.manual)
              MetaTag(strings.contextSource(snapshot.source)),
          ],
        ),
        if (record.optionalNotes != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            record.optionalNotes!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Local date, no time-of-day. The exact minute is not useful here and the
  /// coarser value is less revealing if an export is ever shared.
  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
