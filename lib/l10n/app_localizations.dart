import '../domain/enums/enums.dart';
import 'strings_en.dart';
import 'strings_ja.dart';

/// Interface strings for OpenCue.
///
/// Strings live in two tables keyed by a dotted string rather than being
/// written inline in widgets, so that adding a language means adding one file.
/// `test/localization_test.dart` asserts the two tables have identical key sets
/// and that every key a widget asks for exists.
///
/// ## How the three language modes differ
///
/// * [LanguageMode.japanese] — interface in Japanese. Opener cards show the
///   Japanese line only; the English meaning is available on the detail view.
/// * [LanguageMode.english] — interface in English. Opener cards still lead
///   with the Japanese line, because that is the text the user will actually
///   say, with the English meaning beneath it.
/// * [LanguageMode.bilingual] — interface in English, and both the Japanese
///   line and the English meaning are shown everywhere a line appears.
class AppLocalizations {
  const AppLocalizations(this.mode, {bool romanizeKorean = false})
      : _romanizeKorean = romanizeKorean;

  final LanguageMode mode;

  /// Whether Korean lines carry a Roman reading. Comes from the settings
  /// toggle, threaded through AppScope.
  final bool _romanizeKorean;

  static const AppLocalizations fallback =
      AppLocalizations(LanguageMode.bilingual);

  /// Which table to read interface strings from.
  ///
  /// Korean chrome is not yet translated, so Korean and Both use the English
  /// interface (via [LanguageModeText.interfaceLanguage]) while the opener
  /// cards themselves show Korean.
  Map<String, String> get _table =>
      mode.interfaceLanguage == LanguageMode.japanese ? stringsJa : stringsEn;

  /// Whether the English meaning is shown alongside a line.
  ///
  /// Shown in every mode except pure Japanese, including Korean and Both,
  /// because the English meaning is the metadata the brief asks to preserve.
  bool get showEnglishMeaning => mode != LanguageMode.japanese;

  /// Whether the Roman reading is shown under Korean lines. True only when the
  /// setting is on and Korean lines are actually being shown.
  bool get showKoreanRomanization => _romanizeKorean && mode.showsKorean;

  bool get showsJapaneseLines => mode.showsJapanese;
  bool get showsKoreanLines => mode.showsKorean;

  /// Looks up [key]. Falls back to English, then to the key itself, so a
  /// missing string shows up as an obvious defect rather than a blank label.
  String t(String key) {
    final value = _table[key];
    if (value != null) return value;
    return stringsEn[key] ?? key;
  }

  /// Looks up [key] and substitutes `{0}`, `{1}`, ... with [args].
  String f(String key, List<Object?> args) {
    var result = t(key);
    for (var i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', '${args[i]}');
    }
    return result;
  }

  // -----------------------------------------------------------------
  // Controlled-vocabulary labels
  // -----------------------------------------------------------------

  String location(LocationTag value) => t('location.${value.name}');

  String activity(ActivityTag value) => t('activity.${value.name}');

  String groupSize(GroupSize value) => t('groupSize.${value.name}');

  String noiseLevel(NoiseLevel value) => t('noiseLevel.${value.name}');

  String tone(Tone value) => t('tone.${value.name}');

  String cue(ObservableCue value) => t('cue.${value.name}');

  String useCondition(UseCondition value) => t('condition.${value.name}');

  String avoidCondition(AvoidCondition value) => t('avoid.${value.name}');

  String category(LineCategory value) => t('category.${value.name}');

  String boldness(ConversationBoldness value) =>
      t('boldness.${value.name}');

  String usageType(ConversationUsageType value) =>
      t('usageType.${value.name}');

  String outcome(InteractionOutcome value) => t('outcome.${value.name}');

  String sort(LibrarySort value) => t('sort.${value.name}');

  String languageMode(LanguageMode value) => t('language.${value.name}');

  String theme(AppThemePreference value) => t('theme.${value.name}');

  String contextSource(ContextSource value) => t('source.${value.name}');

  /// A short word for a point on the 1-5 directness scale.
  String directnessLabel(int value) =>
      t('directness.${clampDirectness(value)}');

  /// Turns a score-factor code into a matching reason the user can read.
  String scoreFactor(String code) => t('factor.$code');

  /// Resolves the validation and import message keys that the domain and data
  /// layers return, including the `key:detail` form.
  String message(String rawKey) {
    final separator = rawKey.indexOf(':');
    if (separator == -1) return t(rawKey);
    final key = rawKey.substring(0, separator);
    final detail = rawKey.substring(separator + 1);
    return f(key, <Object?>[detail]);
  }
}
