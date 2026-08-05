import '../context/radial_geometry.dart';
import '../enums/enums.dart';

/// User preferences. Stored locally in the `settings` key/value table.
class AppSettings {
  const AppSettings({
    this.languageMode = LanguageMode.bilingual,
    this.themePreference = AppThemePreference.system,
    this.defaultDirectness = 2,
    this.includeHistoryInExport = false,
    this.developerMode = false,
    this.retainScanImages = false,
    this.radialHandedness = RadialHandedness.automatic,
    this.radialHapticsEnabled = true,
    this.radialTutorialSeen = false,
  });

  final LanguageMode languageMode;
  final AppThemePreference themePreference;

  /// Pre-selected directness on the situation builder.
  final int defaultDirectness;

  /// Whether an export includes interaction history. Off by default: notes are
  /// the most sensitive thing in the database, so including them is a
  /// deliberate choice rather than the default.
  final bool includeHistoryInExport;

  /// Unlocks the scan diagnostics screen. Off by default.
  final bool developerMode;

  /// Keeps captured scan images in app-private storage instead of deleting
  /// them. Off by default, and the settings screen warns before enabling it.
  /// Retained images are excluded from exports.
  final bool retainScanImages;

  /// Which side of the screen the radial menu is optimised for. Automatic
  /// places it by available space; the other two respect a stated preference.
  final RadialHandedness radialHandedness;

  /// Menu haptics. Android only in effect — the widget never calls the
  /// platform channel on Windows — but stored for both so the setting is not
  /// platform-conditional in the database.
  final bool radialHapticsEnabled;

  /// Whether the first-use gesture tutorial has been shown. Replayable from
  /// settings, so this is a "seen" flag rather than a "disabled" one.
  final bool radialTutorialSeen;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    LanguageMode? languageMode,
    AppThemePreference? themePreference,
    int? defaultDirectness,
    bool? includeHistoryInExport,
    bool? developerMode,
    bool? retainScanImages,
    RadialHandedness? radialHandedness,
    bool? radialHapticsEnabled,
    bool? radialTutorialSeen,
  }) {
    return AppSettings(
      languageMode: languageMode ?? this.languageMode,
      themePreference: themePreference ?? this.themePreference,
      defaultDirectness:
          clampDirectness(defaultDirectness ?? this.defaultDirectness),
      includeHistoryInExport:
          includeHistoryInExport ?? this.includeHistoryInExport,
      developerMode: developerMode ?? this.developerMode,
      retainScanImages: retainScanImages ?? this.retainScanImages,
      radialHandedness: radialHandedness ?? this.radialHandedness,
      radialHapticsEnabled:
          radialHapticsEnabled ?? this.radialHapticsEnabled,
      radialTutorialSeen: radialTutorialSeen ?? this.radialTutorialSeen,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'languageMode': languageMode.name,
        'themePreference': themePreference.name,
        'defaultDirectness': defaultDirectness,
        'includeHistoryInExport': includeHistoryInExport,
        'developerMode': developerMode,
        'retainScanImages': retainScanImages,
        'radialHandedness': radialHandedness.name,
        'radialHapticsEnabled': radialHapticsEnabled,
        'radialTutorialSeen': radialTutorialSeen,
      };

  static AppSettings fromJson(Map<String, Object?> json) {
    final raw = json['defaultDirectness'];
    return AppSettings(
      languageMode: enumFromNameOr(
        LanguageMode.values,
        json['languageMode'],
        LanguageMode.bilingual,
      ),
      themePreference: enumFromNameOr(
        AppThemePreference.values,
        json['themePreference'],
        AppThemePreference.system,
      ),
      defaultDirectness:
          clampDirectness(raw is int ? raw : int.tryParse('$raw') ?? 2),
      includeHistoryInExport: json['includeHistoryInExport'] == true,
      developerMode: json['developerMode'] == true,
      retainScanImages: json['retainScanImages'] == true,
      radialHandedness: enumFromNameOr(
        RadialHandedness.values,
        json['radialHandedness'],
        RadialHandedness.automatic,
      ),
      // Absent means "not stated", and the default is on, so this cannot use
      // the `== true` shorthand the other flags use.
      radialHapticsEnabled: json['radialHapticsEnabled'] != false,
      radialTutorialSeen: json['radialTutorialSeen'] == true,
    );
  }

  /// Flat string map for the key/value settings table.
  Map<String, String> toStringMap() => <String, String>{
        'languageMode': languageMode.name,
        'themePreference': themePreference.name,
        'defaultDirectness': '$defaultDirectness',
        'includeHistoryInExport': includeHistoryInExport ? 'true' : 'false',
        'developerMode': developerMode ? 'true' : 'false',
        'retainScanImages': retainScanImages ? 'true' : 'false',
        'radialHandedness': radialHandedness.name,
        'radialHapticsEnabled': radialHapticsEnabled ? 'true' : 'false',
        'radialTutorialSeen': radialTutorialSeen ? 'true' : 'false',
      };

  static AppSettings fromStringMap(Map<String, String> map) {
    return AppSettings(
      languageMode: enumFromNameOr(
        LanguageMode.values,
        map['languageMode'],
        LanguageMode.bilingual,
      ),
      themePreference: enumFromNameOr(
        AppThemePreference.values,
        map['themePreference'],
        AppThemePreference.system,
      ),
      defaultDirectness:
          clampDirectness(int.tryParse(map['defaultDirectness'] ?? '2') ?? 2),
      includeHistoryInExport: map['includeHistoryInExport'] == 'true',
      developerMode: map['developerMode'] == 'true',
      retainScanImages: map['retainScanImages'] == 'true',
      radialHandedness: enumFromNameOr(
        RadialHandedness.values,
        map['radialHandedness'],
        RadialHandedness.automatic,
      ),
      radialHapticsEnabled: map['radialHapticsEnabled'] != 'false',
      radialTutorialSeen: map['radialTutorialSeen'] == 'true',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.languageMode == languageMode &&
      other.themePreference == themePreference &&
      other.defaultDirectness == defaultDirectness &&
      other.includeHistoryInExport == includeHistoryInExport &&
      other.developerMode == developerMode &&
      other.retainScanImages == retainScanImages;

  @override
  int get hashCode => Object.hash(
        languageMode,
        themePreference,
        defaultDirectness,
        includeHistoryInExport,
        developerMode,
        retainScanImages,
      );
}
