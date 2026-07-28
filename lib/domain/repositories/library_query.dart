import '../enums/enums.dart';

/// The set of filters and the sort order applied on the library screen.
///
/// Passed to OpenerLineRepository.query so filtering happens in one place and
/// can be tested without a widget.
class LibraryQuery {
  const LibraryQuery({
    this.searchText = '',
    this.locations = const <LocationTag>{},
    this.cues = const <ObservableCue>{},
    this.tones = const <Tone>{},
    this.categories = const <LineCategory>{},
    this.minDirectness = kMinDirectness,
    this.maxDirectness = kMaxDirectness,
    this.favoritesOnly = false,
    this.userCreatedOnly = false,
    this.sort = LibrarySort.recentlyAdded,
  });

  /// Matched case-insensitively against both the Japanese and English text.
  final String searchText;

  final Set<LocationTag> locations;
  final Set<ObservableCue> cues;
  final Set<Tone> tones;
  final Set<LineCategory> categories;
  final int minDirectness;
  final int maxDirectness;
  final bool favoritesOnly;
  final bool userCreatedOnly;
  final LibrarySort sort;

  bool get isEmpty =>
      searchText.trim().isEmpty &&
      locations.isEmpty &&
      cues.isEmpty &&
      tones.isEmpty &&
      categories.isEmpty &&
      minDirectness == kMinDirectness &&
      maxDirectness == kMaxDirectness &&
      !favoritesOnly &&
      !userCreatedOnly;

  /// How many filters are active, for the "N filters" badge.
  int get activeFilterCount {
    var count = 0;
    if (locations.isNotEmpty) count++;
    if (cues.isNotEmpty) count++;
    if (tones.isNotEmpty) count++;
    if (categories.isNotEmpty) count++;
    if (minDirectness != kMinDirectness || maxDirectness != kMaxDirectness) {
      count++;
    }
    if (favoritesOnly) count++;
    if (userCreatedOnly) count++;
    return count;
  }

  LibraryQuery copyWith({
    String? searchText,
    Set<LocationTag>? locations,
    Set<ObservableCue>? cues,
    Set<Tone>? tones,
    Set<LineCategory>? categories,
    int? minDirectness,
    int? maxDirectness,
    bool? favoritesOnly,
    bool? userCreatedOnly,
    LibrarySort? sort,
  }) {
    return LibraryQuery(
      searchText: searchText ?? this.searchText,
      locations: locations ?? this.locations,
      cues: cues ?? this.cues,
      tones: tones ?? this.tones,
      categories: categories ?? this.categories,
      minDirectness: minDirectness ?? this.minDirectness,
      maxDirectness: maxDirectness ?? this.maxDirectness,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      userCreatedOnly: userCreatedOnly ?? this.userCreatedOnly,
      sort: sort ?? this.sort,
    );
  }
}
