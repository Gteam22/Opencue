import 'package:opencue/data/library_service.dart';
import 'package:opencue/data/db/app_database.dart';
import 'package:opencue/data/repositories/sqlite_repositories.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/context_snapshot.dart';
import 'package:opencue/domain/models/interaction_record.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// `sqflite_common`'s [Database] has no public `getVersion()` accessor —
/// version handling normally stays internal to `openDatabase`'s `version` /
/// `onUpgrade` parameters. Tests need to read it back out to assert the
/// migration actually ran, so this reads the same `PRAGMA user_version` value
/// SQLite itself uses to track it.
extension DatabaseVersionCheck on Database {
  Future<int> getVersion() async {
    final rows = await rawQuery('PRAGMA user_version');
    return rows.first.values.first! as int;
  }
}

/// A fixed timestamp so serialization comparisons are exact.
final DateTime testTime = DateTime.utc(2026, 3, 14, 9, 26, 53);

/// Builds a line with sensible defaults, overriding only what a test cares
/// about. Keeps the test bodies about the behaviour under test rather than
/// about constructing twenty-four fields.
OpenerLine line(
  String id, {
  String japanese = 'テスト用の一言です。',
  String? english = 'A line used in tests.',
  LineCategory category = LineCategory.universal,
  Set<LocationTag> locations = const <LocationTag>{},
  Set<ActivityTag> activities = const <ActivityTag>{},
  Set<ObservableCue> cues = const <ObservableCue>{},
  Set<GroupSize> groupSizes = const <GroupSize>{
    GroupSize.alone,
    GroupSize.withOneFriend,
    GroupSize.smallGroup,
    GroupSize.largeGroup,
    GroupSize.unknown,
  },
  Set<NoiseLevel> noiseLevels = const <NoiseLevel>{
    NoiseLevel.quiet,
    NoiseLevel.normal,
    NoiseLevel.loud,
    NoiseLevel.veryLoud,
  },
  Set<Tone> tones = const <Tone>{Tone.friendly},
  int directness = 2,
  Set<UseCondition> conditions = const <UseCondition>{},
  Set<AvoidCondition> avoidConditions = const <AvoidCondition>{},
  String? followUp,
  String? notes,
  bool isFavorite = false,
  bool isUserCreated = true,
  int timesShown = 0,
  int timesUsed = 0,
  int positive = 0,
  int neutral = 0,
  int negative = 0,
}) {
  return OpenerLine(
    id: id,
    japaneseText: japanese,
    englishMeaning: english,
    category: category,
    locations: locations,
    activities: activities,
    observableCues: cues,
    groupSizes: groupSizes,
    noiseLevels: noiseLevels,
    tones: tones,
    directness: directness,
    conditions: conditions,
    avoidConditions: avoidConditions,
    followUpSuggestion: followUp,
    notes: notes,
    isFavorite: isFavorite,
    isUserCreated: isUserCreated,
    createdAt: testTime,
    updatedAt: testTime,
    timesShown: timesShown,
    timesUsed: timesUsed,
    positiveResults: positive,
    neutralResults: neutral,
    negativeResults: negative,
  );
}

/// Builds a context snapshot. Every flag defaults to the harmless value, so a
/// test that sets `isWorking: true` is unambiguously about that flag.
///
/// The defaults below intentionally mirror ContextSnapshot's own constructor
/// defaults (LocationTag.other, GroupSize.unknown, NoiseLevel.normal) rather
/// than being nullable: those three fields are non-nullable on the model
/// itself, so a nullable parameter here could never actually be forwarded.
ContextSnapshot situation({
  LocationTag location = LocationTag.other,
  ActivityTag? activity,
  GroupSize groupSize = GroupSize.unknown,
  NoiseLevel noiseLevel = NoiseLevel.normal,
  Set<ObservableCue> cues = const <ObservableCue>{},
  bool eyeContact = false,
  bool conversationStarted = false,
  bool occupied = false,
  bool movingQuickly = false,
  bool working = false,
  bool headphones = false,
  bool isolated = false,
  String? userNotes,
  ContextSource source = ContextSource.manual,
}) {
  return ContextSnapshot(
    location: location,
    activity: activity,
    groupSize: groupSize,
    noiseLevel: noiseLevel,
    observableCues: cues,
    eyeContact: eyeContact,
    conversationAlreadyStarted: conversationStarted,
    personAppearsOccupied: occupied,
    personIsMovingQuickly: movingQuickly,
    isWorking: working,
    isUsingHeadphones: headphones,
    isIsolatedOrUnsafeSetting: isolated,
    userNotes: userNotes,
    createdAt: testTime,
    source: source,
  );
}

InteractionRecord record(
  String id,
  String lineId, {
  InteractionOutcome outcome = InteractionOutcome.positive,
  ContextSnapshot? context,
  String? notes,
  DateTime? when,
}) {
  return InteractionRecord(
    id: id,
    openerLineId: lineId,
    contextSnapshot: context,
    dateUsed: when ?? testTime,
    outcome: outcome,
    optionalNotes: notes,
  );
}

/// An open in-memory database plus repositories and a service over it.
class TestStack {
  TestStack._(this.database, this.service);

  final AppDatabase database;
  final LibraryService service;

  static Future<TestStack> create() async {
    final database = await AppDatabase.openInMemory();
    final service = LibraryService(
      lines: SqliteOpenerLineRepository(database.db),
      interactions: SqliteInteractionRepository(database.db),
      settings: SqliteSettingsRepository(database.db),
    );
    return TestStack._(database, service);
  }

  Future<void> dispose() => database.close();
}
