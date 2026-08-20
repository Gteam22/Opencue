// Fusion tests.
//
// Every case the brief names, plus the invariants that matter more than any of
// them: group size is never inferred from GPS or audio, coordinates do not
// survive fusion, and a user correction outranks everything.
//
// No GPS, no Places, no network, no microphone, no camera. The fusion service
// is pure Dart over plain models, which is the whole reason it can be pinned
// this precisely.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/context/context_draft.dart';
import 'package:opencue/domain/context/context_evidence_fusion.dart';
import 'package:opencue/domain/context/radial_menu_tree.dart';
import 'package:opencue/domain/context/signals/audio_environment_signal.dart';
import 'package:opencue/domain/context/signals/context_signal.dart';
import 'package:opencue/domain/context/signals/location_signal.dart';
import 'package:opencue/domain/context/signals/nearby_place_signal.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/context_snapshot.dart';
import 'package:opencue/domain/scan/confidence.dart';
import 'package:opencue/domain/scan/venue_category.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final DateTime kNow = DateTime.utc(2026, 8, 5, 14, 30);

SignalMetadata meta(
  ContextSignalKind kind, {
  ConfidenceLevel level = ConfidenceLevel.high,
  DateTime? at,
}) =>
    SignalMetadata(
      kind: kind,
      providerId: 'fake',
      capturedAt: at ?? kNow,
      confidence: FieldConfidence(level),
      providerVersion: 'test',
    );

LocationSignal fakeLocation({
  double accuracy = 20,
  double? speed = 0,
  bool approximate = false,
  DateTime? at,
}) =>
    LocationSignal(
      metadata: meta(ContextSignalKind.deviceLocation, at: at),
      latitude: 33.59,
      longitude: 130.40,
      accuracyMeters: accuracy,
      speedMetersPerSecond: speed,
      isApproximate: approximate,
      source: LocationSignalSource.synthetic,
    );

NearbyPlaceSignal fakePlaces(List<NearbyPlaceCandidate> candidates) =>
    NearbyPlaceSignal(
      metadata: meta(ContextSignalKind.nearbyPlaces),
      candidates: candidates,
    );

NearbyPlaceCandidate place(
  PlaceType type, {
  double distance = 15,
  double likelihood = 0.8,
  String? name,
}) =>
    NearbyPlaceCandidate(
      types: <PlaceType>{type},
      distanceMeters: distance,
      providerLikelihood: likelihood,
      displayName: name,
    );

AudioEnvironmentSignal fakeAudio(
  Set<SoundCue> cues, {
  double? level = 0.4,
  bool usable = true,
  double cueConfidence = 0.8,
}) =>
    AudioEnvironmentSignal(
      metadata: meta(ContextSignalKind.ambientAudio),
      soundCues: cues,
      confidenceByCue: <SoundCue, double>{
        for (final cue in cues) cue: cueConfidence,
      },
      averageSoundLevel: level,
      noiseLevel: SoundCueMapping.noiseLevelFrom(
        averageSoundLevel: level,
        cues: cues,
        sampleWasUsable: usable,
      ),
      sampleDuration: const Duration(seconds: 3),
      sampleWasUsable: usable,
    );

ContextEvidenceBundle bundle({
  LocationSignal? location,
  NearbyPlaceSignal? places,
  AudioEnvironmentSignal? audio,
  VenueCategory? cameraVenue,
  GroupSize? cameraGroupSize,
  ConfidenceLevel cameraLevel = ConfidenceLevel.high,
  ContextSnapshot? confirmed,
  DateTime? confirmedAt,
  ContextDraft? corrected,
}) =>
    ContextEvidenceBundle(
      capturedAt: kNow,
      location: location,
      nearbyPlaces: places,
      audio: audio,
      cameraVenue: cameraVenue,
      cameraGroupSize: cameraGroupSize,
      cameraConfidence: FieldConfidence(cameraLevel),
      recentConfirmedContext: confirmed,
      recentConfirmedAt: confirmedAt,
      userCorrectedDraft: corrected,
    );

