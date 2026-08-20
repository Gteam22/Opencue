import 'dart:convert';

import '../../domain/models/opener_line.dart';
import 'starter_library.dart';

/// Parses the embedded starter library.
///
/// Seeding deliberately goes through OpenerLine.fromJson, the same parser the
/// importer uses, so the seed doubles as a permanent test of that code path.
class SeedLoader {
  const SeedLoader();

  /// Reads and parses the bundled starter lines.
  ///
  /// Throws FormatException if the embedded asset is malformed, which would be
  /// a build error rather than a user-facing condition; the seed test catches
  /// it long before a release.
  List<OpenerLine> load({DateTime? createdAt}) {
    final decoded = jsonDecode(starterLibraryJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Starter library is not a JSON object.');
    }
    final rawLines = decoded['lines'];
    if (rawLines is! List) {
      throw const FormatException('Starter library has no "lines" array.');
    }
    final stamp = createdAt ?? DateTime.now().toUtc();
    final lines = <OpenerLine>[];
    for (final entry in rawLines) {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('Starter library entry is not an object.');
      }
      final line = OpenerLine.fromJson(entry);
      lines.add(
        line.copyWith(
          isUserCreated: false,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }
    return lines;
  }

  /// The ids of every starter line, used to tell seed lines from user lines
  /// when restoring the starter library.
  Set<String> seedIds() => load().map((l) => l.id).toSet();
}
