import 'dart:convert';

import '../../core/app_info.dart';
import '../../core/id_generator.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/interaction_record.dart';
import '../../domain/models/opener_line.dart';

/// Whether an import adds to the library or replaces it.
enum ImportMode {
  /// Keep existing lines and add the imported ones. Colliding ids are re-keyed.
  merge,

  /// Delete every existing line and install the imported ones.
  replace,
}

/// A validated, ready-to-apply import.
class ImportPayload {
  const ImportPayload({
    required this.schemaVersion,
    required this.lines,
    required this.interactions,
    this.settings,
    this.exportedAt,
    this.sourceAppVersion,
  });

  final int schemaVersion;
  final List<OpenerLine> lines;
  final List<InteractionRecord> interactions;
  final AppSettings? settings;
  final DateTime? exportedAt;
  final String? sourceAppVersion;

  bool get isEmpty => lines.isEmpty && interactions.isEmpty;
}

/// The outcome of parsing a file the user chose.
///
/// A malformed file produces a failure with a message the user can act on. It
/// never throws out of [TransferService.parse] and never leaves the library
/// half-written, because nothing is applied until parsing has fully succeeded.
class ImportResult {
  const ImportResult._({
    required this.isSuccess,
    this.payload,
    this.errors = const <String>[],
    this.warnings = const <String>[],
  });

  factory ImportResult.success(
    ImportPayload payload, {
    List<String> warnings = const <String>[],
  }) {
    return ImportResult._(
      isSuccess: true,
      payload: payload,
      warnings: warnings,
    );
  }

  factory ImportResult.failure(
    String error, {
    List<String> warnings = const <String>[],
  }) {
    return ImportResult._(
      isSuccess: false,
      errors: <String>[error],
      warnings: warnings,
    );
  }

  factory ImportResult.failures(List<String> errors) {
    return ImportResult._(isSuccess: false, errors: errors);
  }

  final bool isSuccess;
  final ImportPayload? payload;

  /// Reasons the file could not be used at all.
  final List<String> errors;

  /// Things that were skipped or adjusted but did not stop the import.
  final List<String> warnings;

  String get firstError => errors.isEmpty ? '' : errors.first;
}

/// How many records an applied import actually changed.
class ImportSummary {
  const ImportSummary({
    required this.linesAdded,
    required this.linesReplaced,
    required this.linesRekeyed,
    required this.interactionsAdded,
    required this.settingsApplied,
  });

  final int linesAdded;
  final int linesReplaced;

  /// Imported lines whose id already existed and were given a new one.
  final int linesRekeyed;

  final int interactionsAdded;
  final bool settingsApplied;
}

/// Reads and writes the OpenCue JSON transfer format.
///
/// ## Schema
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "app": "OpenCue",
///   "appVersion": "0.1.0",
///   "exportedAt": "2026-07-27T09:00:00.000Z",
///   "settings": { ... },
///   "lines": [ ... ],
///   "interactions": [ ... ]
/// }
/// ```
///
/// `schemaVersion` is the only field a reader may rely on before deciding how
/// to interpret the rest.
///
/// ### Version history
///
/// * **0** — pre-release drafts. The line array was called `openerLines` and
///   there was no `category` field. Still readable; see [_normaliseVersion0].
/// * **1** — current. Line arrays are called `lines`; every enum value is
///   stored by its stable name.
///
/// A file whose `schemaVersion` is higher than [AppInfo.transferSchemaVersion]
/// is rejected with a clear message rather than partially parsed, because
/// silently dropping fields the user can see in their own file is worse than
/// refusing.
class TransferService {
  TransferService({IdGenerator? idGenerator})
      : _ids = idGenerator ?? IdGenerator();

  final IdGenerator _ids;

  /// The lowest schema version this build can read.
  static const int minimumSupportedVersion = 0;

  // -------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------

