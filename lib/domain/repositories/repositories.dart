import '../enums/enums.dart';
import '../models/app_settings.dart';
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
