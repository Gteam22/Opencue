import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/opener_line.dart';
import '../../domain/repositories/library_query.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';
import 'line_detail_screen.dart';
import 'line_editor_screen.dart';

/// Browse, search, filter and manage the whole library.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({this.initialFavoritesOnly = false, super.key});

  /// Opens with the favourites filter already applied, for the home shortcut.
  final bool initialFavoritesOnly;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late LibraryQuery _query;
  final TextEditingController _search = TextEditingController();
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _query = LibraryQuery(favoritesOnly: widget.initialFavoritesOnly);
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFavoritesOnly != widget.initialFavoritesOnly) {
      _apply(_query.copyWith(favoritesOnly: widget.initialFavoritesOnly));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply(LibraryQuery next) => setState(() => _query = next);

  @override
  Widget build(BuildContext context) {
    // Subscribe so the list refreshes after a save or delete anywhere.
    final state = AppScope.of(context);
    // Filtered from the in-memory library rather than re-queried from SQLite.
    // AppState already holds every line, the library is only a few hundred
    // rows, and doing it here keeps the list synchronous — a database round
    // trip per keystroke made search feel laggy and left the list empty on
    // the first frame.
    final results = _query.applyTo(state.lines);
    final strings = AppScope.strings(context);

    return Column(
      children: <Widget>[
        _SearchBar(
          controller: _search,
          query: _query,
          filtersOpen: _filtersOpen,
          onSearchChanged: (value) =>
              _apply(_query.copyWith(searchText: value)),
          onToggleFilters: () =>
              setState(() => _filtersOpen = !_filtersOpen),
          onSortChanged: (sort) => _apply(_query.copyWith(sort: sort)),
          onAddLine: () => _openEditor(null),
        ),
        if (_filtersOpen)
          _FilterPanel(
            query: _query,
            onChanged: _apply,
            onClear: () => _apply(
              LibraryQuery(sort: _query.sort),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? _emptyState(strings.t('library.empty'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) => LibraryRow(
                    line: results[index],
                    onOpen: () => _openDetail(results[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyState(String title) {
    final state = AppScope.of(context);
    final strings = state.strings;
    if (state.lineCount == 0) {
      return EmptyState(
        icon: Icons.library_books_outlined,
        title: strings.t('library.emptyLibrary'),
        hint: strings.t('library.emptyLibraryHint'),
        action: FilledButton.icon(
          onPressed: () => _openEditor(null),
          icon: const Icon(Icons.add),
          label: Text(strings.t('action.addLine')),
        ),
      );
    }
    return EmptyState(
      icon: Icons.search_off,
      title: title,
      hint: strings.t('library.emptyHint'),
      action: _query.isEmpty
          ? null
          : OutlinedButton(
              onPressed: () {
                _search.clear();
                _apply(LibraryQuery(sort: _query.sort));
              },
              child: Text(strings.t('library.clearFilters')),
            ),
    );
  }

  Future<void> _openDetail(OpenerLine line) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LineDetailScreen(lineId: line.id),
      ),
    );
    // No explicit refresh: AppState notifies after every write, which rebuilds
    // this screen and re-filters from the in-memory library.
  }

  Future<void> _openEditor(OpenerLine? line) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LineEditorScreen(existing: line),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.filtersOpen,
    required this.onSearchChanged,
    required this.onToggleFilters,
    required this.onSortChanged,
    required this.onAddLine,
  });

  final TextEditingController controller;
  final LibraryQuery query;
  final bool filtersOpen;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleFilters;
  final ValueChanged<LibrarySort> onSortChanged;
  final VoidCallback onAddLine;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final activeCount = query.activeFilterCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: strings.t('library.search'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.t('action.clear'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: activeCount > 0,
            label: Text('$activeCount'),
            child: IconButton(
              tooltip: strings.t('library.filters'),
              isSelected: filtersOpen,
              onPressed: onToggleFilters,
              icon: const Icon(Icons.filter_list),
              selectedIcon: const Icon(Icons.filter_list_off),
            ),
          ),
          PopupMenuButton<LibrarySort>(
            tooltip: strings.t('library.sortBy'),
            icon: const Icon(Icons.sort),
            initialValue: query.sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => <PopupMenuEntry<LibrarySort>>[
              for (final sort in LibrarySort.values)
                PopupMenuItem<LibrarySort>(
                  value: sort,
                  child: Text(strings.sort(sort)),
                ),
            ],
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onAddLine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(strings.t('action.addLine')),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final LibraryQuery query;
  final ValueChanged<LibraryQuery> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return Container(
      // Raised from 320 when the activity, group-size and noise groups were
      // added; the panel scrolls, but three more groups made it feel truncated.
      constraints: const BoxConstraints(maxHeight: 420),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.35),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      FilterChip(
                        label: Text(strings.t('library.favoritesOnly')),
                        selected: query.favoritesOnly,
                        onSelected: (value) => onChanged(
                          query.copyWith(favoritesOnly: value),
                        ),
                      ),
                      FilterChip(
                        label: Text(strings.t('library.userCreatedOnly')),
                        selected: query.userCreatedOnly,
                        onSelected: (value) => onChanged(
                          query.copyWith(userCreatedOnly: value),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: Text(strings.t('library.clearFilters')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _FilterGroup(
              label: strings.t('editor.category'),
              child: MultiSelectChips<LineCategory>(
                values: LineCategory.values,
                selected: query.categories,
                labelFor: strings.category,
                onChanged: (value) =>
                    onChanged(query.copyWith(categories: value)),
              ),
            ),
            _FilterGroup(
              label: strings.t('editor.locations'),
              child: MultiSelectChips<LocationTag>(
                values: LocationTag.values,
                selected: query.locations,
                labelFor: strings.location,
                onChanged: (value) =>
                    onChanged(query.copyWith(locations: value)),
              ),
            ),
            _FilterGroup(
              label: strings.t('editor.activities'),
              child: MultiSelectChips<ActivityTag>(
                values: ActivityTag.values,
                selected: query.activities,
                labelFor: strings.activity,
                onChanged: (value) =>
                    onChanged(query.copyWith(activities: value)),
              ),
            ),
            _FilterGroup(
              label: strings.t('editor.groupSizes'),
              child: MultiSelectChips<GroupSize>(
                values: GroupSize.values,
                selected: query.groupSizes,
                labelFor: strings.groupSize,
                onChanged: (value) =>
                    onChanged(query.copyWith(groupSizes: value)),
              ),
            ),
            _FilterGroup(
              label: strings.t('editor.noiseLevels'),
              child: MultiSelectChips<NoiseLevel>(
                values: NoiseLevel.values,
                selected: query.noiseLevels,
                labelFor: strings.noiseLevel,
                onChanged: (value) =>
                    onChanged(query.copyWith(noiseLevels: value)),
              ),
            ),
            _FilterGroup(
              label: strings.t('editor.cues'),
              child: MultiSelectChips<ObservableCue>(
                values: ObservableCue.values,
                selected: query.cues,
                labelFor: strings.cue,
                onChanged: (value) => onChanged(query.copyWith(cues: value)),
              ),
            ),
            _FilterGroup(
              label: strings.t('editor.tones'),
              child: MultiSelectChips<Tone>(
                values: Tone.values,
                selected: query.tones,
                labelFor: strings.tone,
                onChanged: (value) => onChanged(query.copyWith(tones: value)),
              ),
            ),
            _FilterGroup(
              label: strings.f(
                'library.directnessRange',
                <Object?>[query.minDirectness, query.maxDirectness],
              ),
              child: RangeSlider(
                values: RangeValues(
                  query.minDirectness.toDouble(),
                  query.maxDirectness.toDouble(),
                ),
                min: kMinDirectness.toDouble(),
                max: kMaxDirectness.toDouble(),
                divisions: kMaxDirectness - kMinDirectness,
                labels: RangeLabels(
                  '${query.minDirectness}',
                  '${query.maxDirectness}',
                ),
                onChanged: (values) => onChanged(
                  query.copyWith(
                    minDirectness: values.start.round(),
                    maxDirectness: values.end.round(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child,
        ],
      ),
    );
  }
}

/// One row in the library list.
class LibraryRow extends StatelessWidget {
  const LibraryRow({required this.line, required this.onOpen, super.key});

  final OpenerLine line;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Not selectable: the whole row is tappable, and
                  // SelectableText would swallow the tap.
                  LineText(line: line, selectable: false),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      MetaTag(strings.category(line.category)),
                      for (final tone in line.tones.take(2))
                        MetaTag(strings.tone(tone)),
                      MetaTag('${strings.t('editor.directness')} '
                          '${line.directness}'),
                      if (line.timesUsed > 0)
                        MetaTag(
                          strings.f(
                            'library.usedCount',
                            <Object?>[line.timesUsed],
                          ),
                          icon: Icons.history,
                        ),
                      if (line.isUserCreated)
                        MetaTag(
                          strings.t('library.userLine'),
                          icon: Icons.edit_note,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.gap),
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
      ),
    );
  }
}
