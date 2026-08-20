/// Geometry for the radial context menu.
///
/// Deliberately free of Flutter, `dart:ui` and even `Offset`, so that every
/// boundary condition can be tested as arithmetic. The widget layer converts
/// pointer positions into the `(dx, dy)` pairs this file expects, and converts
/// the angles it returns back into paint coordinates.
///
/// ## Angle convention
///
/// Angles are measured **clockwise from twelve o'clock**, in radians, in
/// `[0, 2π)`. Screen coordinates have y increasing downwards, so the
/// conversion from a vector is `atan2(dx, -dy)` rather than the usual
/// `atan2(dy, dx)`. Sector 0 therefore begins at the top and the ring fills
/// clockwise, which is the order the labels read in.
library;

import 'dart:math' as math;


/// Which part of the menu a pointer is over.
enum RadialZone {
  /// Inside the central dead zone. Releasing here cancels; tapping here in
  /// pinned mode triggers the centre action.
  deadZone,

  /// Over a root-layer sector.
  ring,

  /// Over a child-layer sector, further out.
  childRing,

  /// Beyond the outermost ring. Treated as still pointing at the sector
  /// underneath rather than as "nothing", so a fast flick does not fall off
  /// the end of the menu and select nothing.
  beyond,
}

/// The result of hit-testing a pointer position.
class RadialHit {
  const RadialHit({
    required this.zone,
    required this.index,
    required this.angle,
    required this.distance,
  });

  final RadialZone zone;

  /// Index of the sector under the pointer, or -1 in the dead zone.
  final int index;

  /// Clockwise-from-twelve angle of the pointer, in `[0, 2π)`.
  final double angle;

  /// Distance from the menu centre.
  final double distance;

  /// Whether releasing here should select something.
  bool get selectsSomething => index >= 0 && zone != RadialZone.deadZone;

  @override
  String toString() =>
      'RadialHit(${zone.name}, index: $index, '
      'angle: ${angle.toStringAsFixed(3)}, r: ${distance.toStringAsFixed(1)})';
}

/// Normalises any angle into `[0, 2π)`.
double normaliseAngle(double radians) {
  const twoPi = 2 * math.pi;
  var value = radians % twoPi;
  if (value < 0) value += twoPi;
  return value;
}

/// The clockwise-from-twelve angle of the vector `(dx, dy)` in screen
/// coordinates, where y increases downwards.
double angleOf(double dx, double dy) => normaliseAngle(math.atan2(dx, -dy));

/// Radii and angular extent of one ring layout.
///
/// [startAngle] and [sweep] describe a partial fan. A full ring is
/// `startAngle: 0, sweep: 2π`; a menu opened in the bottom-right corner is
/// given a narrower sweep pointing away from the edges so no sector is clipped.
class RadialGeometry {
  const RadialGeometry({
    required this.sectorCount,
    this.deadZoneRadius = 44,
    this.innerRadius = 68,
    this.outerRadius = 124,
    this.childOuterRadius = 196,
    this.startAngle = 0,
    this.sweep = 2 * math.pi,
  })  : assert(sectorCount > 0, 'a ring needs at least one sector'),
        assert(deadZoneRadius > 0, 'the dead zone must be usable'),
        assert(
          innerRadius > deadZoneRadius,
          'ring must start outside the dead zone',
        ),
        assert(outerRadius > innerRadius, 'ring must have thickness'),
        assert(childOuterRadius > outerRadius, 'child ring must sit outside');

  /// How many sectors this ring is divided into.
  final int sectorCount;

  /// Everything inside this radius cancels rather than selects. Generous on
  /// purpose: the brief asks for no precision requirement near the centre.
  final double deadZoneRadius;

  final double innerRadius;
  final double outerRadius;

  /// Outer edge of the child layer, drawn concentrically outside the root ring.
  final double childOuterRadius;

  /// Where sector 0 begins, clockwise from twelve.
  final double startAngle;

  /// Total angular extent covered by all sectors.
  final double sweep;

  /// Whether this layout covers the whole circle.
  bool get isFullCircle => (sweep - 2 * math.pi).abs() < 1e-9;

  // --- Layered bands -------------------------------------------------------
  //
  // Descending a layer does not replace the ring, it steps outward: the active
  // band grows and the layer above it stays visible as a thin trace arc. That
  // is what makes the depth legible during a single continuous drag, and it is
  // why the finger can keep moving outward rather than having to re-aim.
  //
  // The step is small on purpose. Three layers have to fit inside the radius a
  // phone can actually show. On a 380 pt screen with the menu at the bottom
  // centre, a half-fan opening upwards has about 190 pt to work with, so the
  // bands are 68-124, 94-150 and 120-176, and the outermost edge including its
  // shadow lands at 188. A 56 pt band is thick enough for a two-line label,
  // which is the constraint that stops the step being larger.

  /// How much further out each layer sits.
  static const double layerStep = 26;

  /// Inner radius of the band for a layer at [depth], where the root is 0.
  double innerRadiusAt(int depth) => innerRadius + depth * layerStep;

  /// Outer radius of the band for a layer at [depth].
  double outerRadiusAt(int depth) => outerRadius + depth * layerStep;

