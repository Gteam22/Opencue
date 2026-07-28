/// Application identity and schema versions.
///
/// [version] is duplicated in three places by necessity: pubspec.yaml (which
/// Flutter reads), installer/opencue.iss (which Inno Setup reads) and here.
/// version.txt is the single source of truth and
/// `test/version_consistency_test.dart` fails the build if any of them drift.
class AppInfo {
  const AppInfo._();

  static const String appName = 'OpenCue';

  /// Keep in step with version.txt, pubspec.yaml and installer/opencue.iss.
  static const String version = '0.1.0';

  /// Replace with a real organisation name before publishing. Also appears in
  /// installer/opencue.iss as AppPublisher and in LICENSE.
  static const String publisher = 'PUBLISHER_PLACEHOLDER';

  /// Replace with the real repository URL. Used on the About screen.
  static const String repositoryUrl =
      'https://github.com/OWNER/opencue';

  /// Folder name inside the user's application-data directory.
  static const String dataFolderName = 'OpenCue';

  static const String databaseFileName = 'opencue.db';

  /// Bumping this requires a matching step in AppDatabase.onUpgrade.
  static const int databaseVersion = 2;

  /// Version of the JSON import/export format. See lib/data/transfer.
  static const int transferSchemaVersion = 1;
}
