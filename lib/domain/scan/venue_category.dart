import '../enums/enums.dart';

/// What kind of place this is.
///
/// Finer-grained than [LocationTag] on purpose. The recommendation engine only
/// needs "train station"; the scan can often tell platform from concourse from
/// train interior, and that distinction is worth keeping for display, for
/// diagnostics, and for future line targeting. [toLocationTag] collapses it
/// back down at the boundary.
enum VenueCategory {
  subwayOrTrainStation,
  trainPlatform,
  trainInterior,
  stationConcourse,
  ticketGateArea,
  busStop,
  cafe,
  bar,
  standingBar,
  restaurant,
  street,
  shoppingArea,
  convenienceStore,
  bookstore,
  park,
  waterfront,
  festival,
  cosplayEvent,
  concert,
  gym,
  kickboxingClass,
  meetup,
  party,
  other,
  unknown;

  /// The controlled value the existing engine understands.
  ///
  /// Several transit categories collapse to the same tag: the engine's line
  /// library is written in terms of "train station" and "public transport",
  /// and inventing new tags would strand every existing line.
  LocationTag? toLocationTag() {
    switch (this) {
      case VenueCategory.subwayOrTrainStation:
      case VenueCategory.trainPlatform:
      case VenueCategory.stationConcourse:
      case VenueCategory.ticketGateArea:
        return LocationTag.trainStation;
      case VenueCategory.trainInterior:
      case VenueCategory.busStop:
        return LocationTag.publicTransport;
      case VenueCategory.cafe:
        return LocationTag.cafe;
      case VenueCategory.bar:
        return LocationTag.bar;
      case VenueCategory.standingBar:
        return LocationTag.standingBar;
      case VenueCategory.restaurant:
        return LocationTag.restaurant;
      case VenueCategory.street:
        return LocationTag.street;
      case VenueCategory.shoppingArea:
        return LocationTag.shoppingArea;
      case VenueCategory.convenienceStore:
        return LocationTag.convenienceStore;
      case VenueCategory.bookstore:
        return LocationTag.bookstore;
      case VenueCategory.park:
        return LocationTag.park;
      case VenueCategory.waterfront:
        return LocationTag.waterfront;
      case VenueCategory.festival:
        return LocationTag.festival;
      case VenueCategory.cosplayEvent:
        return LocationTag.cosplayEvent;
      case VenueCategory.concert:
        return LocationTag.concert;
      case VenueCategory.gym:
        return LocationTag.gym;
      case VenueCategory.kickboxingClass:
        return LocationTag.kickboxingClass;
      case VenueCategory.meetup:
        return LocationTag.meetup;
      case VenueCategory.party:
        return LocationTag.party;
      case VenueCategory.other:
        return LocationTag.other;
      case VenueCategory.unknown:
        // Deliberately null rather than `other`: "I could not tell" and "some
        // other kind of place" are different answers, and collapsing them
        // would let an unknown masquerade as a decision.
        return null;
    }
  }

  /// Categories that describe the same kind of place at different angles.
  ///
  /// Members of a family reinforce each other during fusion instead of
  /// competing. Without this, "bar" from labels and "standing bar" from the
  /// scene classifier would look like disagreement and damp each other, when
  /// they are the same answer — an izakaya is genuinely hard to separate from
  /// a seated bar, and both map to sensible lines either way.
  static const Map<String, Set<VenueCategory>> families =
      <String, Set<VenueCategory>>{
    'transit': <VenueCategory>{
      VenueCategory.subwayOrTrainStation,
      VenueCategory.trainPlatform,
      VenueCategory.trainInterior,
      VenueCategory.stationConcourse,
      VenueCategory.ticketGateArea,
      VenueCategory.busStop,
    },
    'drinking': <VenueCategory>{
      VenueCategory.bar,
      VenueCategory.standingBar,
    },
    'retail': <VenueCategory>{
      VenueCategory.shoppingArea,
      VenueCategory.convenienceStore,
    },
    'fitness': <VenueCategory>{
      VenueCategory.gym,
      VenueCategory.kickboxingClass,
    },
    'event': <VenueCategory>{
      VenueCategory.festival,
      VenueCategory.concert,
      VenueCategory.cosplayEvent,
    },
  };

  /// The family this belongs to, or null when it stands alone.
  String? get family {
    for (final entry in families.entries) {
      if (entry.value.contains(this)) return entry.key;
    }
    return null;
  }

  /// Whether this is any kind of rail or road transit environment.
  bool get isTransit => family == 'transit';

  /// The broader category this refines, if any.
  ///
  /// Lets fusion treat "platform" and "concourse" as agreeing about a station
  /// rather than as two competing answers.
  VenueCategory? get parent {
    switch (this) {
      case VenueCategory.trainPlatform:
      case VenueCategory.stationConcourse:
      case VenueCategory.ticketGateArea:
        return VenueCategory.subwayOrTrainStation;
      default:
        return null;
    }
  }
}

/// A venue guess: what kind of place, optionally which specific one.
///
/// The two are separated because they fail independently. A platform is
/// recognisable from rails, signage and a train without any station name being
/// legible; conversely a clearly readable station name settles the category
/// even when the scene is visually ambiguous. Treating "no place name" as
/// "recognition failed" is what made the subway scan report Unknown.
class VenueGuess {
  const VenueGuess({
    required this.category,
    this.subtype,
    this.possiblePlaceName,
    this.placeNameFromText = false,
  });

  const VenueGuess.unknown()
      : category = VenueCategory.unknown,
        subtype = null,
        possiblePlaceName = null,
        placeNameFromText = false;

  final VenueCategory category;

  /// Human-readable refinement, e.g. "Platform 2", "Ticket gates".
  final String? subtype;

  /// A specific place, only when visible text supports it.
  ///
  /// Never guessed from the scene. A café that looks like a Starbucks is not
  /// a Starbucks, and inventing the name would be a fabrication the user has
  /// no way to check.
  final String? possiblePlaceName;

  /// True when [possiblePlaceName] came from text actually read in the image.
  final bool placeNameFromText;

  bool get isKnown => category != VenueCategory.unknown;

  VenueGuess copyWith({
    VenueCategory? category,
    String? subtype,
    String? possiblePlaceName,
    bool? placeNameFromText,
  }) {
    return VenueGuess(
      category: category ?? this.category,
      subtype: subtype ?? this.subtype,
      possiblePlaceName: possiblePlaceName ?? this.possiblePlaceName,
      placeNameFromText: placeNameFromText ?? this.placeNameFromText,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'category': category.name,
        'subtype': subtype,
        'possiblePlaceName': possiblePlaceName,
        'placeNameFromText': placeNameFromText,
      };

  static VenueGuess fromJson(Map<String, Object?> json) => VenueGuess(
        category: enumFromNameOr(
          VenueCategory.values,
          json['category'],
          VenueCategory.unknown,
        ),
        subtype: json['subtype'] as String?,
        possiblePlaceName: json['possiblePlaceName'] as String?,
        placeNameFromText: json['placeNameFromText'] == true,
      );

  @override
  String toString() =>
      '${category.name}${subtype == null ? '' : '/$subtype'}'
      '${possiblePlaceName == null ? '' : ' @$possiblePlaceName'}';
}
