import '../enums/enums.dart';
import 'confidence.dart';
import 'person_presence.dart';
import 'venue_category.dart';

/// Where a set of frames came from.
enum FrameSourceKind {
  phoneCamera,
  importedImage,

  /// Reserved. See docs/SMART_GLASSES_INTEGRATION.md. No implementation ships.
  smartGlasses,

  /// Frames supplied by a test.
  fake,
}

/// One captured frame, held only long enough to analyse it.
///
/// [bytes] is the encoded image. It is deliberately not stored anywhere and is
/// dropped as soon as the analyser returns; [ScanSession] is what enforces
/// that. [temporaryPath], when set, is a file the pipeline is responsible for
/// deleting.
class CapturedFrame {
  const CapturedFrame({
    required this.bytes,
    this.temporaryPath,
    this.width = 0,
    this.height = 0,
    this.rotationDegrees = 0,
  });

  final List<int> bytes;

  /// A file on disk that must be deleted after processing, if any.
  final String? temporaryPath;

  final int width;
  final int height;
  final int rotationDegrees;

  int get byteCount => bytes.length;
}

/// The frames from one press of Scan.
class CapturedFrameSet {
  const CapturedFrameSet({
    required this.frames,
    required this.source,
    required this.capturedAt,
  });

  final List<CapturedFrame> frames;
  final FrameSourceKind source;
  final DateTime capturedAt;

  bool get isEmpty => frames.isEmpty;

  /// Every temporary file this set is responsible for cleaning up.
  List<String> get temporaryPaths => frames
      .map((f) => f.temporaryPath)
      .whereType<String>()
      .toList(growable: false);
}

/// Supplies image frames to the analysis pipeline.
///
/// The pipeline knows nothing about cameras. It asks for frames and gets
/// bytes. That is the whole seam: a phone camera, an image the user picked
/// from storage, a test fixture, or one day a pair of glasses handing over
/// JPEG bytes, all satisfy it identically.
///
/// See docs/SMART_GLASSES_INTEGRATION.md for how a future glasses adapter
/// would implement this without any change below this interface.
abstract interface class ImageFrameSource {
  /// A short identifier used in diagnostics.
  String get id;

  FrameSourceKind get kind;

  /// Whether frames can be captured right now.
  Future<bool> isAvailable();

  /// Captures frames. Called only in response to a deliberate user action.
  Future<CapturedFrameSet> captureFrames();

  /// Releases any hardware or buffers held.
  Future<void> dispose();
}

/// A structured, neutral description of a *place*, derived from image labels.
///
/// This is the intermediate model. Raw analyser output never reaches the
/// recommendation UI: it is normalised into this, then confirmed by the user,
/// and only then mapped to a ContextSnapshot.
///
/// It describes a setting, including how many people are coarsely in it.
///
/// The rule, in full:
///
/// > OpenCue may detect coarse, anonymous human presence and group size as
/// > part of environmental context, but it must never identify, profile or
/// > persist information about particular individuals.
///
/// So [personPresence] carries a bucket — nobody, one, two, small group,
/// large group, unknown — and a confidence, and nothing else. There is no
/// identity, no face data, no demographics, no expression, no tracking across
/// frames or scans, and no assessment of anyone's interest or availability.
/// Group size exists because it changes which *wording* fits: a line aimed at
/// one person talks past their friend, and the library has a whole category
/// written to address both people instead.
class EnvironmentalObservation {
  EnvironmentalObservation({
    required this.id,
    required this.capturedAt,
    required this.source,
    this.detectedLabels = const <ScoredLabel>[],
    this.location = const Inferred<LocationTag>.unknown(),
    this.activity = const Inferred<ActivityTag>.unknown(),
    this.noiseLevel = const Inferred<NoiseLevel>.unknown(),
    this.observableCues = const <ObservableCue, FieldConfidence>{},
    this.personPresence = PersonPresence.unknown,
    this.venue = const VenueGuess.unknown(),
    this.warnings = const <String>[],
    this.processingDuration = Duration.zero,
    this.frameCount = 0,
    this.modelInformation = '',
  });

  final String id;
  final DateTime capturedAt;
  final FrameSourceKind source;

  /// The raw labels, kept for the diagnostics screen and merge logic.
  final List<ScoredLabel> detectedLabels;

  final Inferred<LocationTag> location;
  final Inferred<ActivityTag> activity;
  final Inferred<NoiseLevel> noiseLevel;

  /// Cues with enough evidence to mention, each with its own confidence.
  final Map<ObservableCue, FieldConfidence> observableCues;

  /// Coarse, anonymous group size. Never an identity, never a description.
  final PersonPresence personPresence;

  /// Venue category and subtype, kept separate from the engine's LocationTag
  /// so that "which station" and "is this a station" can fail independently.
  final VenueGuess venue;

  /// Localisation keys describing anything the user should know.
  final List<String> warnings;

