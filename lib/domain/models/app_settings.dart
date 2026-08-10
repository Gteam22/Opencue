import '../context/radial_geometry.dart';
import '../enums/enums.dart';

/// User preferences. Stored locally in the `settings` key/value table.
class AppSettings {
  const AppSettings({
    this.languageMode = LanguageMode.bilingual,
    this.showKoreanRomanization = true,
    this.japaneseTtsEnabled = true,
    this.koreanTtsEnabled = true,
    this.speechRate = SpeechRatePreset.normal,
    this.themePreference = AppThemePreference.system,
    this.defaultDirectness = 2,
    this.includeHistoryInExport = false,
    this.developerMode = false,
    this.retainScanImages = false,
    this.radialHandedness = RadialHandedness.automatic,
    this.radialHapticsEnabled = true,
    this.radialTutorialSeen = false,
    this.conversationLibraryVersion = 0,
  });

  final LanguageMode languageMode;

  /// Whether an easy-to-read Roman reading is shown under each Korean line.
  /// On by default: the audience for Korean lines is likely learning to
  /// pronounce them.
  final bool showKoreanRomanization;

  /// Whether Japanese speak controls are shown on supported platforms.
  final bool japaneseTtsEnabled;

  /// Whether the speak-aloud button appears next to Korean lines. On by
  /// default where the platform supports speech; independent of romanization,
  /// so a user can read the Roman text with the button off, or hear the Korean
  /// with the Roman text hidden.
  final bool koreanTtsEnabled;

  /// How fast a line is read. A named preset, not a raw number, so the setting
  /// stays legible; the presets map to concrete rates in the presentation
  /// layer.
  final SpeechRatePreset speechRate;
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

  /// Internal content-migration marker. Not exposed as a preference.
  final int conversationLibraryVersion;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    LanguageMode? languageMode,
    bool? showKoreanRomanization,
    bool? japaneseTtsEnabled,
    bool? koreanTtsEnabled,
    SpeechRatePreset? speechRate,
    AppThemePreference? themePreference,
    int? defaultDirectness,
    bool? includeHistoryInExport,
    bool? developerMode,
    bool? retainScanImages,
    RadialHandedness? radialHandedness,
    bool? radialHapticsEnabled,
    bool? radialTutorialSeen,
    int? conversationLibraryVersion,
  }) {
    return AppSettings(
      languageMode: languageMode ?? this.languageMode,
      showKoreanRomanization:
          showKoreanRomanization ?? this.showKoreanRomanization,
      japaneseTtsEnabled:
          japaneseTtsEnabled ?? this.japaneseTtsEnabled,
      koreanTtsEnabled: koreanTtsEnabled ?? this.koreanTtsEnabled,
      speechRate: speechRate ?? this.speechRate,
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
      conversationLibraryVersion:
          conversationLibraryVersion ?? this.conversationLibraryVersion,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'languageMode': languageMode.name,
        'showKoreanRomanization': showKoreanRomanization,
        'japaneseTtsEnabled': japaneseTtsEnabled,
        'koreanTtsEnabled': koreanTtsEnabled,
        'speechRate': speechRate.name,
        'themePreference': themePreference.name,
        'defaultDirectness': defaultDirectness,
        'includeHistoryInExport': includeHistoryInExport,
        'developerMode': developerMode,
        'retainScanImages': retainScanImages,
        'radialHandedness': radialHandedness.name,
        'radialHapticsEnabled': radialHapticsEnabled,
        'radialTutorialSeen': radialTutorialSeen,
        'conversationLibraryVersion': conversationLibraryVersion,
      };

  static AppSettings fromJson(Map<String, Object?> json) {
    final raw = json['defaultDirectness'];
    return AppSettings(
      showKoreanRomanization: json['showKoreanRomanization'] != false,
      japaneseTtsEnabled: json['japaneseTtsEnabled'] != false,
      koreanTtsEnabled: json['koreanTtsEnabled'] != false,
      speechRate: enumFromNameOr(
        SpeechRatePreset.values,
        json['speechRate'],
        SpeechRatePreset.normal,
      ),
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
      conversationLibraryVersion:
          _nonNegativeInt(json['conversationLibraryVersion']),
    );
  }

  /// Flat string map for the key/value settings table.
  Map<String, String> toStringMap() => <String, String>{
        'languageMode': languageMode.name,
        'showKoreanRomanization':
            showKoreanRomanization ? 'true' : 'false',
        'japaneseTtsEnabled': japaneseTtsEnabled ? 'true' : 'false',
        'koreanTtsEnabled': koreanTtsEnabled ? 'true' : 'false',
        'speechRate': speechRate.name,
        'themePreference': themePreference.name,
        'defaultDirectness': '$defaultDirectness',
        'includeHistoryInExport': includeHistoryInExport ? 'true' : 'false',
        'developerMode': developerMode ? 'true' : 'false',
        'retainScanImages': retainScanImages ? 'true' : 'false',
        'radialHandedness': radialHandedness.name,
        'radialHapticsEnabled': radialHapticsEnabled ? 'true' : 'false',
        'radialTutorialSeen': radialTutorialSeen ? 'true' : 'false',
        'conversationLibraryVersion': '$conversationLibraryVersion',
      };

  static AppSettings fromStringMap(Map<String, String> map) {
    return AppSettings(
      showKoreanRomanization: map['showKoreanRomanization'] != 'false',
      japaneseTtsEnabled: map['japaneseTtsEnabled'] != 'false',
      koreanTtsEnabled: map['koreanTtsEnabled'] != 'false',
      speechRate: enumFromNameOr(
        SpeechRatePreset.values,
        map['speechRate'],
        SpeechRatePreset.normal,
      ),
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
      conversationLibraryVersion:
          _nonNegativeInt(map['conversationLibraryVersion']),
    );
  }

  // conversationLibraryVersion is operational migration state, not a
  // user-visible preference, so it intentionally does not affect value
  // equality used by settings widgets.
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

int _nonNegativeInt(Object? value) {
  final parsed = value is int ? value : int.tryParse('$value') ?? 0;
  return parsed < 0 ? 0 : parsed;
}
