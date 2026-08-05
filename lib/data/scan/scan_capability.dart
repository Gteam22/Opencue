import 'dart:io';

/// Whether this build can actually run an environmental scan.
///
/// Capability, not platform name. The home screen asks this rather than
/// `Platform.isAndroid`, so that adding a desktop or iOS implementation later
/// is a change here and nowhere else, and so that an Android device with no
/// usable camera degrades to the manual flow instead of offering a button that
/// cannot work.
class ScanCapability {
  const ScanCapability._();

  /// True when a camera-backed scan implementation exists for this platform.
  ///
  /// The ML Kit packages are Android and iOS only. On Windows the plugin has
  /// no implementation to register, so the analyzer is never constructed and
  /// the scan entry point is hidden rather than shown broken.
  static bool get hasCameraImplementation => Platform.isAndroid;

  /// True when the scan should appear as the primary action.
  ///
  /// Windows keeps its desktop layout with manual entry first.
  static bool get scanIsPrimaryAction => hasCameraImplementation;

  /// Why the scan is unavailable, as a localisation key, or null when it is.
  static String? get unavailableReasonKey =>
      hasCameraImplementation ? null : 'scan.error.unavailable';
}
