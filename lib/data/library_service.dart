import '../core/id_generator.dart';
import '../domain/enums/enums.dart';
import '../domain/models/context_preset.dart';
import '../domain/models/context_snapshot.dart';
import '../domain/models/interaction_record.dart';
import '../domain/models/opener_line.dart';
import '../domain/repositories/repositories.dart';
import 'repositories/sqlite_repositories.dart';
import 'seed/conversation_seed_loader.dart';
import 'seed/seed_loader.dart';
import 'seed/starter_presets.dart';

/// Coordinates the operations that touch more than one repository.
///
/// Keeping these here rather than in the UI means "record an outcome" is one
/// call that always writes both the log entry and the line's counters, and can
/// be tested without a widget.
class LibraryService {
  LibraryService({
    required this.lines,
    required this.interactions,
    required this.settings,
    required this.presets,
    SeedLoader seedLoader = const SeedLoader(),
    ConversationSeedLoader conversationSeed =
        const ConversationSeedLoader(),
    StarterPresets presetSeed = const StarterPresets(),
    IdGenerator? idGenerator,
  })  : _seed = seedLoader,
        _conversationSeed = conversationSeed,
        _presetSeed = presetSeed,
        _ids = idGenerator ?? IdGenerator();

  final OpenerLineRepository lines;
  final InteractionRepository interactions;
  final SettingsRepository settings;
  final ContextPresetRepository presets;
  final SeedLoader _seed;
  final ConversationSeedLoader _conversationSeed;
  final StarterPresets _presetSeed;
  final IdGenerator _ids;

  // Version 2 briefly shipped six provisional cue rows. Their content now
  // lives in the structured first-meeting source under stable hashed IDs.
  static const Set<String> _retiredConversationLineIds = <String>{
    'conversation-playful-013',
    'conversation-playful-014',
    'conversation-playful-015',
    'conversation-playful-016',
    'conversation-playful-017',
    'conversation-playful-018',
  };

  /// Installs the starter library if the database has no lines at all.
  ///
  /// Returns the number of lines inserted, so a first run can be distinguished
  /// from a normal one.
  Future<int> seedIfEmpty() async {
    final existing = await lines.count();
    if (existing > 0) return 0;
    final starter = _seed.load();
    await lines.insertMany(starter);
    return starter.length;
  }

  /// Installs missing records from the generated manual conversation library.
  /// AppState gates this by a persisted content version, so intentional user
  /// deletions are not silently undone on every launch.
  Future<int> installConversationLibrary() async {
    final starter = _conversationSeed.load();
    final existingIds = await lines.existingIds();
    for (final id in _retiredConversationLineIds.intersection(existingIds)) {
      await lines.delete(id);
    }
    final missing = starter
        .where((line) =>
            !existingIds.contains(line.id) ||
            _retiredConversationLineIds.contains(line.id))
        .toList();
    if (missing.isNotEmpty) await lines.insertMany(missing);
    return missing.length;
  }

  /// Installs the starter context presets if none exist.
  ///
  /// Separate from [seedIfEmpty] so that a database created before presets
  /// existed gets them on its next launch, rather than only on a fresh
  /// install. Deliberately *not* re-run when the user has deleted them all:
  /// an empty presets list is a legitimate state, so this checks the total
  /// rather than the starter ids specifically... except on a database that has
  /// never held any preset at all, which is the case a migration produces.
  Future<int> seedPresetsIfEmpty() async {
    final existing = await presets.count();
    if (existing > 0) return 0;
    final starter = _presetSeed.load();
    await presets.insertMany(starter);
    return starter.length;
  }

  /// Saves the current context under a user-supplied name.
  Future<ContextPreset> savePreset({
    required String name,
    required ContextPreset preset,
  }) async {
    final stored = preset.copyWith(
      id: preset.id.isEmpty ? _ids.presetId() : preset.id,
      name: name.trim(),
    );
    await presets.insert(stored);
    return stored;
  }

  /// Reinstates any missing starter line without touching the user's own.
  ///
  /// Starter lines the user has edited are left alone unless [overwriteEdited]
  /// is set; the point of the action is to recover deleted lines, not to
  /// discard someone's work by surprise.
  Future<int> restoreStarterLibrary({bool overwriteEdited = false}) async {
    final starter = <OpenerLine>[
      ..._seed.load(),
      ..._conversationSeed.load(),
    ];
    final existingIds = await lines.existingIds();
    final toInsert = <OpenerLine>[];
    final toUpdate = <OpenerLine>[];
    for (final line in starter) {
      if (!existingIds.contains(line.id)) {
        toInsert.add(line);
      } else if (overwriteEdited) {
        toUpdate.add(line);
      }
    }
    if (toInsert.isNotEmpty) await lines.insertMany(toInsert);
    for (final line in toUpdate) {
      await lines.update(line);
    }
    return toInsert.length + toUpdate.length;
  }

  /// Records that a line was used, writing both the log entry and the
  /// counters on the line itself.
  Future<InteractionRecord> recordUsage({
    required OpenerLine line,
    required InteractionOutcome outcome,
    String? notes,
    DateTime? when,
    ContextSnapshot? contextSnapshot,
  }) async {
    final record = InteractionRecord(
      id: _ids.interactionId(),
      openerLineId: line.id,
      contextSnapshot: contextSnapshot,
      dateUsed: when,
      outcome: outcome,
      optionalNotes: notes,
    );
    await interactions.insert(record);
    await lines.recordOutcome(line.id, outcome);
    return record;
  }

  /// Notes that a set of lines was shown as recommendations.
  Future<void> noteShown(Iterable<String> ids) =>
      lines.incrementTimesShown(ids);

  /// Copies a line, marking the copy as user-created so it can be edited and
  /// deleted freely.
  Future<OpenerLine> duplicate(OpenerLine source) async {
    final now = DateTime.now().toUtc();
    final copy = source.copyWith(
      id: _ids.lineId(),
      isUserCreated: true,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      timesShown: 0,
      timesUsed: 0,
      positiveResults: 0,
      neutralResults: 0,
      negativeResults: 0,
    );
    await lines.insert(copy);
    return copy;
  }

  /// Empties the interaction log and resets the per-line counters that were
  /// derived from it, so statistics and history cannot disagree.
  Future<void> clearInteractionHistory() async {
    await interactions.clearAll();
    final repo = lines;
    if (repo is SqliteOpenerLineRepository) {
      await repo.resetAllCounters();
    }
  }
}