  final Duration processingDuration;
  final int frameCount;
  final String modelInformation;

  /// Always true. Kept as a field so the contract is explicit and so no future
  /// caller can look for a way to skip confirmation.
  bool get requiresUserConfirmation => true;

  /// Cues confident enough to tick on the confirmation screen.
  Set<ObservableCue> get preselectedCues => observableCues.entries
      .where((e) => e.value.level.mayPreselect)
      .map((e) => e.key)
      .toSet();

  /// Cues worth offering but not ticking.
  Set<ObservableCue> get suggestedCues => observableCues.entries
      .where((e) => e.value.level == ConfidenceLevel.low)
      .map((e) => e.key)
      .toSet();

  /// True when nothing usable came back, so the UI can say so plainly.
  bool get isInconclusive =>
      location.value == null &&
      activity.value == null &&
      observableCues.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'source': source.name,
        'detectedLabels': detectedLabels.map((l) => l.toJson()).toList(),
        'location': location.value?.name,
        'locationConfidence': location.confidence.toJson(),
        'activity': activity.value?.name,
        'activityConfidence': activity.confidence.toJson(),
        'noiseLevel': noiseLevel.value?.name,
        'noiseLevelConfidence': noiseLevel.confidence.toJson(),
        'observableCues': observableCues.map(
          (cue, confidence) => MapEntry(cue.name, confidence.toJson()),
        ),
        'personPresence': personPresence.toJson(),
        'venue': venue.toJson(),
        'warnings': warnings,
        'processingMs': processingDuration.inMilliseconds,
        'frameCount': frameCount,
        'modelInformation': modelInformation,
      };

  static EnvironmentalObservation fromJson(Map<String, Object?> json) {
    final rawCues = json['observableCues'];
    final cues = <ObservableCue, FieldConfidence>{};
    if (rawCues is Map) {
      rawCues.forEach((key, value) {
        final cue = enumFromName(ObservableCue.values, key);
        if (cue != null && value is Map) {
          cues[cue] = FieldConfidence.fromJson(
            value.cast<String, Object?>(),
          );
        }
      });
    }
    final rawLabels = json['detectedLabels'];
    final rawWarnings = json['warnings'];
    return EnvironmentalObservation(
      id: json['id'] as String? ?? '',
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      source: enumFromNameOr(
        FrameSourceKind.values,
        json['source'],
        FrameSourceKind.fake,
      ),
      detectedLabels: rawLabels is List
          ? rawLabels
              .whereType<Map<Object?, Object?>>()
              .map((m) => ScoredLabel.fromJson(m.cast<String, Object?>()))
              .toList()
          : const <ScoredLabel>[],
      location: Inferred<LocationTag>(
        enumFromName(LocationTag.values, json['location']),
        _confidence(json['locationConfidence']),
      ),
      activity: Inferred<ActivityTag>(
        enumFromName(ActivityTag.values, json['activity']),
        _confidence(json['activityConfidence']),
      ),
      noiseLevel: Inferred<NoiseLevel>(
        enumFromName(NoiseLevel.values, json['noiseLevel']),
        _confidence(json['noiseLevelConfidence']),
      ),
      observableCues: cues,
      personPresence: json['personPresence'] is Map
          ? PersonPresence.fromJson(
              (json['personPresence']! as Map).cast<String, Object?>(),
            )
          : PersonPresence.unknown,
      venue: json['venue'] is Map
          ? VenueGuess.fromJson(
              (json['venue']! as Map).cast<String, Object?>(),
            )
          : const VenueGuess.unknown(),
      warnings: rawWarnings is List
          ? rawWarnings.whereType<String>().toList()
          : const <String>[],
      processingDuration:
          Duration(milliseconds: json['processingMs'] as int? ?? 0),
      frameCount: json['frameCount'] as int? ?? 0,
      modelInformation: json['modelInformation'] as String? ?? '',
    );
  }

  static FieldConfidence _confidence(Object? raw) => raw is Map
      ? FieldConfidence.fromJson(raw.cast<String, Object?>())
      : FieldConfidence.unknown;
}

/// One label returned by the image analyser.
class ScoredLabel {
  const ScoredLabel(this.text, this.confidence, {this.frameIndex = 0});

  /// The label as the model produced it, lower-cased by the analyser.
  final String text;

  /// The model's own 0..1 confidence.
  final double confidence;

  final int frameIndex;

  Map<String, Object?> toJson() => <String, Object?>{
        'text': text,
        'confidence': confidence,
        'frameIndex': frameIndex,
      };

  static ScoredLabel fromJson(Map<String, Object?> json) => ScoredLabel(
        json['text'] as String? ?? '',
        (json['confidence'] as num?)?.toDouble() ?? 0,
        frameIndex: json['frameIndex'] as int? ?? 0,
      );

  @override
  String toString() => '$text=${confidence.toStringAsFixed(2)}';
}
