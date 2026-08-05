import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/scan/environmental_scan_service.dart';
import '../../data/scan/mlkit_analyzer.dart';
import '../../data/scan/phone_camera_frame_source.dart';
import '../../domain/scan/vision_analyzer.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';
import 'scan_confirmation_screen.dart';

/// What the screen is currently doing.
enum _Stage {
  onboarding,
  requestingPermission,
  permissionDenied,
  permissionDeniedForever,
  starting,
  ready,
  capturing,
  failed,
}

/// The camera scan screen.
///
/// Lifecycle rules this screen is responsible for:
/// - Permission is requested when the user accepts the onboarding, not when
///   the screen opens, and never before they have been told why.
/// - The preview runs only while this screen is visible and in the foreground.
///   Leaving the app releases the camera; returning re-acquires it.
/// - Nothing is analysed until Scan is tapped. The preview itself is never fed
///   to the model.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  _Stage _stage = _Stage.onboarding;
  PhoneCameraFrameSource? _source;
  EnvironmentalScanService? _service;
  ScanFailureReason? _failure;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Anything a previous crash left behind goes now, before we add more.
    PhoneCameraFrameSource.sweepOrphans();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Holding the camera open while the app is not visible is exactly the
    // behaviour this feature must not have.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _source?.stop();
    } else if (state == AppLifecycleState.resumed && _stage == _Stage.ready) {
      _startCamera();
    }
  }

  Future<void> _acceptOnboarding() async {
    setState(() => _stage = _Stage.requestingPermission);
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await _startCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() => _stage = _Stage.permissionDeniedForever);
    } else {
      setState(() => _stage = _Stage.permissionDenied);
    }
  }

  Future<void> _startCamera() async {
    setState(() => _stage = _Stage.starting);
    try {
      final source = _source ?? PhoneCameraFrameSource();
      await source.start();
      if (!mounted) {
        await source.stop();
        return;
      }
      _source = source;
      _service ??= EnvironmentalScanService(
        frameSource: source,
        analyzer: OnDeviceEnvironmentalVisionAnalyzer(),
      );
      setState(() => _stage = _Stage.ready);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.code == 'CameraAccessDenied'
            ? ScanFailureReason.permissionDenied
            : ScanFailureReason.cameraInUse;
        _stage = _Stage.failed;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _failure = ScanFailureReason.cameraUnavailable;
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _scan() async {
    final service = _service;
    if (service == null) return;
    setState(() => _stage = _Stage.capturing);

    final result = await service.scan();
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _failure = result.failure;
        _stage = _Stage.failed;
      });
      return;
    }

    // Release the camera before leaving: the confirmation screen has no use
    // for it and holding it open would be gratuitous.
    await _source?.stop();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanConfirmationScreen(
          observation: result.observation!,
          cleanupReport: result,
        ),
      ),
    );
    if (!mounted) return;
    // Coming back means "scan again".
    await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('scan.title'))),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.onboarding:
        return _Onboarding(onAccept: _acceptOnboarding);
      case _Stage.requestingPermission:
      case _Stage.starting:
        return const Center(child: CircularProgressIndicator());
      case _Stage.permissionDenied:
        return _PermissionState(
          bodyKey: 'scan.permission.denied',
          onRetry: _acceptOnboarding,
        );
      case _Stage.permissionDeniedForever:
        return const _PermissionState(
          bodyKey: 'scan.permission.deniedForever',
          onOpenSettings: openAppSettings,
        );
      case _Stage.failed:
        return _FailureState(
          reason: _failure,
          onRetry: () => setState(() => _stage = _Stage.onboarding),
        );
      case _Stage.ready:
      case _Stage.capturing:
        return _Preview(
          source: _source,
          busy: _stage == _Stage.capturing,
          flashOn: _flashOn,
          onScan: _scan,
          onToggleFlash: () async {
            setState(() => _flashOn = !_flashOn);
            await _source?.setFlash(_flashOn);
          },
          onSwitchCamera: () async {
            await _source?.switchCamera();
            if (mounted) setState(() {});
          },
        );
    }
  }
}

/// Shown before the permission dialog, never after.
class _Onboarding extends StatelessWidget {
  const _Onboarding({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    return ListView(
      children: <Widget>[
        ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.t('scan.onboarding.title'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              for (final key in const <String>[
                'scan.onboarding.whatItDoes',
                'scan.onboarding.pointAtEnvironment',
                'scan.onboarding.ephemeral',
                'scan.onboarding.noPeople',
                'scan.onboarding.canBeWrong',
                'scan.onboarding.photographyRules',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.circle,
                        size: 7,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(strings.t(key))),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAccept,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(strings.t('scan.onboarding.accept')),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(strings.t('scan.cancel')),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.source,
    required this.busy,
    required this.flashOn,
    required this.onScan,
    required this.onToggleFlash,
    required this.onSwitchCamera,
  });

  final PhoneCameraFrameSource? source;
  final bool busy;
  final bool flashOn;
  final VoidCallback onScan;
  final VoidCallback onToggleFlash;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final controller = source?.controller;

    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (controller != null && controller.value.isInitialized)
                CameraPreview(controller)
              else
                const ColoredBox(color: Colors.black),
              if (busy)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          strings.t('scan.processing'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Chip(strings.t('scan.notCapturedYet')),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Text(
                strings.t('scan.pointAtRoom'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: flashOn
                        ? strings.t('scan.flashOff')
                        : strings.t('scan.flashOn'),
                    onPressed: busy ? null : onToggleFlash,
                    icon: Icon(flashOn ? Icons.flash_on : Icons.flash_off),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onScan,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(strings.t('scan.button')),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.t('scan.switchCamera'),
                    onPressed:
                        busy || !(source?.canSwitchCamera ?? false)
                            ? null
                            : onSwitchCamera,
                    icon: const Icon(Icons.cameraswitch_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({
    required this.bodyKey,
    this.onRetry,
    this.onOpenSettings,
  });

  final String bodyKey;
  final VoidCallback? onRetry;
  final Future<bool> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return EmptyState(
      icon: Icons.no_photography_outlined,
      title: strings.t('scan.permission.title'),
      hint: strings.t(bodyKey),
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: <Widget>[
          if (onRetry != null)
            FilledButton(
              onPressed: onRetry,
              child: Text(strings.t('scan.permission.grant')),
            ),
          if (onOpenSettings != null)
            FilledButton(
              onPressed: () => onOpenSettings!(),
              child: Text(strings.t('scan.permission.openSettings')),
            ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.t('scan.enterManuallyInstead')),
          ),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.reason, required this.onRetry});

  final ScanFailureReason? reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final key = ScanResult.failure(
      reason ?? ScanFailureReason.analysisFailed,
    ).messageKey;
    return EmptyState(
      icon: Icons.videocam_off_outlined,
      title: strings.t(key),
      hint: strings.t('scan.pointAtRoom'),
      action: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: <Widget>[
          FilledButton(
            onPressed: onRetry,
            child: Text(strings.t('scan.error.retry')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.t('scan.enterManuallyInstead')),
          ),
        ],
      ),
    );
  }
}
