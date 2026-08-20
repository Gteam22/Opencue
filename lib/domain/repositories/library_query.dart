import '../enums/enums.dart';
import '../models/opener_line.dart';

/// The set of filters and the sort order applied on the library screen.
///
/// Passed to OpenerLineRepository.query so filtering happens in one place and
/// can be tested without a widget.
class LibraryQuery {
  const LibraryQuery({
    this.searchText = '',
    this.locations = const <LocationTag>{},
    this.activities = const <ActivityTag>{},
    this.groupSizes = const <GroupSize>{},
    this.noiseLevels = const <NoiseLevel>{},
    this.cues = const <ObservableCue>{},
    this.tones = const <Tone>{},
    this.categories = const <LineCategory>{},
    this.boldness = const <ConversationBoldness>{},
    this.usageTypes = const <ConversationUsageType>{},
    this.minDirectness = kMinDirectness,
    this.maxDirectness = kMaxDirectness,
    this.favoritesOnly = false,
    this.userCreatedOnly = false,
    this.sort = LibrarySort.recentlyAdded,
  });

  /// Token-matched across native text, translations, pronunciation and
  /// browsing metadata. Punctuation is ignored, so `S M` finds `S? M?`.
  final String searchText;

  final Set<LocationTag> locations;

  /// Matches a line that lists any of these activities. An empty set means
  /// "no activity filter", never "lines that suit no activity".
  final Set<ActivityTag> activities;

  final Set<GroupSize> groupSizes;
  final Set<NoiseLevel> noiseLevels;
  final Set<ObservableCue> cues;
  final Set<Tone> tones;
  final Set<LineCategory> categories;
  final Set<ConversationBoldness> boldness;
  final Set<ConversationUsageType> usageTypes;
  final int minDirectness;
  final int maxDirectness;
  final bool favoritesOnly;
  final bool userCreatedOnly;
  final LibrarySort sort;

  bool get isEmpty =>
      searchText.trim().isEmpty &&
      locations.isEmpty &&
      activities.isEmpty &&
      groupSizes.isEmpty &&
      noiseLevels.isEmpty &&
      cues.isEmpty &&
      tones.isEmpty &&
      categories.isEmpty &&
      boldness.isEmpty &&
      usageTypes.isEmpty &&
      minDirectness == kMinDirectness &&
      maxDirectness == kMaxDirectness &&
      !favoritesOnly &&
      !userCreatedOnly;

  /// How many filters are active, for the "N filters" badge.
  int get activeFilterCount {
    var count = 0;
    if (locations.isNotEmpty) count++;
    if (activities.isNotEmpty) count++;
    if (groupSizes.isNotEmpty) count++;
    if (noiseLevels.isNotEmpty) count++;
    if (cues.isNotEmpty) count++;
    if (tones.isNotEmpty) count++;
    if (categories.isNotEmpty) count++;
    if (boldness.isNotEmpty) count++;
    if (usageTypes.isNotEmpty) count++;
    if (minDirectness != kMinDirectness || maxDirectness != kMaxDirectness) {
      count++;
    }
    if (favoritesOnly) count++;
    if (userCreatedOnly) count++;
    return count;
  }

