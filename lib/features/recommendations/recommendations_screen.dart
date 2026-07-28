import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/context_snapshot.dart';
import '../../domain/models/opener_line.dart';
import '../../domain/recommendation/recommendation_models.dart';
import '../../l10n/app_localizations.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// Shows up to three ranked suggestions, or the advisory instead.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({
    required this.situation,
    this.preferences = const RecommendationPreferences(),
    super.key,
  });

  final ContextSnapshot situation;
  final RecommendationPreferences preferences;

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  RecommendationResult? _result;
  bool _showDebug = false;

  /// Ids swapped out by "Show another", so the replacements persist while the
  /// screen is open.
  final Set<String> _dismissed = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_result == null) {
      // Assigned directly rather than through setState: this runs before the
      // first build, so there is nothing to schedule yet.
      _result = _score();
      final shown = _result!.primary.map((s) => s.line.id).toList();
      if (shown.isNotEmpty) {
        // Fire and forget. The counters feed the user's own statistics, and a
        // storage hiccup must not stop the suggestions from appearing.
        AppScope.read(context).noteSuggested(shown);
      }
    }
  }

  RecommendationResult _score() {
    final state = AppScope.read(context);
    return state.engine.recommend(
      context: widget.situation,
      library: state.lines,
      preferences: widget.preferences,
      recentlyShownIds: state.recentlyShownIds.union(_dismissed),
    );
  }

  void _rescore() => setState(() => _result = _score());

  /// Replaces one card with the next-best candidate.
  void _showAnother(ScoredLine current) {
    _dismissed.add(current.line.id);
    _rescore();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('rec.title')),
        actions: <Widget>[
          IconButton(
            tooltip: strings.t('rec.debugToggle'),
            onPressed: () => setState(() => _showDebug = !_showDebug),
            icon: Icon(
              _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
            ),
          ),
        ],
      ),
      body: result == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: <Widget>[
                ContentColumn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (result.advisory.discouraged)
                        AdvisoryBanner(
                          reasons: result.advisory.reasons,
                          onChangeSituation: () => Navigator.of(context).pop(),
                        )
                      else
                        ..._suggestions(result, strings),
                      const SizedBox(height: 24),
                      _ExitLines(result: result),
                      if (_showDebug) ...<Widget>[
                        const SizedBox(height: 24),
                        _DebugPanel(result: result),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _suggestions(
    RecommendationResult result,
    AppLocalizations strings,
  ) {
    if (result.primary.isEmpty) {
      return <Widget>[
        EmptyState(
          icon: Icons.search_off,
          title: strings.t('rec.noResults'),
          hint: strings.t('rec.noResultsHint'),
          action: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.t('advisory.changeSituation')),
          ),
        ),
      ];
    }
    return <Widget>[
      for (final scored in result.primary) ...<Widget>[
        RecommendationCard(
          scored: scored,
          situation: widget.situation,
          canShowAnother: result.alternates.isNotEmpty,
          onShowAnother: () => _showAnother(scored),
        ),
        const SizedBox(height: AppTheme.gap),
      ],
      const SizedBox(height: 4),
      Text(
        strings.t('rec.noGuarantee'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ];
  }
}

/// One large suggestion card.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    required this.scored,
    required this.situation,
    this.canShowAnother = false,
    this.onShowAnother,
    super.key,
  });

  final ScoredLine scored;
  final ContextSnapshot situation;
  final bool canShowAnother;
  final VoidCallback? onShowAnother;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);
    // Read the live copy so a favourite toggle updates immediately.
    final line = state.lineById(scored.line.id) ?? scored.line;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                MetaTag(
                  strings.t('rec.category.${scored.category.name}'),
                  emphasised: true,
                ),
                const SizedBox(width: 8),
                MetaTag(strings.directnessLabel(line.directness)),
                const Spacer(),
                IconButton(
                  tooltip: line.isFavorite
                      ? strings.t('action.unfavorite')
                      : strings.t('action.favorite'),
                  onPressed: () => state.toggleFavorite(line),
                  icon: Icon(
                    line.isFavorite ? Icons.star : Icons.star_outline,
                    color: line.isFavorite ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LineText(
              line: line,
              japaneseStyle: AppTheme.japaneseDisplay(context),
            ),
            const SizedBox(height: 16),

            if (scored.matchingReasons.isNotEmpty) ...<Widget>[
              Text(
                strings.t('rec.matchingReasons'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final factor in scored.matchingReasons.take(4))
                    MetaTag(strings.scoreFactor(factor.code.name)),
                ],
              ),
              const SizedBox(height: 14),
            ],

            ConditionList(
              title: strings.t('rec.conditions'),
              items: useConditionLabels(strings, line),
              icon: Icons.check_circle_outline,
            ),
            if (line.conditions.isNotEmpty) const SizedBox(height: 10),
            ConditionList(
              title: strings.t('rec.avoidConditions'),
              items: avoidConditionLabels(strings, line),
              icon: Icons.do_not_disturb_on_outlined,
              isWarning: true,
            ),

            if (line.notes != null) ...<Widget>[
              const SizedBox(height: 12),
              _Aside(label: strings.t('rec.notes'), body: line.notes!),
            ],
            if (line.followUpSuggestion != null) ...<Widget>[
              const SizedBox(height: 10),
              _Aside(
                label: strings.t('rec.followUp'),
                body: line.followUpSuggestion!,
              ),
            ],

            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _recordOutcome(context, line),
                  icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                  label: Text(strings.t('action.usedThisLine')),
                ),
                if (canShowAnother && onShowAnother != null)
                  OutlinedButton.icon(
                    onPressed: onShowAnother,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(strings.t('action.showAnother')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordOutcome(BuildContext context, OpenerLine line) async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final outcome = await showOutcomeSheet(context, line);
    if (outcome == null) return;
    await state.recordOutcome(
      line: line,
      outcome: outcome.outcome,
      context: situation,
      notes: outcome.note,
    );
    if (!context.mounted) return;
    showBriefMessage(context, strings.t('outcome.saved'));
  }
}