  /// Radius of the thin trace arc left behind by an ancestor at [depth].
  ///
  /// Sits just inside that layer's own former band, so the trail reads
  /// outward from the centre in the order it was walked.
  double traceRadiusAt(int depth) => innerRadiusAt(depth) - 8;

  /// The outermost radius anything is drawn at, for the placement solver.
  double totalRadiusAt(int depth) => outerRadiusAt(depth) + 12;

  /// Angular width of one sector.
  double get sectorSweep => sweep / sectorCount;

  /// The angle at the centre of sector [index], used to place labels.
  double centreAngleOf(int index) =>
      normaliseAngle(startAngle + (index + 0.5) * sectorSweep);

  /// The angle at which sector [index] begins.
  double startAngleOf(int index) =>
      normaliseAngle(startAngle + index * sectorSweep);

  /// Which sector contains [angle], or -1 if the angle falls outside a partial
  /// fan's sweep.
  ///
  /// The boundary between two sectors belongs to the sector with the higher
  /// index, so hit-testing is total: exactly one sector claims each angle.
  int sectorAt(double angle) {
    final relative = normaliseAngle(angle - startAngle);
    if (!isFullCircle && relative >= sweep) return -1;
    final index = (relative / sectorSweep).floor();
    // Guards the case where floating-point error puts `relative` exactly at
    // `sweep` on a full circle.
    if (index >= sectorCount) return sectorCount - 1;
    return index;
  }

  /// Hit-tests a pointer at `(dx, dy)` relative to the menu centre.
  ///
  /// [depth] is the layer currently showing, so the band the pointer is tested
  /// against moves outward as the user descends.
  RadialHit hitTest(
    double dx,
    double dy, {
    bool childLayerOpen = false,
    int depth = 0,
  }) {
    final distance = math.sqrt(dx * dx + dy * dy);
    final angle = angleOf(dx, dy);
    final bandOuter = outerRadiusAt(depth);

    if (distance <= deadZoneRadius) {
      return RadialHit(
        zone: RadialZone.deadZone,
        index: -1,
        angle: angle,
        distance: distance,
      );
    }

    final index = sectorAt(angle);
    if (index < 0) {
      // Outside a partial fan's sweep. Not a selection, but not a cancel
      // either — the finger has strayed sideways, and the last highlight is
      // kept by the controller.
      return RadialHit(
        zone: RadialZone.beyond,
        index: -1,
        angle: angle,
        distance: distance,
      );
    }

    final RadialZone zone;
    if (distance <= bandOuter) {
      // Anywhere outside the dead zone and inside the active band's outer
      // edge counts as pointing at that sector, including the gap between the
      // dead zone and `bandInner`. Requiring the finger to land inside a thin
      // annulus would be exactly the precision the brief says not to demand.
      zone = RadialZone.ring;
    } else if (childLayerOpen &&
        distance <= outerRadiusAt(depth + 1)) {
      zone = RadialZone.childRing;
    } else {
      zone = RadialZone.beyond;
    }

    return RadialHit(
      zone: zone,
      index: index,
      angle: angle,
      distance: distance,
    );
  }

  /// Whether a pointer at [distance] has crossed the threshold that opens the
  /// next layer. Sits just inside [outerRadius] so the layer opens as the
  /// finger reaches the edge of the sector rather than after leaving it.
  bool crossesExpandThreshold(double distance, {int depth = 0}) =>
      distance >= outerRadiusAt(depth) - _expandSlack;

  /// Whether a pointer at [distance] has been drawn back far enough to close
  /// the child layer. Deliberately well inside [crossesExpandThreshold] so a
  /// small tremor at the boundary does not flap the layer open and shut.
  bool crossesCollapseThreshold(double distance, {int depth = 0}) =>
      distance <= innerRadiusAt(depth) + _collapseSlack;

  static const double _expandSlack = 10;
  static const double _collapseSlack = 6;

  /// How far a fanned menu's centre sits from the safe edge it hugs.
  static const double edgeMargin = 24;

  RadialGeometry copyWith({
    int? sectorCount,
    double? deadZoneRadius,
    double? innerRadius,
    double? outerRadius,
    double? childOuterRadius,
    double? startAngle,
    double? sweep,
  }) {
    return RadialGeometry(
      sectorCount: sectorCount ?? this.sectorCount,
      deadZoneRadius: deadZoneRadius ?? this.deadZoneRadius,
      innerRadius: innerRadius ?? this.innerRadius,
      outerRadius: outerRadius ?? this.outerRadius,
      childOuterRadius: childOuterRadius ?? this.childOuterRadius,
      startAngle: startAngle ?? this.startAngle,
      sweep: sweep ?? this.sweep,
    );
  }
}

/// Which side of the screen the menu is optimised for.
enum RadialHandedness { automatic, leftHanded, rightHanded }

/// Where the menu should be centred, and how wide a fan it may use.
///
/// Returned by [RadialPlacement.solve], which is the whole of the edge-aware
/// positioning logic and is tested directly.
class RadialPlacement {
  const RadialPlacement({
    required this.centreX,
    required this.centreY,
    required this.startAngle,
    required this.sweep,
    required this.clamped,
  });

