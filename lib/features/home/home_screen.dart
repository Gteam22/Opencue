import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../../domain/models/interaction_record.dart';
import '../context_builder/context_builder_screen.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// The landing screen.
///
/// One large primary action, two shortcuts, a short recent list, and an
/// honest placeholder for the scan feature that this version does not have.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onOpenLibrary,
    required this.onOpenFavorites,
    required this.onOpenHistory,
    super.key,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);

    return ListView(
      children: <Widget>[
        ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const OpenCueMark(size: 34),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppInfo.appName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        strings.t('app.tagline'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Primary action.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ContextBuilderScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.explore_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: <Widget>[
                        Text(
                          strings.t('home.findLine'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.t('home.findLineSubtitle'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              // Secondary shortcuts.
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenLibrary,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(strings.t('home.browseLibrary')),
                    ),
                  ),
                  const SizedBox(width: AppTheme.gap),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenFavorites,
                      icon: const Icon(Icons.star_outline),
                      label: Text(strings.t('home.favorites')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.f('home.libraryCount', <Object?>[state.lineCount]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              _RecentSection(onOpenHistory: onOpenHistory),
              const SizedBox(height: 24),
              const _ScanPlaceholder(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.onOpenHistory});

  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);
    final recent = state.history.take(4).toList();

    return SectionCard(
      title: strings.t('home.recent'),
      trailing: recent.isEmpty
          ? null
          : TextButton(
              onPressed: onOpenHistory,
              child: Text(strings.t('nav.history')),
            ),
      child: recent.isEmpty
          ? Text(
              strings.t('home.recentEmpty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: <Widget>[
                for (final record in recent) _RecentRow(record: record),
              ],
            ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record});

  final InteractionRecord record;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);
    final line = state.lineById(record.openerLineId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: line == null
                ? Text(
                    strings.t('history.lineDeleted'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : LineText(line: line, showEnglish: false),
          ),
          const SizedBox(width: 12),
          MetaTag(strings.outcome(record.outcome)),
        ],
      ),
    );
  }
}

/// The scan placeholder.
///
/// Visible and explained, but not interactive, and no permission is requested
/// anywhere in this build. Showing it as a live-looking button would imply the
/// app already has camera access, which it does not.
class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder();

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    return Opacity(
      opacity: 0.75,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.center_focus_weak_outlined,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Wrap, not Row: "Planned for a later version" is a long
                    // label, and in a narrow window (or a longer translation)
                    // the two together overflow a fixed Row. Wrap drops the
                    // badge onto a second line instead of clipping it.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          strings.t('home.scan'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        MetaTag(strings.t('home.scanPlanned')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.t('home.scanExplain'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
