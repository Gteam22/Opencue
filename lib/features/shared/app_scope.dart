import 'package:flutter/widgets.dart';

import '../../data/library_service.dart';
import '../../data/statistics_service.dart';
import '../../data/transfer/transfer_service.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/context_snapshot.dart';
import '../../domain/models/interaction_record.dart';
import '../../domain/models/opener_line.dart';
import '../../domain/recommendation/recommendation_engine.dart';
import '../../l10n/app_localizations.dart';

/// Holds everything the screens read and every action they can take.
///
/// The whole library is a few hundred rows, so it is cached in memory and the
/// recommendation engine is handed a plain list. That keeps the engine free of
/// storage concerns and makes the UI synchronous to read.
class AppState extends ChangeNotifier {
  AppState({
    required this.service,
    this.engine = const RecommendationEngine(),
    this.statistics = const StatisticsService(),
    TransferService? transfer,
  }) : transfer = transfer ?? TransferService();

  final LibraryService service;
  final RecommendationEngine engine;
  final StatisticsService statistics;
  final TransferService transfer;

  AppSettings _settings = AppSettings.defaults;
  List<OpenerLine> _lines = const <OpenerLine>[];
  List<InteractionRecord> _history = const <InteractionRecord>[];
  bool _isLoading = true;
  String? _loadError;

  /// Ids offered in recent recommendation rounds, so the engine can rotate.
  /// Session-only; there is no reason to persist it.
  final List<String> _recentlyShown = <String>[];

  static const int _recentlyShownMemory = 12;

  AppSettings get settings => _settings;

  List<OpenerLine> get lines => _lines;

  List<InteractionRecord> get history => _history;

  bool get isLoading => _isLoading;

  String? get loadError => _loadError;

  Set<String> get recentlyShownIds => _recentlyShown.toSet();

  AppLocalizations get strings => AppLocalizations(_settings.languageMode);

  List<OpenerLine> get favorites =>
      _lines.where((l) => l.isFavorite).toList();

  List<OpenerLine> get exitLines =>
      _lines.where((l) => l.isExitLine).toList();

  int get lineCount => _lines.length;

  /// Loads settings, seeds the starter library on a first run, and reads
  /// everything into memory.
  Future<void> bootstrap() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      await service.seedIfEmpty();
      _settings = await service.settings.load();
      await _refreshFromStorage();
    } on Object catch (error) {
      _loadError = '$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshFromStorage() async {
    _lines = await service.lines.getAll();
    _history = await service.interactions.getAll(limit: 300);
  }

  /// Re-reads storage and notifies. Called after every write.
  Future<void> reload() async {
    await _refreshFromStorage();
    notifyListeners();
  }

  OpenerLine? lineById(String id) {
    for (final line in _lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  // -----------------------------------------------------------------
  // Settings
  // -----------------------------------------------------------------

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await service.settings.save(next);
  }

  Future<void> setLanguage(LanguageMode mode) =>
      updateSettings(_settings.copyWith(languageMode: mode));

  Future<void> setTheme(AppThemePreference preference) =>
      updateSettings(_settings.copyWith(themePreference: preference));

  // -----------------------------------------------------------------
  // Lines
  // -----------------------------------------------------------------

  Future<void> toggleFavorite(OpenerLine line) async {
    await service.lines.setFavorite(line.id, isFavorite: !line.isFavorite);
    await reload();
  }

  Future<void> saveLine(OpenerLine line, {required bool isNew}) async {
    if (isNew) {
      await service.lines.insert(line);
    } else {
      await service.lines.update(line);
    }
    await reload();
  }

  Future<void> deleteLine(String id) async {
    await service.lines.delete(id);
    await reload();
  }

  Future<OpenerLine> duplicateLine(OpenerLine line) async {
    final copy = await service.duplicate(line);
    await reload();
    return copy;
  }

  Future<int> restoreStarterLibrary() async {
    final count = await service.restoreStarterLibrary();
    await reload();
    return count;
  }

  // -----------------------------------------------------------------
  // Recommendations
  // -----------------------------------------------------------------

  /// Notes that a set of lines was offered, for both the counters and the
  /// rotation window.
  Future<void> noteSuggested(Iterable<String> ids) async {
    for (final id in ids) {
      _recentlyShown.remove(id);
      _recentlyShown.add(id);
    }
    while (_recentlyShown.length > _recentlyShownMemory) {
      _recentlyShown.removeAt(0);
    }
    await service.noteShown(ids);
    await reload();
  }

  Future<void> recordOutcome({
    required OpenerLine line,
    required InteractionOutcome outcome,
    ContextSnapshot? context,
    String? notes,
  }) async {
    await service.recordUsage(
      line: line,
      outcome: outcome,
      notes: notes,
      contextSnapshot: context,
    );
    await reload();
  }

  // -----------------------------------------------------------------
  // History and destructive actions
  // -----------------------------------------------------------------

  LibraryStatistics computeStatistics() =>
      statistics.compute(lines: _lines, interactions: _history);

  Future<void> clearHistory() async {
    await service.clearInteractionHistory();
    await reload();
  }

  /// Deletes everything, then reinstalls the starter library so the app is
  /// never left in an unusable empty state.
  Future<void> resetAllData() async {
    await service.interactions.clearAll();
    await service.lines.replaceAll(const <OpenerLine>[]);
    await updateSettings(AppSettings.defaults);
    await service.seedIfEmpty();
    _recentlyShown.clear();
    await reload();
  }

  // -----------------------------------------------------------------
  // Import
  // -----------------------------------------------------------------

  /// Applies a parsed import. Returns what actually changed.
  Future<ImportSummary> applyImport({
    required ImportPayload payload,
    required ImportMode mode,
  }) async {
    final existingIds = await service.lines.existingIds();
    final resolved = transfer.resolveCollisions(
      imported: payload.lines,
      existingIds: existingIds,
      mode: mode,
    );

    var replaced = 0;
    if (mode == ImportMode.replace) {
      replaced = existingIds.length;
      await service.interactions.clearAll();
      await service.lines.replaceAll(resolved.lines);
    } else {
      await service.lines.insertMany(resolved.lines);
    }

    // Interactions are only written for lines that now exist, so the foreign
    // key cannot be violated by a partial file.
    final knownIds = await service.lines.existingIds();
    final usable = payload.interactions
        .where((r) => knownIds.contains(r.openerLineId))
        .toList();
    await service.interactions.insertMany(usable);

    if (payload.settings != null) {
      await updateSettings(payload.settings!);
    }
    await reload();

    return ImportSummary(
      linesAdded: resolved.lines.length,
      linesReplaced: replaced,
      linesRekeyed: resolved.rekeyed,
      interactionsAdded: usable.length,
      settingsApplied: payload.settings != null,
    );
  }

  /// Builds the export document from current state.
  String buildExport({required bool includeInteractions}) {
    return transfer.buildExportJson(
      lines: _lines,
      settings: _settings,
      interactions: _history,
      includeInteractions: includeInteractions,
    );
  }
}

/// Makes [AppState] available to the widget tree and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    required AppState state,
    required super.child,
    super.key,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree.');
    return scope!.notifier!;
  }

  /// Reads state without subscribing to rebuilds. For use in callbacks.
  static AppState read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree.');
    return scope!.notifier!;
  }

  /// Shorthand for the current language's strings.
  static AppLocalizations strings(BuildContext context) => of(context).strings;
}
