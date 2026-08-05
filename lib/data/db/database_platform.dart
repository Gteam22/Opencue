import 'dart:io';

// sqflite_common_ffi re-exports everything from sqflite_common/sqlite_api.dart
// (DatabaseFactory, inMemoryDatabasePath), so importing both would be flagged
// as an unnecessary_import. The sqflite import is prefixed because it exports
// the same names again for the mobile factory.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite_android;

/// Chooses the SQLite implementation for the current platform.
///
/// Both packages expose the same `sqflite_common` API, which is what every
/// repository in `lib/data/repositories` is written against. Nothing above this
/// file knows which one is in use, so the schema, the migrations and all the
/// queries are shared byte-for-byte between Windows and Android.
///
/// - Desktop (Windows, macOS, Linux) uses `sqflite_common_ffi`, which bundles
///   its own SQLite and talks to it over FFI.
/// - Android and iOS use `sqflite`, which binds to the SQLite already present
///   in the operating system.
///
/// Getting this backwards is the one change in the Android port that could
/// break the existing Windows build, so it is isolated here rather than being
/// decided inline at the call site.
class DatabasePlatform {
  const DatabasePlatform._();

  /// True when the mobile (`sqflite`) implementation should be used.
  ///
  /// Read through a getter rather than inlined so tests can reason about it,
  /// and so the desktop path stays the default for any platform not named.
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool _desktopReady = false;

  /// Prepares the platform's SQLite. Safe to call more than once.
  ///
  /// On mobile this is a no-op: `sqflite` needs no initialisation. On desktop
  /// it initialises the FFI bindings, which must happen before the first open.
  static void initialise() {
    if (isMobile) return;
    if (_desktopReady) return;
    sqfliteFfiInit();
    _desktopReady = true;
  }

  /// The factory to open databases with.
  static DatabaseFactory get factory =>
      isMobile ? sqflite_android.databaseFactory : databaseFactoryFfi;

  /// The path that opens a throwaway in-memory database.
  ///
  /// Both implementations honour the same sentinel, but it is re-exported here
  /// so callers do not have to import a platform package to get it.
  static String get inMemoryPath => inMemoryDatabasePath;
}
