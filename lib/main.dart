import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_paths.dart';
import 'data/db/app_database.dart';
import 'data/library_service.dart';
import 'data/repositories/sqlite_repositories.dart';
import 'features/shared/app_scope.dart';

/// Wires storage to the UI and starts the app.
///
/// Deliberately thin: the whole object graph is assembled here so that a test,
/// or a future Android entry point, can build the same one against a different
/// database path without touching any widget code.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final databasePath = await AppPaths.databaseFile();
    final database = await AppDatabase.open(databasePath);

    final state = AppState(
      service: LibraryService(
        lines: SqliteOpenerLineRepository(database.db),
        interactions: SqliteInteractionRepository(database.db),
        settings: SqliteSettingsRepository(database.db),
      ),
    );

    runApp(OpenCueApp(state: state));
  } on Object catch (error) {
    // Opening the data file is the one thing that has to happen before any
    // widget exists, so its failure needs its own minimal app rather than the
    // in-app error screen. A locked file or an unwritable AppData folder are
    // the realistic causes, and both need the path to diagnose.
    runApp(StartupFailureApp(message: '$error'));
  }
}
