import '../domain/enums/enums.dart';
import '../domain/models/interaction_record.dart';
import '../domain/models/opener_line.dart';

/// A count keyed by an enum value, sorted highest first.
class TallyEntry<T> {
  const TallyEntry(this.key, this.count);

  final T key;
  final int count;
}

/// Local, restrained statistics for the history screen.
///
/// Percentages are only exposed once there are enough records for them to mean
/// anything. Below [minimumForRates] the screen shows counts instead, because
/// "100% positive" from one interaction is worse than no number at all.
class LibraryStatistics {
  const LibraryStatistics({
    required this.totalSuggestionsViewed,
    required this.totalLinesUsed,
    required this.outcomeCounts,
    required this.topLocations,
    required this.topTones,
    required this.bestLines,
    required this.recordedOutcomeCount,
  });

  /// Sum of `timesShown` across the library.
  final int totalSuggestionsViewed;

  /// Sum of `timesUsed` across the library.
  final int totalLinesUsed;

  final Map<InteractionOutcome, int> outcomeCounts;
  final List<TallyEntry<LocationTag>> topLocations;
  final List<TallyEntry<Tone>> topTones;

  /// Lines with the strongest personal record. Empty until there is enough
  /// history for the ranking to be honest.
  final List<OpenerLine> bestLines;

  /// Number of interactions with an outcome other than "not recorded".
  final int recordedOutcomeCount;

  /// Below this, rates are not shown at all.
  static const int minimumForRates = 8;

  /// Below this, per-line rankings are not shown.
  static const int minimumForLineRanking = 12;

  bool get hasEnoughForRates => recordedOutcomeCount >= minimumForRates;

  bool get isEmpty => totalSuggestionsViewed == 0 && totalLinesUsed == 0;

  /// Share of recorded outcomes for [outcome], or null when the sample is too
  /// small to quote a proportion.
  double? rateFor(InteractionOutcome outcome) {
    if (!hasEnoughForRates) return null;
    final total = recordedOutcomeCount;
    if (total == 0) return null;
    return (outcomeCounts[outcome] ?? 0) / total;
  }
}

/// Computes statistics from lines and the interaction log.
class StatisticsService {
  const StatisticsService();

  LibraryStatistics compute({
    required List<OpenerLine> lines,
    required List<InteractionRecord> interactions,
  }) {
    var shown = 0;
    var used = 0;
    for (final line in lines) {
      shown += line.timesShown;
      used += line.timesUsed;
    }

    final outcomes = <InteractionOutcome, int>{
      for (final outcome in InteractionOutcome.values) outcome: 0,
    };
    final locationCounts = <LocationTag, int>{};
    for (final record in interactions) {
      outcomes[record.outcome] = (outcomes[record.outcome] ?? 0) + 1;
      final location = record.contextSnapshot?.location;
      if (location != null) {
        locationCounts[location] = (locationCounts[location] ?? 0) + 1;
      }
    }

    // Tone popularity is derived from how often lines were used rather than
    // from how many lines carry the tone, which would just measure the shape
    // of the starter library.
    final toneCounts = <Tone, int>{};
    final byId = <String, OpenerLine>{for (final l in lines) l.id: l};
    for (final record in interactions) {
      final line = byId[record.openerLineId];
      if (line == null) continue;
      for (final tone in line.tones) {
        toneCounts[tone] = (toneCounts[tone] ?? 0) + 1;
      }
    }

    final recorded = interactions
        .where((r) => r.outcome != InteractionOutcome.notRecorded)
        .length;

    final ranked = <OpenerLine>[];
    if (recorded >= LibraryStatistics.minimumForLineRanking) {
      ranked.addAll(
        lines.where((l) => l.personalSignal != null && l.recordedOutcomes >= 3),
      );
      ranked.sort((a, b) {
        final bySignal = b.personalSignal!.compareTo(a.personalSignal!);
        if (bySignal != 0) return bySignal;
        final byVolume = b.recordedOutcomes.compareTo(a.recordedOutcomes);
        return byVolume != 0 ? byVolume : a.id.compareTo(b.id);
      });
    }

    return LibraryStatistics(
      totalSuggestionsViewed: shown,
      totalLinesUsed: used,
      outcomeCounts: outcomes,
      topLocations: _rank(locationCounts),
      topTones: _rank(toneCounts),
      bestLines: ranked.take(5).toList(),
      recordedOutcomeCount: recorded,
    );
  }

  List<TallyEntry<T>> _rank<T extends Enum>(Map<T, int> counts) {
    final entries = counts.entries
        .map((e) => TallyEntry<T>(e.key, e.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0
            ? byCount
            : a.key.index.compareTo(b.key.index);
      });
    return entries.take(5).toList();
  }
}