  /// Builds the export document.
  ///
  /// Only user-created lines and favourites are exported by default: shipping
  /// the whole starter library back out again would bloat the file and create
  /// pointless id collisions on re-import. Pass `includeAllLines` to override.
  String buildExportJson({
    required List<OpenerLine> lines,
    required AppSettings settings,
    List<InteractionRecord> interactions = const <InteractionRecord>[],
    bool includeInteractions = false,
    bool includeAllLines = false,
    DateTime? now,
  }) {
    final selected = includeAllLines
        ? lines
        : lines.where((l) => l.isUserCreated || l.isFavorite).toList();

    final document = <String, Object?>{
      'schemaVersion': AppInfo.transferSchemaVersion,
      'app': AppInfo.appName,
      'appVersion': AppInfo.version,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'settings': settings.toJson(),
      'lines': selected.map((l) => l.toJson()).toList(),
      'interactions': includeInteractions
          ? interactions.map((r) => r.toJson()).toList()
          : <Object?>[],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  // -------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------

  /// Parses and validates [raw]. Never throws.
  ImportResult parse(String raw) {
    if (raw.trim().isEmpty) {
      return ImportResult.failure('import.error.emptyFile');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      return ImportResult.failure(
        'import.error.notJson:${error.message}',
      );
    }

    if (decoded is! Map<String, Object?>) {
      return ImportResult.failure('import.error.notAnObject');
    }

    final rawVersion = decoded['schemaVersion'];
    final int version;
    if (rawVersion == null) {
      // Pre-release files had no version field at all.
      version = 0;
    } else if (rawVersion is int) {
      version = rawVersion;
    } else if (rawVersion is num) {
      version = rawVersion.toInt();
    } else {
      return ImportResult.failure('import.error.badVersionField');
    }

    if (version < minimumSupportedVersion) {
      return ImportResult.failure('import.error.versionTooOld:$version');
    }
    if (version > AppInfo.transferSchemaVersion) {
      return ImportResult.failure(
        'import.error.versionTooNew:$version',
      );
    }

    final warnings = <String>[];
    final document =
        version == 0 ? _normaliseVersion0(decoded, warnings) : decoded;

    final rawLines = document['lines'];
    if (rawLines != null && rawLines is! List) {
      return ImportResult.failure('import.error.linesNotAList');
    }
    final rawInteractions = document['interactions'];
    if (rawInteractions != null && rawInteractions is! List) {
      return ImportResult.failure('import.error.interactionsNotAList');
    }

    final lines = <OpenerLine>[];
    final seenIds = <String>{};
    if (rawLines is List) {
      for (var i = 0; i < rawLines.length; i++) {
        final entry = rawLines[i];
        if (entry is! Map<String, Object?>) {
          warnings.add('import.warning.lineNotAnObject:$i');
          continue;
        }
        try {
          final line = OpenerLine.fromJson(entry);
          final problems = line.validationErrors();
          if (problems.isNotEmpty) {
            warnings.add('import.warning.invalidLine:${line.id}');
            continue;
          }
          if (!seenIds.add(line.id)) {
            // Duplicate ids inside a single file: keep the first, re-key the
            // rest so nothing is silently lost.
            final rekeyed = line.copyWith(id: _ids.importedLineId(line.id));
            lines.add(rekeyed);
            warnings.add('import.warning.duplicateIdInFile:${line.id}');
            seenIds.add(rekeyed.id);
            continue;
          }
          lines.add(line);
        } on FormatException catch (error) {
          warnings.add('import.warning.unreadableLine:$i:${error.message}');
        }
      }
    }

    final interactions = <InteractionRecord>[];
    if (rawInteractions is List) {
      final lineIds = lines.map((l) => l.id).toSet();
      for (var i = 0; i < rawInteractions.length; i++) {
        final entry = rawInteractions[i];
        if (entry is! Map<String, Object?>) {
          warnings.add('import.warning.interactionNotAnObject:$i');
          continue;
        }
        try {
          final record = InteractionRecord.fromJson(entry);
          // An interaction pointing at a line that is not in this file would
          // violate the foreign key on import, so it is dropped with a
          // warning rather than crashing the insert. (AppState.applyImport
          // applies a second, broader check against the real library once
          // merge/replace has happened, since a line referenced here might
          // already exist there under a different file; this check only
          // covers self-consistency within the file itself.)
          if (lineIds.contains(record.openerLineId)) {
            interactions.add(record);
          } else {
            warnings.add(
              'import.warning.orphanInteraction:${record.openerLineId}',
            );
          }
        } on FormatException catch (error) {
          warnings.add(
            'import.warning.unreadableInteraction:$i:${error.message}',
          );
        }
      }
    }

    AppSettings? settings;
    final rawSettings = document['settings'];
    if (rawSettings is Map<String, Object?>) {
      settings = AppSettings.fromJson(rawSettings);
    } else if (rawSettings != null) {
      warnings.add('import.warning.settingsIgnored');
    }

    if (lines.isEmpty && interactions.isEmpty) {
      return ImportResult.failure(
        'import.error.nothingUsable',
        warnings: warnings,
      );
    }

    final rawExportedAt = document['exportedAt'];
    return ImportResult.success(
      ImportPayload(
        schemaVersion: version,
        lines: lines,
        interactions: interactions,
        settings: settings,
        exportedAt:
            rawExportedAt is String ? DateTime.tryParse(rawExportedAt) : null,
        sourceAppVersion: document['appVersion'] is String
            ? document['appVersion']! as String
            : null,
      ),
      warnings: warnings,
    );
  }

  /// Upgrades a schema-version-0 document in place to the version 1 shape.
  Map<String, Object?> _normaliseVersion0(
    Map<String, Object?> source,
    List<String> warnings,
  ) {
    final migrated = Map<String, Object?>.of(source);
    if (!migrated.containsKey('lines') && migrated['openerLines'] is List) {
      migrated['lines'] = migrated.remove('openerLines');
      warnings.add('import.warning.migratedFromV0');
    }
    final lines = migrated['lines'];
    if (lines is List) {
      migrated['lines'] = lines.map((entry) {
        if (entry is! Map<String, Object?>) return entry;
        final copy = Map<String, Object?>.of(entry);
        // Version 0 had no category; universal is the safe default because it
        // means "no location bonus" rather than a wrong location bonus.
        copy.putIfAbsent('category', () => 'universal');
        // Version 0 stored a single tone under `tone`.
        if (!copy.containsKey('tones') && copy['tone'] is String) {
          copy['tones'] = <Object?>[copy.remove('tone')];
        }
        return copy;
      }).toList();
    }
    migrated['schemaVersion'] = AppInfo.transferSchemaVersion;
    return migrated;
  }

  /// Resolves id collisions against the ids already in the database.
  ///
  /// Returns the lines to write plus how many were re-keyed. In
  /// [ImportMode.replace] nothing can collide, so the list is returned as-is.
  ({List<OpenerLine> lines, int rekeyed}) resolveCollisions({
    required List<OpenerLine> imported,
    required Set<String> existingIds,
    required ImportMode mode,
  }) {
    if (mode == ImportMode.replace) {
      return (lines: imported, rekeyed: 0);
    }
    final taken = existingIds.toSet();
    final result = <OpenerLine>[];
    var rekeyed = 0;
    for (final line in imported) {
      if (!taken.contains(line.id)) {
        taken.add(line.id);
        result.add(line);
        continue;
      }
      var candidate = _ids.importedLineId(line.id);
      while (taken.contains(candidate)) {
        candidate = _ids.importedLineId(line.id);
      }
      taken.add(candidate);
      result.add(line.copyWith(id: candidate));
      rekeyed++;
    }
    return (lines: result, rekeyed: rekeyed);
  }
}
