// Geometry tests for the radial menu.
//
// Everything here is arithmetic on `RadialGeometry` and `RadialPlacement`,
// which is why the geometry lives in `lib/domain` with no Flutter import: a
// wrong wedge boundary is a unit-test failure, not a thing to notice on a
// phone.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/context/radial_geometry.dart';

void main() {
  const eightSectors = RadialGeometry(sectorCount: 8);

  group('angle convention', () {
    test('twelve o\'clock is angle zero', () {
      expect(angleOf(0, -10), closeTo(0, 1e-9));
    });

    test('three, six and nine o\'clock, clockwise', () {
      expect(angleOf(10, 0), closeTo(math.pi / 2, 1e-9));
      expect(angleOf(0, 10), closeTo(math.pi, 1e-9));
      expect(angleOf(-10, 0), closeTo(3 * math.pi / 2, 1e-9));
    });

    test('normaliseAngle wraps into [0, 2π)', () {
      expect(normaliseAngle(-math.pi / 2), closeTo(3 * math.pi / 2, 1e-9));
      expect(normaliseAngle(2 * math.pi), closeTo(0, 1e-9));
      expect(normaliseAngle(5 * math.pi), closeTo(math.pi, 1e-9));
    });
  });

  group('sector selection at representative angles', () {
    test('centre of each sector maps to its own index', () {
      for (var i = 0; i < 8; i++) {
        final angle = eightSectors.centreAngleOf(i);
        expect(eightSectors.sectorAt(angle), i, reason: 'sector $i');
      }
    });

    test('a boundary belongs to the higher-index sector', () {
      // The start angle of sector 3 is the boundary between 2 and 3.
      final boundary = eightSectors.startAngleOf(3);
      expect(eightSectors.sectorAt(boundary), 3);
    });

    test('the wrap-around boundary belongs to sector 0', () {
      expect(eightSectors.sectorAt(0), 0);
      expect(eightSectors.sectorAt(2 * math.pi - 1e-9), 7);
    });

    test('hit-testing is total over the full circle', () {
      // 720 samples: every angle lands in exactly one sector.
      for (var step = 0; step < 720; step++) {
        final angle = step * math.pi / 360;
        final index = eightSectors.sectorAt(normaliseAngle(angle));
        expect(index, inInclusiveRange(0, 7));
      }
    });

    test('one sector still hit-tests correctly', () {
      const single = RadialGeometry(sectorCount: 1);
      expect(single.sectorAt(0.1), 0);
      expect(single.sectorAt(5.9), 0);
    });
  });

  group('zones', () {
    test('inside the dead zone cancels regardless of angle', () {
      for (final angle in <double>[0, 1, 2, 3, 4, 5, 6]) {
        final dx = 20 * math.sin(angle);
        final dy = -20 * math.cos(angle);
        final hit = eightSectors.hitTest(dx, dy);
        expect(hit.zone, RadialZone.deadZone);
        expect(hit.selectsSomething, isFalse);
      }
    });

    test('the ring band selects a sector', () {
      final hit = eightSectors.hitTest(0, -100); // straight up, radius 100
      expect(hit.zone, RadialZone.ring);
      expect(hit.index, 0);
      expect(hit.selectsSomething, isTrue);
    });

    test('outer band is dead space until the child layer opens', () {
      final closed = eightSectors.hitTest(0, -160);
      expect(closed.zone, RadialZone.beyond);
      final open = eightSectors.hitTest(0, -160, childLayerOpen: true);
      expect(open.zone, RadialZone.childRing);
      expect(open.index, 0);
    });

    test('beyond everything still points at the sector underneath', () {
      // A fast flick can overshoot; that must not deselect.
      final hit = eightSectors.hitTest(0, -500, childLayerOpen: true);
      expect(hit.zone, RadialZone.beyond);
      expect(hit.index, 0);
      expect(hit.selectsSomething, isTrue);
    });
  });

  group('expand and collapse thresholds', () {
    test('expand threshold sits just inside the outer radius', () {
      expect(eightSectors.crossesExpandThreshold(121), isFalse);
      expect(eightSectors.crossesExpandThreshold(123), isTrue);
      expect(eightSectors.crossesExpandThreshold(140), isTrue);
    });

    test('collapse threshold is well inside expand, so no flapping', () {
      // The band between them is a hysteresis zone in which neither fires.
      const between = 100.0;
      expect(eightSectors.crossesExpandThreshold(between), isFalse);
      expect(eightSectors.crossesCollapseThreshold(between), isFalse);
      expect(eightSectors.crossesCollapseThreshold(70), isTrue);
    });
  });

  group('partial fans', () {
    final upFan = RadialGeometry(
      sectorCount: 4,
      startAngle: normaliseAngle(-math.pi / 2),
      sweep: math.pi,
    );

    test('angles inside the sweep select sectors', () {
      expect(upFan.sectorAt(normaliseAngle(-math.pi / 2 + 0.1)), 0);
      expect(upFan.sectorAt(normaliseAngle(math.pi / 2 - 0.1)), 3);
    });

    test('angles outside the sweep select nothing', () {
      final hit = upFan.hitTest(0, 100); // straight down, behind the fan
      expect(hit.index, -1);
      expect(hit.zone, RadialZone.beyond);
      expect(hit.selectsSomething, isFalse);
    });
  });

  group('edge-aware placement', () {
    test('a comfortable centre is left where it was', () {
      final placement = RadialPlacement.solve(
        requestedX: 400,
        requestedY: 400,
        width: 800,
        height: 800,
        radius: 220,
      );
      expect(placement.centreX, 400);
      expect(placement.centreY, 400);
      expect(placement.clamped, isFalse);
      expect(placement.isFullCircle, isTrue);
    });

    test('near a corner the ring is nudged inwards, not fanned', () {
      final placement = RadialPlacement.solve(
        requestedX: 760,
        requestedY: 760,
        width: 800,
        height: 800,
        radius: 220,
      );
      expect(placement.centreX, 800 - 220);
      expect(placement.centreY, 800 - 220);
      expect(placement.clamped, isTrue);
      expect(placement.isFullCircle, isTrue);
    });

    test('safe insets are honoured when nudging', () {
      final placement = RadialPlacement.solve(
        requestedX: 0,
        requestedY: 0,
        width: 800,
        height: 800,
        radius: 200,
        safeLeft: 24,
        safeTop: 48,
      );
      expect(placement.centreX, 24 + 200);
      expect(placement.centreY, 48 + 200);
    });

    test('a phone too short for the ring falls back to an upward fan', () {
      // A 380x300 area cannot hold a 220-radius circle vertically.
      final placement = RadialPlacement.solve(
        requestedX: 190,
        requestedY: 280,
        width: 380,
        height: 300,
        radius: 220,
      );
      expect(placement.clamped, isTrue);
      expect(placement.isFullCircle, isFalse);
      expect(placement.sweep, closeTo(math.pi, 1e-9));
      // Fan centred on twelve o'clock: starts a quarter-turn anticlockwise.
      expect(placement.startAngle, closeTo(3 * math.pi / 2, 1e-9));
    });

    test('an area too narrow fans towards the open side', () {
      final nearLeft = RadialPlacement.solve(
        requestedX: 20,
        requestedY: 400,
        width: 300,
        height: 800,
        radius: 220,
      );
      expect(nearLeft.isFullCircle, isFalse);
      // Fan centred on three o'clock, opening rightwards.
      expect(nearLeft.startAngle, closeTo(0, 1e-9));

      final nearRight = RadialPlacement.solve(
        requestedX: 280,
        requestedY: 400,
        width: 300,
        height: 800,
        radius: 220,
      );
      // Fan centred on nine o'clock, opening leftwards.
      expect(nearRight.startAngle, closeTo(math.pi, 1e-9));
    });

    test('handedness rotates a full ring in opposite directions', () {
      RadialPlacement solveWith(RadialHandedness handedness) =>
          RadialPlacement.solve(
            requestedX: 400,
            requestedY: 400,
            width: 800,
            height: 800,
            radius: 220,
            handedness: handedness,
          );
      final auto = solveWith(RadialHandedness.automatic);
      final left = solveWith(RadialHandedness.leftHanded);
      final right = solveWith(RadialHandedness.rightHanded);
      expect(auto.startAngle, 0);
      expect(left.startAngle, closeTo(math.pi / 8, 1e-9));
      expect(right.startAngle, closeTo(2 * math.pi - math.pi / 8, 1e-9));
    });
  });

  group('paging for layers with more than eight options', () {
    test('eight or fewer options fit one page', () {
      expect(radialPageCount(0), 0);
      expect(radialPageCount(1), 1);
      expect(radialPageCount(8), 1);
    });

    test('past eight, each page gives up one sector to "more"', () {
      // 9 options: pages of 7 usable => 2 pages.
      expect(radialPageCount(9), 2);
      expect(radialPageCount(14), 2);
      expect(radialPageCount(15), 3);
    });
  });
}
