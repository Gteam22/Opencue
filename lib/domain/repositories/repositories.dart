import '../enums/enums.dart';
import '../models/app_settings.dart';
import '../models/context_preset.dart';
import '../models/interaction_record.dart';
import '../models/opener_line.dart';
import 'library_query.dart';

/// Storage for openers.
///
/// The UI depends on this interface rather than on SQLite, so local storage
/// could later be swapped or synchronised without touching lib/features.
abstract class OpenerLineRepository {
  Future<List<OpenerLine>> getAll();

  Future<OpenerLine?> getById(String id);

  /// Applies search, filters and sort. See LibraryQuery.
  Future<List<OpenerLine>> query(LibraryQuery query);

  Future<void> insert(OpenerLine line);

  Future<void> insertMany(List<OpenerLine> lines);

  Future<void> update(OpenerLine line);

  Future<void> delete(String id);

  /// Removes every line and inserts the given list, in one transaction.
  Future<void> replaceAll(List<OpenerLine> lines);

  Future<void> setFavorite(String id, {required bool isFavorite});

  /// Bumps `timesShown` for lines that were offered as recommendations.
  Future<void> incrementTimesShown(Iterable<String> ids);

  /// Bumps `timesUsed` and the matching outcome counter.
  Future<void> recordOutcome(String id, InteractionOutcome outcome);

  Future<int> count();

  /// Ids currently present, used by the importer to detect collisions.
  Future<Set<String>> existingIds();
}

/// Storage for the interaction log.
abstract class InteractionRepository {
  Future<List<InteractionRecord>> getAll({int? limit});

  Future<List<InteractionRecord>> getForLine(String openerLineId);

  Future<void> insert(InteractionRecord record);

  Future<void> insertMany(List<InteractionRecord> records);

  Future<void> delete(String id);

  /// Empties the log. Line counters are reset separately.
  Future<void> clearAll();

  Future<int> count();

  Future<Set<String>> existingIds();
}

/// Storage for user preferences.
abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// Storage for saved and recent contexts.
///
/// Ordering is the repository's concern rather than the caller's: favourites
/// first, then `sortOrder`, then creation time, so a reorder is a single
/// column write and every screen shows the same sequence.
abstract class ContextPresetRepository {
  Future<List<ContextPreset>> getAll();

  Future<ContextPreset?> getById(String id);

  /// The most recently applied presets, newest first. Presets never applied
  /// are excluded rather than sorted last.
  Future<List<ContextPreset>> recentlyUsed({int limit = 8});

  Future<void> insert(ContextPreset preset);

  Future<void> insertMany(List<ContextPreset> presets);

  Future<void> update(ContextPreset preset);

  Future<void> delete(String id);

  /// Rewrites `sort_order` from the given id order, in one transaction.
  Future<void> reorder(List<String> idsInOrder);

  Future<void> setFavorite(String id, {required bool isFavorite});

  /// Records that a preset was applied: bumps the counter and the timestamp.
  Future<void> markUsed(String id);

  Future<int> count();

  Future<Set<String>> existingIds();
}