void main() {
  const fusion = ContextEvidenceFusionService();

  group('subway station', () {
    // Nearby subway station 18 m away, fix accurate to 22 m, train and
    // announcement audio, device stationary.
    final result = fusion.fuse(bundle(
      location: fakeLocation(accuracy: 22, speed: 0),
      places: fakePlaces(<NearbyPlaceCandidate>[
        place(PlaceType.subwayStation, distance: 18, name: 'Tenjin Station'),
      ]),
      audio: fakeAudio(<SoundCue>{
        SoundCue.train,
        SoundCue.publicAddressAnnouncement,
        SoundCue.doorChime,
      }),
    ));

    test('resolves to a station at high confidence', () {
      expect(result.draft.location, LocationTag.trainStation);
      expect(result.confidence.level, ConfidenceLevel.high);
      expect(result.reason, FusionReason.placeAndAudioAgree);
      expect(result.mayShowRecommendationsDirectly, isTrue);
    });

    test('keeps the station subtype and reports waiting', () {
      expect(result.draft.venue, VenueCategory.subwayOrTrainStation);
      // Stationary at a transit stop is waiting. This follows from a speed
      // measurement, not from a guess about what the user is doing.
      expect(result.draft.activity, ActivityTag.waiting);
    });

    test('sets a noise level from audio, and names the place', () {
      expect(result.draft.noiseLevel, NoiseLevel.normal);
      expect(result.placeName, 'Tenjin Station');
    });

    test('every field is marked as automatically derived', () {
      expect(
        result.draft.originOf(ContextDimension.location),
        DraftOrigin.fromScan,
      );
      expect(
        result.draft.originOf(ContextDimension.noiseLevel),
        DraftOrigin.fromScan,
      );
    });
  });

  group('train interior', () {
    final result = fusion.fuse(bundle(
      // Transit speed, so this is a carriage rather than a platform.
      location: fakeLocation(accuracy: 25, speed: 18),
      places: fakePlaces(<NearbyPlaceCandidate>[
        place(PlaceType.subwayStation, distance: 120, likelihood: 0.4),
      ]),
      audio: fakeAudio(<SoundCue>{
        SoundCue.trainWheels,
        SoundCue.doorChime,
        SoundCue.publicAddressAnnouncement,
      }),
    ));

    test('vehicle motion turns a station into public transport', () {
      expect(result.draft.location, LocationTag.publicTransport);
      expect(result.reason, FusionReason.vehicleMotion);
    });

    test('reports commuting rather than waiting', () {
      expect(result.draft.activity, ActivityTag.commuting);
    });

    test('confidence is medium or high, never low', () {
      expect(
        result.confidence.level,
        anyOf(ConfidenceLevel.medium, ConfidenceLevel.high),
      );
    });
  });

  group('cafe', () {
    final result = fusion.fuse(bundle(
      location: fakeLocation(accuracy: 15, speed: 0),
      places: fakePlaces(<NearbyPlaceCandidate>[
        place(PlaceType.cafe, distance: 12, likelihood: 0.85),
      ]),
      audio: fakeAudio(<SoundCue>{
        SoundCue.cupsOrGlasses,
        SoundCue.dishes,
        SoundCue.indoorConversation,
      }, level: 0.35),
    ));

    test('resolves to a cafe at high confidence', () {
      expect(result.draft.location, LocationTag.cafe);
      expect(result.confidence.level, ConfidenceLevel.high);
      expect(result.draft.venue, VenueCategory.cafe);
    });

    test('a stationary cafe customer is not reported as waiting', () {
      // Waiting is only inferred at transit stops and queues, where standing
      // still means something specific.
      expect(result.draft.activity, isNull);
    });
  });

  group('ambiguous shopping street', () {
    final result = fusion.fuse(bundle(
      location: fakeLocation(accuracy: 45, speed: 0.5),
      places: fakePlaces(<NearbyPlaceCandidate>[
        place(PlaceType.cafe, distance: 30, likelihood: 0.5),
        place(PlaceType.restaurant, distance: 34, likelihood: 0.48),
        place(PlaceType.clothingStore, distance: 40, likelihood: 0.45),
      ]),
      audio: fakeAudio(<SoundCue>{
        SoundCue.traffic,
        SoundCue.indoorConversation,
      }),
    ));

    test('does not claim an exact venue', () {
      expect(result.confidence.level,
          anyOf(ConfidenceLevel.medium, ConfidenceLevel.low));
      expect(result.mayShowRecommendationsDirectly, isFalse);
    });

    test('offers alternatives for one-tap correction', () {
      expect(result.alternativeLocations, isNotEmpty);
      expect(result.shouldOfferQuickCorrection ||
          result.shouldOpenRadialMenu, isTrue);
    });

    test('withholds the place name when the answer is in doubt', () {
      expect(result.placeName, isNull);
    });
  });

  group('bar versus restaurant', () {
    final result = fusion.fuse(bundle(
      location: fakeLocation(accuracy: 18, speed: 0),
      places: fakePlaces(<NearbyPlaceCandidate>[
        place(PlaceType.bar, distance: 14, likelihood: 0.55),
        place(PlaceType.restaurant, distance: 16, likelihood: 0.52),
      ]),
      audio: fakeAudio(<SoundCue>{
        SoundCue.loudMusic,
        SoundCue.crowd,
        SoundCue.cupsOrGlasses,
      }, level: 0.7),
    ));

    test('audio breaks the tie towards the bar', () {
      expect(result.draft.location, LocationTag.bar);
    });

    test('the restaurant remains an alternative', () {
      expect(result.alternativeLocations, contains(LocationTag.restaurant));
    });

    test('a close call is not presented as certain', () {
      expect(result.confidence.level, isNot(ConfidenceLevel.high));
    });

    test('loud music raises the noise level', () {
      expect(result.draft.noiseLevel,
          anyOf(NoiseLevel.loud, NoiseLevel.veryLoud));
    });
  });

  group('park', () {
    final result = fusion.fuse(bundle(
      location: fakeLocation(accuracy: 20, speed: 0.6),
      places: fakePlaces(<NearbyPlaceCandidate>[
        place(PlaceType.park, distance: 20, likelihood: 0.75),
      ]),
      audio: fakeAudio(<SoundCue>{SoundCue.birds, SoundCue.wind}, level: 0.12),
    ));

    test('resolves to a park at medium or high confidence', () {
      expect(result.draft.location, LocationTag.park);
      expect(result.confidence.level,
          anyOf(ConfidenceLevel.medium, ConfidenceLevel.high));
    });

    test('wind becomes a weather cue and the level reads quiet', () {
      expect(result.draft.cues, contains(ObservableCue.weather));
      expect(result.draft.noiseLevel, NoiseLevel.quiet);
    });
  });

  group('low-information environment', () {
    final result = fusion.fuse(bundle(
      location: fakeLocation(accuracy: 800, approximate: true),
      places: fakePlaces(const <NearbyPlaceCandidate>[]),
      audio: fakeAudio(const <SoundCue>{}, usable: false, level: null),
    ));

    test('refuses to guess', () {
      expect(result.confidence.level, ConfidenceLevel.unknown);
      expect(result.reason, FusionReason.noUsableEvidence);
      expect(result.draft.location, LocationTag.other);
    });

    test('routes to the radial menu', () {
      expect(result.shouldOpenRadialMenu, isTrue);
      expect(result.mayShowRecommendationsDirectly, isFalse);
    });

    test('explains itself in warnings', () {
      expect(result.warnings, contains('fusion.warning.noUsableEvidence'));
    });
  });

  group('strong location versus weak conflicting audio', () {
    test('one weak audio label does not override a good fix', () {
      final result = fusion.fuse(bundle(
        location: fakeLocation(accuracy: 12, speed: 0),
        places: fakePlaces(<NearbyPlaceCandidate>[
          place(PlaceType.cafe, distance: 8, likelihood: 0.9),
        ]),
        // Traffic audible through the window of a café on a main road.
        audio: fakeAudio(<SoundCue>{SoundCue.traffic}, cueConfidence: 0.45),
      ));
      expect(result.draft.location, LocationTag.cafe);
      expect(result.warnings,
          contains('fusion.warning.audioDisagreesWithPlace'));
    });
  });

  group('camera evidence', () {
    test('a camera scan added afterwards outweighs a weak place result', () {
      final result = fusion.fuse(bundle(
        location: fakeLocation(accuracy: 60, speed: 0),
        places: fakePlaces(<NearbyPlaceCandidate>[
          place(PlaceType.restaurant, distance: 50, likelihood: 0.4),
        ]),
        audio: fakeAudio(<SoundCue>{SoundCue.indoorConversation}),
        cameraVenue: VenueCategory.bookstore,
      ));
      expect(result.draft.location, LocationTag.bookstore);
      expect(result.reason, FusionReason.cameraScan);
    });
  });

  group('user correction outranks everything', () {
    test('an edited draft is returned untouched', () {
      final corrected = ContextDraft.empty()
          .apply(const SetLocation(LocationTag.kickboxingClass));
      final result = fusion.fuse(bundle(
        location: fakeLocation(accuracy: 10),
        places: fakePlaces(<NearbyPlaceCandidate>[
          place(PlaceType.cafe, distance: 5, likelihood: 0.99),
        ]),
        audio: fakeAudio(<SoundCue>{SoundCue.coffeeMachine}),
        corrected: corrected,
      ));
      expect(result.draft.location, LocationTag.kickboxingClass);
      expect(result.reason, FusionReason.userCorrection);
      expect(result.confidence.level, ConfidenceLevel.high);
    });
  });

  group('recent confirmed context', () {
    test('a fresh confirmed context is reused, so nothing is sampled', () {
      final result = fusion.fuse(bundle(
        confirmed: ContextSnapshot(location: LocationTag.standingBar),
        confirmedAt: kNow.subtract(const Duration(minutes: 2)),
        location: fakeLocation(),
        places: fakePlaces(<NearbyPlaceCandidate>[place(PlaceType.cafe)]),
      ));
      expect(result.draft.location, LocationTag.standingBar);
      expect(result.reason, FusionReason.recentConfirmedContext);
    });

    test('a stale one is not', () {
      final result = fusion.fuse(bundle(
        confirmed: ContextSnapshot(location: LocationTag.standingBar),
        confirmedAt: kNow.subtract(const Duration(minutes: 30)),
        location: fakeLocation(accuracy: 12),
        places: fakePlaces(<NearbyPlaceCandidate>[
          place(PlaceType.cafe, distance: 10, likelihood: 0.9),
        ]),
      ));
      expect(result.draft.location, LocationTag.cafe);
      expect(result.reason, isNot(FusionReason.recentConfirmedContext));
    });
  });

  group('privacy invariants', () {
    test('group size is never inferred from location or audio', () {
      // The strongest possible location and audio evidence, and a crowd cue.
      final result = fusion.fuse(bundle(
        location: fakeLocation(accuracy: 5, speed: 0),
        places: fakePlaces(<NearbyPlaceCandidate>[
          place(PlaceType.bar, distance: 3, likelihood: 0.99),
        ]),
        audio: fakeAudio(<SoundCue>{
          SoundCue.crowd,
          SoundCue.crowdedSpeech,
          SoundCue.cheering,
        }),
      ));
      expect(result.draft.groupSize, GroupSize.unknown);
      expect(
        result.draft.originOf(ContextDimension.groupSize),
        DraftOrigin.unset,
      );
    });

    test('group size comes from the camera when the camera supplies it', () {
      final result = fusion.fuse(bundle(
        location: fakeLocation(accuracy: 10),
        places: fakePlaces(<NearbyPlaceCandidate>[place(PlaceType.cafe)]),
        cameraVenue: VenueCategory.cafe,
        cameraGroupSize: GroupSize.withOneFriend,
      ));
      expect(result.draft.groupSize, GroupSize.withOneFriend);
    });

    test('no caution condition is ever inferred automatically', () {
      // Nothing a microphone or a GPS chip can measure says whether someone is
      // working, wearing headphones, or wants to be left alone.
      final result = fusion.fuse(bundle(
        location: fakeLocation(accuracy: 8),
        places: fakePlaces(<NearbyPlaceCandidate>[place(PlaceType.cafe)]),
        audio: fakeAudio(<SoundCue>{SoundCue.quiet}),
      ));
      expect(result.draft.cautions, isEmpty);
      expect(result.draft.toSnapshot().discouragesApproach, isFalse);
    });

    test('coordinates do not survive being discarded', () {
      final signal = fakeLocation();
      expect(signal.hasCoordinates, isTrue);
      final stripped = signal.withoutCoordinates();
      expect(stripped.hasCoordinates, isFalse);
      expect(stripped.coordinatesDiscarded, isTrue);
      // Everything fusion actually needs survives.
      expect(stripped.accuracyMeters, signal.accuracyMeters);
      expect(stripped.speedMetersPerSecond, signal.speedMetersPerSecond);
      expect(stripped.appearsStationary, signal.appearsStationary);
    });

    test('anonymising a place signal drops ids and names', () {
      final signal = fakePlaces(<NearbyPlaceCandidate>[
        const NearbyPlaceCandidate(
          types: <PlaceType>{PlaceType.cafe},
          providerPlaceId: 'ChIJsomething',
          displayName: 'A real cafe',
          distanceMeters: 10,
          providerLikelihood: 0.9,
        ),
      ]).anonymised();
      expect(signal.candidates.single.providerPlaceId, isNull);
      expect(signal.candidates.single.displayName, isNull);
      // The category and the geometry, which are what fusion uses, remain.
      expect(signal.candidates.single.primaryType, PlaceType.cafe);
      expect(signal.candidates.single.distanceMeters, 10);
    });
  });

  group('determinism', () {
    test('the same bundle fuses to the same result every time', () {
      ContextEvidenceBundle make() => bundle(
            location: fakeLocation(accuracy: 22, speed: 0),
            places: fakePlaces(<NearbyPlaceCandidate>[
              place(PlaceType.bar, distance: 14, likelihood: 0.55),
              place(PlaceType.restaurant, distance: 16, likelihood: 0.55),
            ]),
            audio: fakeAudio(<SoundCue>{SoundCue.music, SoundCue.crowd}),
          );
      final first = fusion.fuse(make());
      for (var run = 0; run < 20; run++) {
        final again = fusion.fuse(make());
        expect(again.draft.location, first.draft.location);
        expect(again.confidence.level, first.confidence.level);
        expect(again.alternativeLocations, first.alternativeLocations);
      }
    });

    test('the debug report names the winner and the reason', () {
      final report = fusion
          .fuse(bundle(
            location: fakeLocation(accuracy: 12),
            places: fakePlaces(<NearbyPlaceCandidate>[
              place(PlaceType.gym, distance: 8, likelihood: 0.9),
            ]),
          ))
          .debugReport();
      expect(report, contains('gym'));
      expect(report, contains('confidence'));
      expect(report, contains('factors'));
    });
  });

  group('time of day is only a weak tie-breaker', () {
    test('evening alone never implies a bar', () {
      // No place evidence at all, quiet audio, in the evening.
      final result = fusion.fuse(ContextEvidenceBundle(
        capturedAt: DateTime.utc(2026, 8, 5, 21, 30),
        location: fakeLocation(accuracy: 400, approximate: true),
        audio: fakeAudio(<SoundCue>{SoundCue.quiet}, level: 0.1),
      ));
      expect(result.draft.location, isNot(LocationTag.bar));
    });
  });
}
