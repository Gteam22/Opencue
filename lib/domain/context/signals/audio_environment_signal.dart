library;

import '../../enums/enums.dart';
import '../../scan/confidence.dart';
import 'context_signal.dart';

/// Broad environmental sound categories.
///
/// A controlled vocabulary sitting between a general audio model's several
/// hundred labels and OpenCue's twenty [ObservableCue] values. The model's own
/// label strings never reach a widget or the engine: the adapter maps them onto
/// these, and [SoundCueMapping] maps these onto the domain.
///
/// Nothing here describes a person. There is no speaker identification, no
/// speech content, no emotion, no age or gender inference. `speechPresent` and
/// `crowdedSpeech` record that voices are audible, which is a property of a
/// room, and nothing more is derived from them.
enum SoundCue {
  // Transit.
  train,
  railTransport,
  subwayOrMetro,
  vehicleInterior,
  publicAddressAnnouncement,
  trainWheels,
  trainHorn,
  doorChime,
  traffic,
  bus,
  aircraft,

  // Café and restaurant.
  dishes,
  cutlery,
  cupsOrGlasses,
  indoorConversation,
  coffeeMachine,
  restaurantAmbience,

  // Nightlife and entertainment.
  music,
  loudMusic,
  danceMusic,
  crowd,
  cheering,
  applause,
  livePerformance,
  clubBass,
  festivalAmbience,

  // Fitness.
  gymEquipment,
  impactSounds,
  boxingBell,
  strikingSounds,
  exerciseAmbience,
  sportsCrowd,

  // Outdoors.
  birds,
  wind,
  water,
  waves,
  rain,
  roadTraffic,
  dogBarking,

  // General.
  quiet,
  speechPresent,
  crowdedSpeech,
  mechanicalAmbience,
  unknown,
}

/// What a short ambient sample sounded like.
class AudioEnvironmentSignal extends ContextSignal {
  AudioEnvironmentSignal({
    required SignalMetadata metadata,
    Set<SoundCue>? soundCues,
    this.noiseLevel,
    Map<SoundCue, double>? confidenceByCue,
    this.averageSoundLevel,
    this.sampleDuration = Duration.zero,
    this.sampleWasUsable = true,
  })  : soundCues = Set.unmodifiable(soundCues ?? const <SoundCue>{}),
        confidenceByCue =
            Map.unmodifiable(confidenceByCue ?? const <SoundCue, double>{}),
        super(metadata);

  AudioEnvironmentSignal.unavailable({
    required String providerId,
    required SignalUnavailableReason reason,
    required DateTime capturedAt,
    List<String> warnings = const <String>[],
  })  : soundCues = const <SoundCue>{},
        noiseLevel = null,
        confidenceByCue = const <SoundCue, double>{},
        averageSoundLevel = null,
        sampleDuration = Duration.zero,
        sampleWasUsable = false,
        super(SignalMetadata(
          kind: ContextSignalKind.ambientAudio,
          providerId: providerId,
          capturedAt: capturedAt,
          unavailableReason: reason,
          warnings: warnings,
        ));

  final Set<SoundCue> soundCues;

  /// Null means "could not tell", which `NoiseLevel` itself cannot express —
  /// it has four values and none of them is unknown.
  final NoiseLevel? noiseLevel;

  final Map<SoundCue, double> confidenceByCue;

  /// Normalized 0–1 energy. Never shown as a decibel figure to an ordinary
  /// user: a phone microphone is not a calibrated meter.
  final double? averageSoundLevel;

  final Duration sampleDuration;

  /// False for silence, a zero-length buffer or a microphone that returned
  /// nothing usable. Distinct from unavailable: capture happened, but the
  /// result carries no information.
  final bool sampleWasUsable;

  double confidenceOf(SoundCue cue) => confidenceByCue[cue] ?? 0;

  bool hasAny(Set<SoundCue> cues) => soundCues.intersection(cues).isNotEmpty;

  /// The cues above a threshold, strongest first.
  List<SoundCue> strongestCues({double threshold = 0.4}) {
    final strong = soundCues.where((c) => confidenceOf(c) >= threshold).toList()
      ..sort((a, b) => confidenceOf(b).compareTo(confidenceOf(a)));
    return strong;
  }
}

