import 'dart:math';

/// Generates ids for user-created lines and interaction records.
///
/// Deliberately not a UUID package: a timestamp plus randomness is unique
/// enough for a single-user local database, and it keeps ids short and
/// readable when inspecting the file by hand. The `user-` and `rec-` prefixes
/// make it obvious at a glance where a row came from.
class IdGenerator {
  IdGenerator({Random? random, DateTime Function()? clock})
      : _random = random ?? Random(),
        _clock = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _clock;

  static const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  String _suffix(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  String _timePart() =>
      _clock().toUtc().millisecondsSinceEpoch.toRadixString(36);

  /// Id for a line the user wrote.
  String lineId() => 'user-${_timePart()}-${_suffix(4)}';

  /// Id for an interaction record.
  String interactionId() => 'rec-${_timePart()}-${_suffix(4)}';

  /// Id for a context preset the user saved.
  String presetId() => 'preset-${_timePart()}-${_suffix(4)}';

  /// Id for an environmental scan.
  String scanId() => 'scan-${_timePart()}-${_suffix(4)}';

  /// Id for a line arriving from an import whose own id already exists.
  String importedLineId(String originalId) {
    final trimmed =
        originalId.length > 24 ? originalId.substring(0, 24) : originalId;
    return 'imported-$trimmed-${_suffix(4)}';
  }
}