  /// Whether [line] satisfies every active filter.
  ///
  /// This is the in-memory counterpart to the SQL that
  /// SqliteOpenerLineRepository.query builds, and the two must agree.
  /// `applyTo` below is what the library screen uses: AppState already holds
  /// the whole library in memory, so filtering there avoids a database round
  /// trip on every keystroke.
  bool matches(OpenerLine line) {
    final tokens = _searchTokens(searchText);
    if (tokens.isNotEmpty) {
      final haystack = _normaliseSearch(<String>[
        line.japaneseText,
        line.englishMeaning ?? '',
        ...line.translations.values,
        line.koreanRomanization ?? '',
        line.category.name,
        line.boldness?.name ?? '',
        line.usageType?.name ?? '',
        ...line.tones.map((tone) => tone.name),
        ...line.topics,
      ].join(' '));
      final words = haystack.split(' ').toSet();
      if (!tokens.every(
        (token) => token.length == 1
            ? words.contains(token)
            : haystack.contains(token),
      )) {
        return false;
      }
    }
    if (favoritesOnly && !line.isFavorite) return false;
    if (userCreatedOnly && !line.isUserCreated) return false;
    if (line.directness < minDirectness) return false;
    if (line.directness > maxDirectness) return false;
    if (categories.isNotEmpty && !categories.contains(line.category)) {
      return false;
    }
    if (boldness.isNotEmpty && !boldness.contains(line.boldness)) {
      return false;
    }
    if (usageTypes.isNotEmpty && !usageTypes.contains(line.usageType)) {
      return false;
    }
    if (locations.isNotEmpty &&
        line.locations.intersection(locations).isEmpty) {
      return false;
    }
    if (activities.isNotEmpty &&
        line.activities.intersection(activities).isEmpty) {
      return false;
    }
    if (groupSizes.isNotEmpty &&
        line.groupSizes.intersection(groupSizes).isEmpty) {
      return false;
    }
    if (noiseLevels.isNotEmpty &&
        line.noiseLevels.intersection(noiseLevels).isEmpty) {
      return false;
    }
    if (cues.isNotEmpty &&
        line.observableCues.intersection(cues).isEmpty) {
      return false;
    }
    if (tones.isNotEmpty && line.tones.intersection(tones).isEmpty) {
      return false;
    }
    return true;
  }

  /// Filters and sorts [lines] according to this query.
  List<OpenerLine> applyTo(Iterable<OpenerLine> lines) {
    final results = lines.where(matches).toList();
    switch (sort) {
      case LibrarySort.recentlyAdded:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case LibrarySort.mostUsed:
        results.sort((a, b) => b.timesUsed.compareTo(a.timesUsed));
      case LibrarySort.highestPositiveHistory:
        // Lines without enough recorded history sort last rather than being
        // flattered by a tiny sample, matching the SQL ordering.
        results.sort((a, b) {
          final aSignal = a.personalSignal;
          final bSignal = b.personalSignal;
          if (aSignal == null && bSignal == null) {
            return b.timesUsed.compareTo(a.timesUsed);
          }
          if (aSignal == null) return 1;
          if (bSignal == null) return -1;
          return bSignal.compareTo(aSignal);
        });
      case LibrarySort.alphabetical:
        results.sort((a, b) => a.japaneseText.compareTo(b.japaneseText));
    }
    return results;
  }

  LibraryQuery copyWith({
    String? searchText,
    Set<LocationTag>? locations,
    Set<ActivityTag>? activities,
    Set<GroupSize>? groupSizes,
    Set<NoiseLevel>? noiseLevels,
    Set<ObservableCue>? cues,
    Set<Tone>? tones,
    Set<LineCategory>? categories,
    Set<ConversationBoldness>? boldness,
    Set<ConversationUsageType>? usageTypes,
    int? minDirectness,
    int? maxDirectness,
    bool? favoritesOnly,
    bool? userCreatedOnly,
    LibrarySort? sort,
  }) {
    return LibraryQuery(
      searchText: searchText ?? this.searchText,
      locations: locations ?? this.locations,
      activities: activities ?? this.activities,
      groupSizes: groupSizes ?? this.groupSizes,
      noiseLevels: noiseLevels ?? this.noiseLevels,
      cues: cues ?? this.cues,
      tones: tones ?? this.tones,
      categories: categories ?? this.categories,
      boldness: boldness ?? this.boldness,
      usageTypes: usageTypes ?? this.usageTypes,
      minDirectness: minDirectness ?? this.minDirectness,
      maxDirectness: maxDirectness ?? this.maxDirectness,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      userCreatedOnly: userCreatedOnly ?? this.userCreatedOnly,
      sort: sort ?? this.sort,
    );
  }
}

String _normaliseSearch(String value) => value
    .toLowerCase()
    .replaceAll(
      RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+'),
      ' ',
    )
    .trim();

List<String> _searchTokens(String value) =>
    _normaliseSearch(value)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