  final double centreX;
  final double centreY;

  /// Where sector 0 should begin, clockwise from twelve.
  final double startAngle;

  /// How much of the circle the sectors may occupy.
  final double sweep;

  /// True when the requested centre had to be moved, or the ring reduced to a
  /// fan, to keep every sector on screen.
  final bool clamped;

  bool get isFullCircle => (sweep - 2 * math.pi).abs() < 1e-9;

  /// Solves for a centre and sweep that keep a menu of [radius] entirely
  /// within a [width] x [height] area, honouring [safeInsets] on each edge.
  ///
  /// The menu is nudged inwards first, because moving a ring is less
  /// disruptive than reshaping it. Only when the area is genuinely too small
  /// on an axis does it fall back to a fan pointing away from the nearer edge.
  static RadialPlacement solve({
    required double requestedX,
    required double requestedY,
    required double width,
    required double height,
    required double radius,
    double safeLeft = 0,
    double safeTop = 0,
    double safeRight = 0,
    double safeBottom = 0,
    RadialHandedness handedness = RadialHandedness.automatic,
  }) {
    final minX = safeLeft + radius;
    final maxX = width - safeRight - radius;
    final minY = safeTop + radius;
    final maxY = height - safeBottom - radius;

    var clamped = false;
    var centreX = requestedX;
    var centreY = requestedY;

    // Horizontal.
    var fanHorizontally = false;
    var fanOpensRight = true;
    if (minX > maxX) {
      // Not wide enough for a full ring at this radius. A sideways fan needs
      // the radius on one side only, so the centre goes to the edge nearer
      // the finger and the fan opens into the space that is actually there.
      // Centring it would leave the fan clipped on whichever side it opened.
      fanHorizontally = true;
      final middle = (safeLeft + width - safeRight) / 2;
      fanOpensRight = requestedX <= middle;
      centreX = fanOpensRight
          ? safeLeft + RadialGeometry.edgeMargin
          : width - safeRight - RadialGeometry.edgeMargin;
      clamped = true;
    } else if (centreX < minX) {
      centreX = minX;
      clamped = true;
    } else if (centreX > maxX) {
      centreX = maxX;
      clamped = true;
    }

    // Vertical.
    var fanVertically = false;
    if (minY > maxY) {
      // Same reasoning as above, and on a phone this is the common case: the
      // trigger sits near the bottom, so the fan opens upwards from there
      // rather than from the middle of the screen.
      fanVertically = true;
      centreY = height - safeBottom - RadialGeometry.edgeMargin;
      clamped = true;
    } else if (centreY < minY) {
      centreY = minY;
      clamped = true;
    } else if (centreY > maxY) {
      centreY = maxY;
      clamped = true;
    }

    if (!fanHorizontally && !fanVertically) {
      return RadialPlacement(
        centreX: centreX,
        centreY: centreY,
        startAngle: _startAngleForFullRing(handedness),
        sweep: 2 * math.pi,
        clamped: clamped,
      );
    }

    // A half-fan opening away from the constrained edge. Vertical crowding
    // takes precedence: on a phone the trigger sits near the bottom, so an
    // upward fan is the one that matches the thumb.
    //
    // The direction comes from `fanOpensRight`, which was decided from the
    // *requested* position. Reading it back off `centreX` here would be
    // wrong, because `centreX` has since been moved to an edge.
    final double centre;
    if (fanVertically) {
      // Fan upwards: centred on twelve o'clock.
      centre = 0;
    } else {
      // Three o'clock opens rightwards, nine o'clock leftwards.
      centre = fanOpensRight ? math.pi / 2 : 3 * math.pi / 2;
    }
    const fanSweep = math.pi;
    return RadialPlacement(
      centreX: centreX,
      centreY: centreY,
      startAngle: normaliseAngle(centre - fanSweep / 2),
      sweep: fanSweep,
      clamped: true,
    );
  }

  /// Rotates a full ring slightly so the first sectors fall under the thumb.
  ///
  /// A right-handed user's thumb sweeps up and to the left from the
  /// bottom-right, so sector 0 is nudged anticlockwise; a left-handed user's
  /// sweeps the other way.
  static double _startAngleForFullRing(RadialHandedness handedness) {
    switch (handedness) {
      case RadialHandedness.rightHanded:
        return normaliseAngle(-math.pi / 8);
      case RadialHandedness.leftHanded:
        return normaliseAngle(math.pi / 8);
      case RadialHandedness.automatic:
        return 0;
    }
  }
}

/// Splits a list of children into pages of at most [maxPerPage].
///
/// The brief forbids shrinking sectors until labels stop being readable, so a
/// layer with more options than fit is paged rather than subdivided. Eight is
/// the ceiling the brief names.
int radialPageCount(int childCount, {int maxPerPage = 8}) {
  if (childCount <= 0) return 0;
  // With more than one page, one sector on each page is spent on "more", so
  // the usable capacity per page drops by one.
  if (childCount <= maxPerPage) return 1;
  final usable = maxPerPage - 1;
  return (childCount / usable).ceil();
}
