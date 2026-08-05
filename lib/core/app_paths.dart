import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_info.dart';

/// Resolves where OpenCue keeps its data.
///
/// The database lives in the per-user application-data directory, never inside
/// the installation directory. That is what lets the installer replace every
/// program file during an upgrade without touching the user's library.
///
/// On Windows this resolves to:
///   %APPDATA%\OpenCue\opencue.db
/// which for a per-user install is
///   C:\Users\<name>\AppData\Roaming\OpenCue\opencue.db
class AppPaths {
  const AppPaths._();

  /// Overrides the data directory. Set by tests; null in the real app.
  static String? debugDataDirectoryOverride;

  /// Returns the OpenCue data directory, creating it if necessary.
  static Future<Directory> dataDirectory() async {
    final override = debugDataDirectoryOverride;
    if (override != null) {
      return Directory(override).create(recursive: true);
    }
    final base = await getApplicationSupportDirectory();
    // getApplicationSupportDirectory already includes the application name on
    // Windows, but joining explicitly keeps the layout identical across
    // platforms and stable if the plugin's convention changes.
    final dir = Directory(p.join(base.path, AppInfo.dataFolderName));
    return dir.create(recursive: true);
  }

  /// Full path to the SQLite file.
  static Future<String> databaseFile() async {
    final dir = await dataDirectory();
    return p.join(dir.path, AppInfo.databaseFileName);
  }

  /// Default filename offered in the export save dialog.
  static String suggestedExportFileName(DateTime now) {
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'opencue-backup-$stamp.json';
  }
}
