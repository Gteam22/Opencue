library;

import '../../enums/enums.dart';
import '../../scan/confidence.dart';
import '../../scan/venue_category.dart';
import 'context_signal.dart';
import 'location_signal.dart';

/// Provider-neutral place categories.
///
/// A deliberate intermediate vocabulary. Google's place types are a long,
/// changing list; OpenCue's [LocationTag] is a short, stable one the 155 lines
/// are written against. Mapping directly between them would put provider
/// strings in the domain model and break the moment the provider renames one.
/// This enum is the seam: the provider adapter maps its strings onto these,
/// and [PlaceTypeMapping] maps these onto the domain.
enum PlaceType {
  // Food and drink.
  cafe,
  restaurant,
  bakery,
  bar,
  nightClub,
  convenienceStore,
  foodMarket,

  // Transit.
  subwayStation,
  trainStation,
  transitStation,
  busStation,
  airport,

  // Shopping.
  shoppingMall,
  departmentStore,
  clothingStore,
  bookStore,
  supermarket,

  // Outdoors.
  park,
  touristAttraction,
  marina,
  beach,

  // Events and fitness.
  gym,
  stadium,
  performingArtsVenue,
  conventionCenter,
  museum,

  // Everything the adapter recognised but OpenCue has no opinion about.
  other,
}

/// One candidate place near the device.
class NearbyPlaceCandidate {
  const NearbyPlaceCandidate({
    required this.types,
    this.providerPlaceId,
    this.displayName,
    this.distanceMeters,
    this.providerLikelihood = 0,
    this.isOpen,
  });

  /// The provider's own identifier. Deliberately **not** persisted in ordinary
  /// history: it is a durable handle to a real venue the user visited.
  final String? providerPlaceId;

  /// The venue's name. Shown only when confidence is high enough and the user
  /// has not turned place names off, and excluded from exports by default.
  final String? displayName;

  final Set<PlaceType> types;
  final double? distanceMeters;

  /// The provider's own 0–1 likelihood, where it supplies one.
  final double providerLikelihood;

  /// Only used when the data is reliable; a closed venue is a weak negative,
  /// never a hard exclusion, because opening hours are frequently wrong.
  final bool? isOpen;

  PlaceType get primaryType => types.isEmpty ? PlaceType.other : types.first;

  /// Whether the device could plausibly be *inside* this place.
  ///
  /// Compares the distance against the fix's own error radius plus a building
  /// allowance, so a 12 m candidate with a 22 m fix counts as inside, while the
  /// same candidate 300 m away does not.
  bool isWithinVenueRadius(double? accuracyMeters) {
    final distance = distanceMeters;
    if (distance == null) return false;
    const buildingAllowance = 25.0;
    return distance <= (accuracyMeters ?? 0) + buildingAllowance;
  }

  /// The candidate with anything durably identifying stripped out.
  NearbyPlaceCandidate anonymised() => NearbyPlaceCandidate(
        types: types,
        distanceMeters: distanceMeters,
        providerLikelihood: providerLikelihood,
        isOpen: isOpen,
      );

  @override
  String toString() => 'NearbyPlaceCandidate(${primaryType.name}, '
      '${distanceMeters?.round()} m, p=$providerLikelihood)';
}

/// The candidates near a position, ranked.
class NearbyPlaceSignal extends ContextSignal {
  const NearbyPlaceSignal({
    required SignalMetadata metadata,
    this.candidates = const <NearbyPlaceCandidate>[],
    this.locationWasApproximate = false,
  }) : super(metadata);

  NearbyPlaceSignal.unavailable({
    required String providerId,
    required SignalUnavailableReason reason,
    required DateTime capturedAt,
    List<String> warnings = const <String>[],
  })  : candidates = const <NearbyPlaceCandidate>[],
        locationWasApproximate = false,
        super(SignalMetadata(
          kind: ContextSignalKind.nearbyPlaces,
          providerId: providerId,
          capturedAt: capturedAt,
          unavailableReason: reason,
          warnings: warnings,
        ));

  /// Ranked, most likely first. Several are returned on purpose: on a shopping
  /// street the honest answer is a list, not a winner.
  final List<NearbyPlaceCandidate> candidates;

  final bool locationWasApproximate;

  NearbyPlaceCandidate? get best =>
      candidates.isEmpty ? null : candidates.first;

