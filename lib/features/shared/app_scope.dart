import 'package:flutter/widgets.dart';

import '../../data/library_service.dart';
import '../../data/statistics_service.dart';
import '../../data/transfer/transfer_service.dart';
import '../../domain/enums/enums.dart';
import '../../domain/context/context_draft.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/context_preset.dart';
import '../../domain/models/context_snapshot.dart';
import '../../domain/models/interaction_record.dart';
import '../../domain/models/opener_line.dart';
import '../../domain/recommendation/recommendation_engine.dart';
import '../../domain/speech/speech_controller.dart';
import '../../domain/speech/speech_service.dart';
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
    SpeechService? speechService,
  })  : transfer = transfer ?? TransferService(),
        speech = SpeechController(
          speechService ?? const NullSpeechService(),
        );

  final LibraryService service;
  final RecommendationEngine engine;
  final StatisticsService statistics;
  final TransferService transfer;

  /// Shared speech controller. Owns which line is speaking, so no cue widget
  /// carries playback logic. Bound to a real engine on Android and to a no-op
  /// elsewhere, so `speech.isSupported` is the single gate for speech controls.
  final SpeechController speech;

  AppSettings _settings = AppSettings.defaults;
  List<OpenerLine> _lines = const <OpenerLine>[];
  List<InteractionRecord> _history = const <InteractionRecord>[];
  List<ContextPreset> _presets = const <ContextPreset>[];
  bool _isLoading = true;
  String? _loadError;

  /// Ids offered in recent recommendation rounds, so the engine can rotate.
  /// Session-only; there is no reason to persist it.
  final List<String> _recentlyShown = <String>[];

  static const int _recentlyShownMemory = 12;
  static const int _conversationLibraryVersion = 3;

  AppSettings get settings => _settings;

  List<OpenerLine> get lines => _lines;

  List<InteractionRecord> get history => _history;

  /// Saved contexts, favourites first. See ContextPresetRepository for the
  /// ordering rule.
  List<ContextPreset> get presets => _presets;

  /// The presets the user has actually applied, most recent first.
  List<ContextPreset> get recentPresets {
    final used = _presets.where((p) => p.lastUsedAt != null).toList()
      ..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return used.take(8).toList();
  }

  bool get isLoading => _isLoading;

  String? get loadError => _loadError;

  Set<String> get recentlyShownIds => _recentlyShown.toSet();

  AppLocalizations get strings => AppLocalizations(
        _settings.languageMode,
        romanizeKorean: _settings.showKoreanRomanization,
      );

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
      // Separate from the line seed so a database upgraded from v2 — which
      // had no presets table at all — receives the starter presets on its
      // next launch rather than only on a fresh install.
      await service.seedPresetsIfEmpty();
      _settings = await service.settings.load();
      if (_settings.conversationLibraryVersion <
          _conversationLibraryVersion) {
        await service.installConversationLibrary();
        _settings = _settings.copyWith(
          conversationLibraryVersion: _conversationLibraryVersion,
        );
        await service.settings.save(_settings);
      }
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
    _presets = await service.presets.getAll();
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
  // Context presets and the working draft
  // -----------------------------------------------------------------

  /// The context currently being composed.
  ///
  /// One object for the whole app: the radial menu, the scan correction
  /// sheet, the detailed editor and the preset loader all read and write this
  /// same draft, which is what stops the four surfaces drifting apart. It is
  /// **not** persisted; it lives for the session.
  ContextDraft _draft = ContextDraft.empty();
  ContextDraft get draft => _draft;

  /// The last draft that was actually applied, so cancelling an edit can fall
  /// back to it rather than to nothing.
  ContextDraft? _appliedDraft;
  ContextDraft? get appliedDraft => _appliedDraft;

  /// Replaces the working draft without applying it. Cancelling afterwards
  /// leaves [appliedDraft] untouched, as the brief requires.
  void setDraft(ContextDraft draft) {
    _draft = draft;
    notifyListeners();
  }

  /// Starts a fresh draft carrying the user's saved defaults, so tone and
  /// directness do not have to be set every time.
  ContextDraft newDraft() {
    _draft = ContextDraft.empty(
      defaultDirectness: _settings.defaultDirectness,
    );
    notifyListeners();
    return _draft;
  }

  /// Commits the working draft. Everything downstream reads the snapshot.
  void applyDraft(ContextDraft draft) {
    _draft = draft;
    _appliedDraft = draft;
    notifyListeners();
  }

  /// Discards edits and returns to the last applied context.
  void cancelDraft() {
    _draft = _appliedDraft ??
        ContextDraft.empty(defaultDirectness: _settings.defaultDirectness);
    notifyListeners();
  }

  Future<ContextPreset> saveCurrentAsPreset(String name) async {
    final preset = await service.savePreset(
      name: name,
      preset: ContextPreset(id: '', name: name, draft: _draft),
    );
    await reload();
    return preset;
  }

  /// Loads a preset into the working draft and records the use.
  Future<void> applyPreset(ContextPreset preset) async {
    _draft = preset.draft;
    _appliedDraft = preset.draft;
    notifyListeners();
    await service.presets.markUsed(preset.id);
    await reload();
  }

  Future<void> renamePreset(ContextPreset preset, String name) async {
    // A renamed starter preset stops being a starter preset: its name is now
    // the user's literal text, not a localization key.
    await service.presets.update(
      preset.copyWith(name: name.trim(), isStarter: false),
    );
    await reload();
  }

  Future<void> deletePreset(String id) async {
    await service.presets.delete(id);
    await reload();
  }

  Future<void> togglePresetFavorite(ContextPreset preset) async {
    await service.presets.setFavorite(
      preset.id,
      isFavorite: !preset.isFavorite,
    );
    await reload();
  }

  Future<void> reorderPresets(List<String> idsInOrder) async {
    await service.presets.reorder(idsInOrder);
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
    for (final preset in _presets) {
      await service.presets.delete(preset.id);
    }
    await updateSettings(
      AppSettings.defaults.copyWith(
        conversationLibraryVersion: _conversationLibraryVersion,
      ),
    );
    await service.seedIfEmpty();
    await service.installConversationLibrary();
    await service.seedPresetsIfEmpty();
    _draft = ContextDraft.empty();
    _appliedDraft = null;
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

  /// The shared speech controller, without subscribing to state rebuilds.
  /// Widgets that need to react to playback listen to it directly.
  static SpeechController speech(BuildContext context) => read(context).speech;
}
