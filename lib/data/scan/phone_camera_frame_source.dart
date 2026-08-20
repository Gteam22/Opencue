import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/scan/environmental_observation.dart';

/// Captures frames from the device's rear camera.
///
/// Rear by default because this is an environmental scan: the point is what is
/// around you, not you. The front camera is reachable only through an explicit
/// switch control.
///
/// The preview runs continuously once started, but nothing is analysed until
/// [captureFrames] is called, which only happens when the user taps Scan.
/// There is no frame-stream analysis in this release and no background use.
class PhoneCameraFrameSource implements ImageFrameSource {
  PhoneCameraFrameSource({this.burstSize = 3, this.burstGap = const Duration(
    milliseconds: 350,
  )});

  /// Up to three frames over roughly one second, merged by consensus. This is
  /// what stops a single misread frame deciding the result.
  final int burstSize;
  final Duration burstGap;

  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIndex = 0;

  /// The live controller, for the preview widget. Null until [start].
  CameraController? get controller => _controller;

  bool get isReady => _controller?.value.isInitialized ?? false;

  /// Whether a second camera exists to switch to.
  bool get canSwitchCamera => _cameras.length > 1;

  bool get supportsFlash => _cameras.isNotEmpty;

  @override
  String get id => 'phoneCamera';

  @override
  FrameSourceKind get kind => FrameSourceKind.phoneCamera;

  @override
  Future<bool> isAvailable() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      return _cameras.isNotEmpty;
    } on CameraException {
      return false;
    }
  }

  /// Opens the preview. Call from the scan screen once permission is granted.
  Future<void> start() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    if (_cameras.isEmpty) {
      throw CameraException('noCamera', 'No camera on this device');
    }
    // Prefer the rear camera explicitly rather than trusting list order.
    final rear = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _cameraIndex = rear >= 0 ? rear : 0;
    await _open(_cameraIndex);
  }

  Future<void> _open(int index) async {
    await _controller?.dispose();
    final controller = CameraController(
      _cameras[index],
      // Medium is plenty for label recognition and keeps capture fast; higher
      // resolutions cost time and memory for no accuracy gain here.
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    _controller = controller;
  }

  /// Switches to the next camera. Explicit user action only.
  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _open(_cameraIndex);
  }

  Future<void> setFlash(bool on) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } on CameraException {
      // Not every device has a torch. Silently leaving it off is correct.
    }
  }

  /// Releases the camera. Called when the screen is closed or backgrounded.
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Future<CapturedFrameSet> captureFrames() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw CameraException('notReady', 'Camera is not initialised');
    }

    final directory = await _scanTempDirectory();
    final frames = <CapturedFrame>[];

    for (var i = 0; i < burstSize; i++) {
      final shot = await controller.takePicture();
      // takePicture writes to a plugin-chosen temporary path. It is moved into
      // our own scan directory so that cleanup has one place to look and so
      // nothing is left in a location the plugin might reuse.
      final target = p.join(
        directory.path,
        'scan-${DateTime.now().microsecondsSinceEpoch}-$i.jpg',
      );
      final file = await File(shot.path).copy(target);
      try {
        await File(shot.path).delete();
      } on Object {
        // The copy is what matters; the original is reported by the service
        // if it survives.
      }

      frames.add(
        CapturedFrame(
          bytes: const <int>[],
          // Declared so EnvironmentalScanService deletes it, on every path.
          temporaryPath: file.path,
          width: controller.value.previewSize?.width.round() ?? 0,
          height: controller.value.previewSize?.height.round() ?? 0,
          rotationDegrees: controller.description.sensorOrientation,
        ),
      );

      if (i < burstSize - 1) {
        await Future<void>.delayed(burstGap);
      }
    }

    return CapturedFrameSet(
      frames: frames,
      source: FrameSourceKind.phoneCamera,
      capturedAt: DateTime.now().toUtc(),
    );
  }

  /// App-private scratch space. Not the gallery, not shared storage.
  static Future<Directory> _scanTempDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'opencue-scan'));
    return dir.create(recursive: true);
  }

  /// Removes anything a previous crash may have left behind.
  ///
  /// Belt and braces: the service deletes frames on every path, but a process
  /// killed mid-scan cannot run that code, so the directory is swept on start.
  static Future<int> sweepOrphans() async {
    try {
      final dir = await _scanTempDirectory();
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
          removed++;
        }
      }
      return removed;
    } on Object {
      return 0;
    }
  }

  @override
  Future<void> dispose() => stop();
}