/// Turns sound cues into the app's own vocabulary.
abstract final class SoundCueMapping {
  /// Sound cues that correspond to something the library actually tags.
  ///
  /// Most sound cues map to nothing, and that is correct: hearing a train tells
  /// you about the *place*, not about an observable thing you could compliment.
  /// Only cues that name a real, visible subject become an [ObservableCue].
  static const Map<SoundCue, ObservableCue> _observable =
      <SoundCue, ObservableCue>{
    SoundCue.music: ObservableCue.music,
    SoundCue.loudMusic: ObservableCue.music,
    SoundCue.danceMusic: ObservableCue.music,
    SoundCue.livePerformance: ObservableCue.music,
    SoundCue.clubBass: ObservableCue.music,
    SoundCue.dogBarking: ObservableCue.dog,
    SoundCue.rain: ObservableCue.weather,
    SoundCue.wind: ObservableCue.weather,
    SoundCue.festivalAmbience: ObservableCue.festivalItem,
    SoundCue.gymEquipment: ObservableCue.sportsEquipment,
    SoundCue.boxingBell: ObservableCue.sportsEquipment,
  };

  static ObservableCue? toObservableCue(SoundCue cue) => _observable[cue];

  /// The observable cues a sample supports.
  ///
  /// `groupHavingFun` is deliberately absent from the per-cue map and added
  /// here only when cheering *and* a crowd are both present, because a single
  /// cheer label fires on a television in an empty bar.
  static Set<ObservableCue> toObservableCues(AudioEnvironmentSignal audio) {
    final cues = <ObservableCue>{};
    for (final cue in audio.soundCues) {
      final mapped = _observable[cue];
      if (mapped != null) cues.add(mapped);
    }
    if (audio.soundCues.contains(SoundCue.cheering) &&
        audio.soundCues.contains(SoundCue.crowd)) {
      cues.add(ObservableCue.groupHavingFun);
    }
    return cues;
  }

  /// Location tags a set of sound cues makes more likely, with weights.
  ///
  /// Corroboration only. These weights are deliberately smaller than the
  /// place-evidence weights in the fusion service, because audio cannot
  /// identify a venue: dishes and conversation fit a café, a restaurant, a
  /// canteen and a hotel breakfast room equally well.
  static Map<LocationTag, int> locationAffinities(Set<SoundCue> cues) {
    final scores = <LocationTag, int>{};
    void add(LocationTag tag, int weight) {
      scores[tag] = (scores[tag] ?? 0) + weight;
    }

    // Transit. A station and a train interior share most of their sounds, so
    // neither gets a decisive weight from audio alone; speed separates them.
    for (final cue in cues) {
      switch (cue) {
        case SoundCue.train:
        case SoundCue.railTransport:
        case SoundCue.subwayOrMetro:
          add(LocationTag.trainStation, 18);
          add(LocationTag.publicTransport, 14);
        case SoundCue.publicAddressAnnouncement:
          add(LocationTag.trainStation, 16);
          add(LocationTag.publicTransport, 10);
        case SoundCue.trainWheels:
          // Heard from inside far more than from a platform.
          add(LocationTag.publicTransport, 20);
          add(LocationTag.trainStation, 6);
        case SoundCue.doorChime:
          add(LocationTag.publicTransport, 14);
          add(LocationTag.trainStation, 10);
        case SoundCue.trainHorn:
          add(LocationTag.trainStation, 12);
        case SoundCue.vehicleInterior:
        case SoundCue.bus:
          add(LocationTag.publicTransport, 16);
        case SoundCue.traffic:
        case SoundCue.roadTraffic:
          add(LocationTag.street, 16);
        case SoundCue.aircraft:
          add(LocationTag.publicTransport, 6);

        // Food and drink.
        case SoundCue.dishes:
        case SoundCue.cutlery:
          add(LocationTag.restaurant, 14);
          add(LocationTag.cafe, 10);
        case SoundCue.cupsOrGlasses:
          add(LocationTag.cafe, 12);
          add(LocationTag.bar, 8);
        case SoundCue.coffeeMachine:
          add(LocationTag.cafe, 18);
        case SoundCue.restaurantAmbience:
          add(LocationTag.restaurant, 14);
          add(LocationTag.cafe, 8);
        case SoundCue.indoorConversation:
          // Almost every indoor venue. Weak on purpose.
          add(LocationTag.cafe, 5);
          add(LocationTag.restaurant, 5);
          add(LocationTag.bar, 4);

        // Nightlife.
        case SoundCue.loudMusic:
        case SoundCue.danceMusic:
        case SoundCue.clubBass:
          add(LocationTag.club, 18);
          add(LocationTag.bar, 10);
          add(LocationTag.concert, 8);
        case SoundCue.music:
          add(LocationTag.bar, 6);
          add(LocationTag.cafe, 4);
        case SoundCue.crowd:
          add(LocationTag.bar, 8);
          add(LocationTag.festival, 8);
          add(LocationTag.concert, 6);
        case SoundCue.cheering:
        case SoundCue.applause:
          add(LocationTag.concert, 14);
          add(LocationTag.festival, 8);
        case SoundCue.livePerformance:
          add(LocationTag.concert, 18);
        case SoundCue.festivalAmbience:
          add(LocationTag.festival, 18);

        // Fitness.
        case SoundCue.gymEquipment:
        case SoundCue.exerciseAmbience:
          add(LocationTag.gym, 18);
        case SoundCue.boxingBell:
        case SoundCue.strikingSounds:
          add(LocationTag.kickboxingClass, 18);
          add(LocationTag.gym, 8);
        case SoundCue.impactSounds:
          add(LocationTag.gym, 8);
        case SoundCue.sportsCrowd:
          add(LocationTag.concert, 6);

        // Outdoors.
        case SoundCue.birds:
          add(LocationTag.park, 16);
        case SoundCue.wind:
          add(LocationTag.park, 6);
          add(LocationTag.waterfront, 6);
        case SoundCue.water:
        case SoundCue.waves:
          add(LocationTag.waterfront, 18);
        case SoundCue.rain:
          add(LocationTag.street, 4);
        case SoundCue.dogBarking:
          add(LocationTag.park, 10);
          add(LocationTag.street, 4);

        // Carry no location information at all.
        case SoundCue.quiet:
        case SoundCue.speechPresent:
        case SoundCue.crowdedSpeech:
        case SoundCue.mechanicalAmbience:
        case SoundCue.unknown:
          break;
      }
    }
    return scores;
  }

