# Smart-glasses integration

**Nothing in this document is implemented.** There is no glasses code in the
repository, no vendor SDK, no Bluetooth permission and no networking
dependency. This exists so that a future adapter has a defined contract to
satisfy, and so that the constraints are written down before anyone builds it
rather than after.

## The seam

The analysis pipeline never touches a camera. It asks an `ImageFrameSource`
for frames and gets bytes back:

```dart
abstract interface class ImageFrameSource {
  String get id;
  FrameSourceKind get kind;
  Future<bool> isAvailable();
  Future<CapturedFrameSet> captureFrames();
  Future<void> dispose();
}
```

That is the entire integration surface. A glasses adapter implements this
interface and nothing below it changes: not `ObservationNormalizer`, not
`ScanHeuristics`, not `ContextSnapshotMapper`, not the recommendation engine,
not any screen. `FrameSourceKind.smartGlasses` already exists and
`ContextSource.smartGlasses` already round-trips through the database and the
JSON export, so records written by such a version stay readable by this one.

```dart
class SmartGlassesFrameSource implements ImageFrameSource {
  @override
  FrameSourceKind get kind => FrameSourceKind.smartGlasses;

  @override
  Future<CapturedFrameSet> captureFrames() async {
    // Obtain encoded frames from the device by whichever transport applies,
    // wrap each in CapturedFrame, and return them tagged with this kind.
  }
}
```

## What the adapter must provide

`CapturedFrame` wants encoded image bytes — JPEG is the expected format —
plus optional dimensions and rotation for the diagnostics screen. Up to three
frames per capture; one is acceptable.

If the transport writes to disk, set `temporaryPath` on each frame. The
pipeline deletes every path in `CapturedFrameSet.temporaryPaths` after
analysis, on both the success and the failure path. An adapter that hands over
a file without declaring it in `temporaryPath` has created a leak the pipeline
cannot clean up.

## Possible transports

None of these is chosen, and each has consequences worth thinking about before
picking one.

| Transport | Notes |
| --- | --- |
| Bluetooth command triggering the glasses camera | Lowest bandwidth; expect seconds per frame, and a permission the app does not currently request. |
| Wi-Fi Direct or local network transfer | Fast enough for a burst. Frames cross a network boundary, so they must not leave the local link. |
| Vendor SDK | Simplest if it exists, but couples the app to one manufacturer and to whatever that SDK does with the frames. |
| Android companion device service | Standard pairing UX; requires a companion-device profile and its own permission. |
| Shared local file or content URI | Trivial to implement. The file is visible to whatever wrote it, so treat it as untrusted and delete it promptly. |
| Raw JPEG byte stream | Maps most directly onto `CapturedFrame`. |
| WebSocket while the app is visible | Workable, but must be torn down the moment the app leaves the foreground. |

## Constraints a future adapter must not relax

These are not stylistic preferences. They are the reason the current scan
feature is defensible, and glasses make each of them harder rather than easier.

**Capture happens only on a deliberate user action.** A button, a touch
control, or an explicit voice command. Not on a timer, not on motion, not
"whenever the glasses see a face", not continuously with the app deciding which
frames are interesting. The current implementation starts model processing only
after the user taps Scan, and the preview itself is not analysed; a glasses
adapter must preserve that.

**Capture must remain perceptible to people nearby.** This is the constraint
glasses genuinely threaten. A phone held up to photograph a room is visible to
everyone in it; that visibility is most of what makes the current feature
socially and legally survivable. Head-worn cameras remove it. Any adapter
should keep whatever recording indicator the hardware provides, and must not
suppress, dim or work around it. If a device offers a "discreet" capture mode,
that mode is out of scope for this application.

**Frames stay ephemeral and local.** Analysed on-device, deleted immediately,
never uploaded, never written to shared storage, never attached to an export.
A network transport moves bytes between two devices the user owns; it does not
license sending them anywhere else.

**Coarse presence only, never identity.** The pipeline reads places, plus a
bucket for how many people are roughly present — nobody, one, two, small group,
large group, unknown. It does not identify, describe, profile or track anyone.
`ScanHeuristics.neverInferred` blocks the cues that would amount to judging a
particular person, and `PersonPresence` carries no identifier of any kind, by
construction, so no detection can be matched to another frame or another scan.

A glasses adapter supplies frames. It does not get to add fields to
`EnvironmentalObservation`, and it must not pre-process frames to extract
anything about the people in them beyond a generic count.

**Legal exposure is worse, not the same.** Covert photography in public is
prosecuted in Japan under prefectural nuisance ordinances, and the app's
primary users are in Japan. A phone pointed at a room is defensible; a camera
worn on the face in a bar or on a station platform is much harder to explain,
and in some venues is prohibited outright regardless of intent. Anyone building
this should get advice specific to the jurisdiction before shipping it, not
after.

## Testing

`ImageFrameSource` is an interface precisely so that none of this requires
hardware to test. `FakeFrameSource` returns fixture bytes and is what the unit
and widget tests use. A glasses adapter should ship with a fake alongside it so
its behaviour under a dropped connection, a partial transfer and a timeout is
covered without pairing anything.
