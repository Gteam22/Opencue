import '../enums/enums.dart';

/// User preferences. Stored locally in the `settings` key/value table.
class AppSettings {
  const AppSettings({
    this.languageMode = LanguageMode.bilingual,
    this.themePreference = AppThemePreference.system,
    this.defaultDirectness = 2,
    this.includeHistoryInExport = false,
  });

  final LanguageMode languageMode;
  final AppThemePreference themePreference;

  /// Pre-selected directness on the situation builder.
  final int defaultDirectness;

  /// Whether an export includes interaction history. Off by default: notes are
  /// the most sensitive thing in the database, so including them is a
  /// deliberate choice rather than the default.
  final bool includeHistoryInExport;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    LanguageMode? languageMode,
    AppThemePreference? themePreference,
    int? defaultDirectness,
    bool? includeHistoryInExport,
  }) {
    return AppSettings(
      languageMode: languageMode ?? this.languageMode,
      themePreference: themePreference ?? this.themePreference,
      defaultDirectness:
          clampDirectness(defaultDirectness ?? this.defaultDirectness),
      includeHistoryInExport:
          includeHistoryInExport ?? this.includeHistoryInExport,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'languageMode': languageMode.name,
        'themePreference': themePreference.name,
        'defaultDirectness': defaultDirectness,
        'includeHistoryInExport': includeHistoryInExport,
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
    );
  }

  /// Flat string map for the key/value settings table.
  Map<String, String> toStringMap() => <String, String>{
        'languageMode': languageMode.name,
        'themePreference': themePreference.name,
        'defaultDirectness': '$defaultDirectness',
        'includeHistoryInExport': includeHistoryInExport ? 'true' : 'false',
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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.languageMode == languageMode &&
      other.themePreference == themePreference &&
      other.defaultDirectness == defaultDirectness &&
      other.includeHistoryInExport == includeHistoryInExport;

  @override
  int get hashCode => Object.hash(
        languageMode,
        themePreference,
        defaultDirectness,
        includeHistoryInExport,
      );
}