  /// Whether the top candidates are too close together to pick between.
  ///
  /// The test the brief asks for: do not claim an exact café when several
  /// places are equally plausible. Two candidates within a tenth of each other
  /// in likelihood, mapping to *different* location tags, is a tie.
  bool get isContested {
    if (candidates.length < 2) return false;
    final first = candidates[0];
    final second = candidates[1];
    if (PlaceTypeMapping.toLocationTag(first.primaryType) ==
        PlaceTypeMapping.toLocationTag(second.primaryType)) {
      return false;
    }
    return (first.providerLikelihood - second.providerLikelihood).abs() < 0.1;
  }

  /// The distinct location tags the candidates map onto, in rank order.
  List<LocationTag> get candidateTags {
    final seen = <LocationTag>[];
    for (final candidate in candidates) {
      final tag = PlaceTypeMapping.toLocationTag(candidate.primaryType);
      if (tag != null && !seen.contains(tag)) seen.add(tag);
    }
    return seen;
  }

  /// The signal with every provider id and place name removed.
  NearbyPlaceSignal anonymised() => NearbyPlaceSignal(
        metadata: metadata,
        candidates: candidates.map((c) => c.anonymised()).toList(),
        locationWasApproximate: locationWasApproximate,
      );
}

/// Turns provider-neutral place types into OpenCue's own vocabulary.
///
/// Every value here is a real [LocationTag] or [VenueCategory]; there are no
/// new strings, so a place type cannot introduce a location the recommendation
/// engine has never heard of.
abstract final class PlaceTypeMapping {
  /// The broad tag the engine scores. Null means "OpenCue has no location for
  /// this", which is honest and better than forcing it into `other`.
  static LocationTag? toLocationTag(PlaceType type) => _tags[type];

  /// The finer-grained venue kept alongside the tag, where one exists. This is
  /// what lets a subway station show as "Platform" while the engine still
  /// reasons about `trainStation`.
  static VenueCategory? toVenueCategory(PlaceType type) => _venues[type];

  static const Map<PlaceType, LocationTag> _tags = <PlaceType, LocationTag>{
    PlaceType.cafe: LocationTag.cafe,
    PlaceType.bakery: LocationTag.cafe,
    PlaceType.restaurant: LocationTag.restaurant,
    PlaceType.convenienceStore: LocationTag.convenienceStore,
    // No dedicated market tag; a food market is a place you browse and buy in.
    PlaceType.foodMarket: LocationTag.shoppingArea,
    PlaceType.supermarket: LocationTag.convenienceStore,

    PlaceType.bar: LocationTag.bar,
    PlaceType.nightClub: LocationTag.club,

    PlaceType.subwayStation: LocationTag.trainStation,
    PlaceType.trainStation: LocationTag.trainStation,
    PlaceType.transitStation: LocationTag.publicTransport,
    PlaceType.busStation: LocationTag.publicTransport,
    // An airport is not a station and OpenCue has no airport lines, so it maps
    // to the broadest honest tag rather than pretending.
    PlaceType.airport: LocationTag.publicTransport,

    PlaceType.shoppingMall: LocationTag.shoppingArea,
    PlaceType.departmentStore: LocationTag.shoppingArea,
    PlaceType.clothingStore: LocationTag.shoppingArea,
    PlaceType.bookStore: LocationTag.bookstore,

    PlaceType.park: LocationTag.park,
    PlaceType.marina: LocationTag.waterfront,
    PlaceType.beach: LocationTag.waterfront,
    // A tourist attraction could be anything at all, so it stays unmapped
    // rather than being guessed at.

    PlaceType.gym: LocationTag.gym,
    PlaceType.stadium: LocationTag.concert,
    PlaceType.performingArtsVenue: LocationTag.concert,
    // A convention centre is where a cosplay event happens, but it is also
    // where a trade show happens. Mapping it to cosplayEvent would put costume
    // lines in front of someone at a dentistry conference, so it maps to the
    // neutral shopping/indoor-public tag and lets a camera scan or the radial
    // menu decide.
    PlaceType.conventionCenter: LocationTag.other,
    PlaceType.museum: LocationTag.other,
  };

