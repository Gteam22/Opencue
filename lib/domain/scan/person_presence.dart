import '../enums/enums.dart';
import 'confidence.dart';

/// One generic `person` detection from a single frame.
///
/// Transient by construction. This type exists only between the detector and
/// [PersonPresence.fromFrames], is never serialized, and never reaches storage
/// or the recommendation engine. What survives is a coarse [GroupSize] and a
/// confidence, and nothing else.
///
/// There is deliberately no identifier on this class. No tracking id, no
/// embedding, no descriptor — nothing that could match a detection in one
/// frame to a detection in another, or in another scan. The box is here only
/// so that overlapping detections within a single frame can be de-duplicated
/// and so that detections sitting on a poster can be suppressed; it is dropped
/// immediately afterwards.
class PersonDetection {
  const PersonDetection({
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double confidence;

  /// Normalised 0..1 box. Transient. Never persisted.
  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get area => width * height;

  /// Intersection-over-union with another box in the same frame.
  double iou(PersonDetection other) {
    final x1 = left > other.left ? left : other.left;
    final y1 = top > other.top ? top : other.top;
    final x2 = right < other.right ? right : other.right;
    final y2 = bottom < other.bottom ? bottom : other.bottom;
    final w = x2 - x1;
    final h = y2 - y1;
    if (w <= 0 || h <= 0) return 0;
    final intersection = w * h;
    return intersection / (area + other.area - intersection);
  }

  /// Whether this box sits inside a flat surface such as a poster or screen.
  bool isInside(PersonDetection surface) {
    final x1 = left > surface.left ? left : surface.left;
    final y1 = top > surface.top ? top : surface.top;
    final x2 = right < surface.right ? right : surface.right;
    final y2 = bottom < surface.bottom ? bottom : surface.bottom;
    final w = x2 - x1;
    final h = y2 - y1;
    if (w <= 0 || h <= 0) return false;
    // Most of the person is within the surface.
    return (w * h) / area >= 0.75;
  }
}

/// Coarse, anonymous group size derived from generic person detections.
///
/// The rule this class implements, in full:
///
/// > OpenCue may detect coarse, anonymous human presence and group size as
/// > part of environmental context, but it must never identify, profile or
/// > persist information about particular individuals.
///
/// So: how many people, roughly. Not who, not what they are like, not whether
/// they want to be spoken to. Group size changes the *wording* a line uses —
/// a line addressed to one person is wrong when two friends are together, and
/// the library has a whole category of lines that address both people
/// precisely so that nobody gets talked past. It is never evidence that an
/// approach is welcome.
class PersonPresence {
  const PersonPresence({
    required this.groupSize,
    required this.confidence,
    this.rawCountPerFrame = const <int>[],
    this.suppressedAsFlatSurface = 0,
    this.deduplicatedWithinFrames = 0,
  });

  static const PersonPresence unknown = PersonPresence(
    groupSize: GroupSize.unknown,
    confidence: FieldConfidence.unknown,
  );

  final GroupSize groupSize;
  final FieldConfidence confidence;

  /// Diagnostics only. Counts, never boxes.
  final List<int> rawCountPerFrame;
  final int suppressedAsFlatSurface;
  final int deduplicatedWithinFrames;

  /// Detections below this are noise and are ignored entirely.
  static const double minimumDetectionConfidence = 0.55;

  /// Two boxes overlapping by more than this in one frame are one person
  /// detected twice.
  static const double duplicateIou = 0.55;

  /// A detection smaller than this fraction of the frame is too far away to
  /// count reliably, and is usually background crowd rather than the
  /// situation the user is in.
  static const double minimumBoxArea = 0.004;

  /// Turns per-frame detections into one coarse answer.
  ///
  /// Frames are combined by **median, not sum**. Summing would multiply the
  /// same two people across three burst frames into six, which is the obvious
  /// way to get this badly wrong. Since nothing is tracked between frames, the
  /// median is the honest estimator: it is what most frames agreed on.
  static PersonPresence fromFrames(
    List<List<PersonDetection>> perFrame, {
    List<List<PersonDetection>> flatSurfacesPerFrame = const [],
    bool imageQualityAdequate = true,
  }) {
    if (!imageQualityAdequate || perFrame.isEmpty) {
      return unknown;
    }

    final counts = <int>[];
    var suppressed = 0;
    var deduplicated = 0;

    for (var index = 0; index < perFrame.length; index++) {
      final surfaces = index < flatSurfacesPerFrame.length
          ? flatSurfacesPerFrame[index]
          : const <PersonDetection>[];

      // 1. Drop weak and tiny detections.
      final candidates = perFrame[index]
          .where((d) => d.confidence >= minimumDetectionConfidence)
          .where((d) => d.area >= minimumBoxArea)
          .toList()
        // Strongest first, so de-duplication keeps the best of a cluster.
        ..sort((a, b) => b.confidence.compareTo(a.confidence));

      // 2. Suppress people printed on posters, billboards and screens. An
      //    advertisement in a station is full of them and none are present.
      final real = <PersonDetection>[];
      for (final candidate in candidates) {
        if (surfaces.any(candidate.isInside)) {
          suppressed++;
          continue;
        }
        real.add(candidate);
      }

      // 3. Collapse boxes that overlap heavily: one person, detected twice.
      final distinct = <PersonDetection>[];
      for (final candidate in real) {
        if (distinct.any((kept) => kept.iou(candidate) >= duplicateIou)) {
          deduplicated++;
          continue;
        }
        distinct.add(candidate);
      }

      counts.add(distinct.length);
    }

    if (counts.isEmpty) return unknown;

    final sorted = <int>[...counts]..sort();
    final median = sorted[sorted.length ~/ 2];
    final spread = sorted.last - sorted.first;

    // Frames that disagree wildly mean the detector is unstable here — a
    // moving crowd, a bad angle. Saying "unknown" is better than picking one.
    if (spread >= 3 || (spread >= 2 && median <= 2)) {
      return PersonPresence(
        groupSize: GroupSize.unknown,
        confidence: const FieldConfidence(ConfidenceLevel.low),
        rawCountPerFrame: counts,
        suppressedAsFlatSurface: suppressed,
        deduplicatedWithinFrames: deduplicated,
      );
    }

    final agreement = counts.where((c) => c == median).length / counts.length;
    final level = spread == 0 && agreement >= 0.99
        ? ConfidenceLevel.high
        : agreement >= 0.6
            ? ConfidenceLevel.medium
            : ConfidenceLevel.low;

    return PersonPresence(
      groupSize: _bucket(median),
      // Exact counts above two are not claimed; the bucket is the answer.
      confidence: FieldConfidence(
        level,
        score: median,
        evidence: <String>['frames:${counts.join("/")}'],
      ),
      rawCountPerFrame: counts,
      suppressedAsFlatSurface: suppressed,
      deduplicatedWithinFrames: deduplicated,
    );
  }

  /// Coarse buckets. Never an exact count above two.
  static GroupSize _bucket(int count) {
    if (count <= 0) return GroupSize.noneVisible;
    if (count == 1) return GroupSize.alone;
    if (count == 2) return GroupSize.withOneFriend;
    if (count <= 5) return GroupSize.smallGroup;
    return GroupSize.largeGroup;
  }

  /// What is safe to store: a bucket and a confidence. No boxes, no counts of
  /// individuals, nothing that could describe anyone.
  Map<String, Object?> toJson() => <String, Object?>{
        'groupSize': groupSize.name,
        'confidence': confidence.level.name,
      };

  static PersonPresence fromJson(Map<String, Object?> json) => PersonPresence(
        groupSize: enumFromNameOr(
          GroupSize.values,
          json['groupSize'],
          GroupSize.unknown,
        ),
        confidence: FieldConfidence(
          enumFromNameOr(
            ConfidenceLevel.values,
            json['confidence'],
            ConfidenceLevel.unknown,
          ),
        ),
      );

  @override
  String toString() => '${groupSize.name}(${confidence.level.name})';
}