/// A small labelled paragraph used for notes and follow-ups.
class _Aside extends StatelessWidget {
  const _Aside({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// The graceful exits, always shown, including under the advisory.
class _ExitLines extends StatelessWidget {
  const _ExitLines({required this.result});

  final RecommendationResult result;

  @override
  Widget build(BuildContext context) {
    if (result.exitLines.isEmpty) return const SizedBox.shrink();
    final strings = AppScope.strings(context);
    return SectionCard(
      title: strings.t('rec.exitLines'),
      subtitle: strings.t('rec.exitLinesHint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final scored in result.exitLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LineText(line: scored.line),
            ),
        ],
      ),
    );
  }
}

/// The score breakdown, for understanding why a line ranked where it did.
class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.result});

  final RecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    return SectionCard(
      title: strings.t('rec.debugTitle'),
      subtitle: strings.f(
        'rec.consideredCount',
        <Object?>[result.consideredCount, result.excludedCount],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final scored in <ScoredLine>[
            ...result.primary,
            ...result.alternates,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${scored.score}  ${scored.line.japaneseText}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scored.factors
                        .map((f) =>
                            '${strings.scoreFactor(f.code.name)} '
                            '(${f.delta >= 0 ? '+' : ''}${f.delta})')
                        .join('  ·  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

/// What the outcome sheet returns.
class OutcomeEntry {
  const OutcomeEntry(this.outcome, this.note);

  final InteractionOutcome outcome;
  final String? note;
}

/// Asks how the interaction went. Returns null if dismissed.
Future<OutcomeEntry?> showOutcomeSheet(
  BuildContext context,
  OpenerLine line,
) {
  return showModalBottomSheet<OutcomeEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OutcomeSheet(line: line),
  );
}

class _OutcomeSheet extends StatefulWidget {
  const _OutcomeSheet({required this.line});

  final OpenerLine line;

  @override
  State<_OutcomeSheet> createState() => _OutcomeSheetState();
}

class _OutcomeSheetState extends State<_OutcomeSheet> {
  InteractionOutcome _selected = InteractionOutcome.notRecorded;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.t('outcome.title'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            strings.t('outcome.subtitle'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LineText(line: widget.line),
          const SizedBox(height: 20),
          SingleSelectChips<InteractionOutcome>(
            values: InteractionOutcome.values,
            selected: _selected,
            labelFor: strings.outcome,
            onChanged: (value) => setState(() => _selected = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: strings.t('outcome.note'),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.t('action.cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final note = _note.text.trim();
                  Navigator.of(context).pop(
                    OutcomeEntry(_selected, note.isEmpty ? null : note),
                  );
                },
                child: Text(strings.t('action.save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