  static const Map<PlaceType, VenueCategory> _venues =
      <PlaceType, VenueCategory>{
    PlaceType.cafe: VenueCategory.cafe,
    PlaceType.restaurant: VenueCategory.restaurant,
    PlaceType.convenienceStore: VenueCategory.convenienceStore,
    PlaceType.bar: VenueCategory.bar,
    // No nightClub subtype exists: LocationTag.club is already the right
    // granularity, so adding one would be a value with nothing behind it.
    PlaceType.subwayStation: VenueCategory.subwayOrTrainStation,
    PlaceType.trainStation: VenueCategory.subwayOrTrainStation,
    PlaceType.busStation: VenueCategory.busStop,
    PlaceType.shoppingMall: VenueCategory.shoppingArea,
    PlaceType.bookStore: VenueCategory.bookstore,
    PlaceType.park: VenueCategory.park,
    PlaceType.gym: VenueCategory.gym,
  };

  /// Every place type OpenCue can turn into a location. Used by a test that
  /// fails if a new `PlaceType` is added without a decision being made.
  static Set<PlaceType> get mappedTypes => _tags.keys.toSet();

  /// Place types deliberately left unmapped, with the reason recorded in the
  /// comments above. A test asserts this list and `mappedTypes` together cover
  /// the whole enum, so silence is never the same as an oversight.
  static const Set<PlaceType> deliberatelyUnmapped = <PlaceType>{
    PlaceType.touristAttraction,
    PlaceType.other,
  };

  /// Ranks candidates for a given fix.
  ///
  /// Deterministic and pure, so every weight below is testable. The ordering
  /// is by descending score, with ties broken on distance and then on name so
  /// the same inputs always produce the same list.
  static List<NearbyPlaceCandidate> rank(
    List<NearbyPlaceCandidate> candidates,
    LocationSignal location,
  ) {
    final scored = <(NearbyPlaceCandidate, double)>[];
    for (final candidate in candidates) {
      var score = candidate.providerLikelihood * 100;

      // Inside the plausible radius is the single strongest place signal.
      if (candidate.isWithinVenueRadius(location.accuracyMeters)) {
        score += 40;
      }

      final distance = candidate.distanceMeters;
      if (distance != null) {
        // Nearer is better, tapering off rather than dropping sharply, so a
        // 30 m candidate is not treated as wildly worse than a 25 m one.
        score += (50 - distance).clamp(-30, 50);
      }

      // A stationary device inside a venue is probably in it. A moving one is
      // probably passing, so proximity means much less.
      if (location.appearsStationary) {
        score += 15;
      } else if (location.appearsInVehicle) {
        score -= 30;
      }

      // Reported as closed is a weak negative only: opening hours are often
      // stale, and a closed shop is still somewhere you can stand outside.
      if (candidate.isOpen == false) score -= 15;

      // An unmapped type cannot become a recommendation, so it sinks.
      if (toLocationTag(candidate.primaryType) == null) score -= 50;

      scored.add((candidate, score));
    }

    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      final byDistance =
          (a.$1.distanceMeters ?? 1e9).compareTo(b.$1.distanceMeters ?? 1e9);
      if (byDistance != 0) return byDistance;
      return (a.$1.displayName ?? '').compareTo(b.$1.displayName ?? '');
    });
    return scored.map((entry) => entry.$1).toList();
  }

  /// Confidence in the top candidate.
  static FieldConfidence confidenceFor(
    List<NearbyPlaceCandidate> ranked,
    LocationSignal location,
  ) {
    if (ranked.isEmpty) return const FieldConfidence(ConfidenceLevel.unknown);
    final best = ranked.first;
    if (toLocationTag(best.primaryType) == null) {
      return const FieldConfidence(ConfidenceLevel.unknown);
    }

    var level = ConfidenceLevel.high;
    void demoteTo(ConfidenceLevel candidate) {
      if (candidate.index > level.index) level = candidate;
    }

    if (!best.isWithinVenueRadius(location.accuracyMeters)) {
      demoteTo(ConfidenceLevel.medium);
    }
    if (!location.isVenuePrecise) demoteTo(ConfidenceLevel.medium);
    if (location.isApproximate) demoteTo(ConfidenceLevel.low);
    if (location.appearsInVehicle) demoteTo(ConfidenceLevel.low);

    // Several plausible neighbours mapping to different tags: the honest
    // answer is a list, so the top one cannot be high confidence.
    final distinctTags = ranked
        .take(4)
        .map((c) => toLocationTag(c.primaryType))
        .whereType<LocationTag>()
        .toSet();
    if (distinctTags.length > 2) demoteTo(ConfidenceLevel.low);
    if (distinctTags.length == 2) demoteTo(ConfidenceLevel.medium);

    return FieldConfidence(level);
  }
}