  /// Derives a noise level from energy and the cues present.
  ///
  /// Energy leads, because it is the more direct measurement; cues only pull
  /// the answer when the level is borderline. Returns null rather than
  /// guessing when the sample was unusable.
  static NoiseLevel? noiseLevelFrom({
    required double? averageSoundLevel,
    required Set<SoundCue> cues,
    required bool sampleWasUsable,
  }) {
    if (!sampleWasUsable) return null;
    if (averageSoundLevel == null) {
      // No energy figure, but strong cues can still separate loud from quiet.
      if (cues.contains(SoundCue.loudMusic) ||
          cues.contains(SoundCue.clubBass)) {
        return NoiseLevel.veryLoud;
      }
      if (cues.contains(SoundCue.quiet)) return NoiseLevel.quiet;
      return null;
    }

    var level = switch (averageSoundLevel) {
      < 0.15 => NoiseLevel.quiet,
      < 0.45 => NoiseLevel.normal,
      < 0.75 => NoiseLevel.loud,
      _ => NoiseLevel.veryLoud,
    };

    // A club or a concert is louder than a phone microphone can represent,
    // because the input clips. One step up, never more.
    if ((cues.contains(SoundCue.clubBass) ||
            cues.contains(SoundCue.loudMusic)) &&
        level == NoiseLevel.loud) {
      level = NoiseLevel.veryLoud;
    }
    return level;
  }

  /// Confidence in a sample.
  static FieldConfidence confidenceFor(AudioEnvironmentSignal audio) {
    if (!audio.isUsable || !audio.sampleWasUsable) {
      return const FieldConfidence(ConfidenceLevel.unknown);
    }
    final strong = audio.strongestCues();
    if (strong.isEmpty) return const FieldConfidence(ConfidenceLevel.low);

    // Only ever medium at best. A general environmental audio model is
    // corroborating evidence; treating it as high confidence would let a
    // single label override a good GPS fix, which the brief forbids and which
    // would be wrong anyway.
    final best = audio.confidenceOf(strong.first);
    if (best >= 0.7 && strong.length >= 2) {
      return const FieldConfidence(ConfidenceLevel.medium);
    }
    if (best >= 0.5) return const FieldConfidence(ConfidenceLevel.low);
    return const FieldConfidence(ConfidenceLevel.low);
  }
}
