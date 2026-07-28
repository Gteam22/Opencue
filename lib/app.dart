import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'core/theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shared/app_scope.dart';
import 'features/shared/widgets.dart';

/// The root widget.
///
/// Owns the [AppState] lifecycle, resolves the theme mode from settings, and
/// hosts the responsive shell.
class OpenCueApp extends StatefulWidget {
  const OpenCueApp({required this.state, super.key});

  final AppState state;

  @override
  State<OpenCueApp> createState() => _OpenCueAppState();
}

class _OpenCueAppState extends State<OpenCueApp> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    // Bootstrap here rather than in main() so a storage failure can be shown
    // inside the app instead of crashing before the first frame.
    widget.state.bootstrap();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// MaterialApp sits above AppScope, so the theme and locale have to be
  /// rebuilt from an explicit listener rather than an InheritedWidget.
  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: AppTheme.themeModeFor(
        widget.state.settings.themePreference,
      ),
      home: AppScope(
        state: widget.state,
        child: const _Shell(),
      ),
    );
  }
}

/// Shown by `main` when the database could not be opened at all.
///
/// Separate from the in-app error state because at that point there is no
/// [AppState] and therefore no settings, no theme preference and no strings.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: _StartupError(message: message),
      ),
    );
  }
}

/// The five destinations, in the order they appear in the navigation.
enum ShellDestination { home, library, favorites, history, settings }

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  ShellDestination _current = ShellDestination.home;

  void _go(ShellDestination destination) =>
      setState(() => _current = destination);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.loadError != null) {
      return Scaffold(
        body: _StartupError(
          message: state.loadError!,
          onRetry: state.bootstrap,
        ),
      );
    }

    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.railBreakpoint;

    final body = _bodyFor(_current);
    final destinations = <_DestinationSpec>[
      _DestinationSpec(
        ShellDestination.home,
        strings.t('nav.home'),
        Icons.home_outlined,
        Icons.home,
      ),
      _DestinationSpec(
        ShellDestination.library,
        strings.t('nav.library'),
        Icons.menu_book_outlined,
        Icons.menu_book,
      ),
      _DestinationSpec(
        ShellDestination.favorites,
        strings.t('nav.favorites'),
        Icons.star_outline,
        Icons.star,
      ),
      _DestinationSpec(
        ShellDestination.history,
        strings.t('nav.history'),
        Icons.insights_outlined,
        Icons.insights,
      ),
      _DestinationSpec(
        ShellDestination.settings,
        strings.t('nav.settings'),
        Icons.settings_outlined,
        Icons.settings,
      ),
    ];
    final index = destinations.indexWhere((d) => d.destination == _current);

    return Scaffold(
      appBar: _current == ShellDestination.home
          ? null
          : AppBar(title: Text(destinations[index].label)),
      body: isWide
          ? Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) =>
                      _go(destinations[i].destination),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: OpenCueMark(size: 26),
                  ),
                  destinations: <NavigationRailDestination>[
                    for (final spec in destinations)
                      NavigationRailDestination(
                        icon: Icon(spec.icon),
                        selectedIcon: Icon(spec.selectedIcon),
                        label: Text(spec.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => _go(destinations[i].destination),
              destinations: <NavigationDestination>[
                for (final spec in destinations)
                  NavigationDestination(
                    icon: Icon(spec.icon),
                    selectedIcon: Icon(spec.selectedIcon),
                    label: spec.label,
                  ),
              ],
            ),
    );
  }

  Widget _bodyFor(ShellDestination destination) {
    switch (destination) {
      case ShellDestination.home:
        return HomeScreen(
          onOpenLibrary: () => _go(ShellDestination.library),
          onOpenFavorites: () => _go(ShellDestination.favorites),
          onOpenHistory: () => _go(ShellDestination.history),
        );
      case ShellDestination.library:
        // Distinct keys so switching between Library and Favorites rebuilds
        // the screen with the right initial filter instead of reusing state.
        return const LibraryScreen(key: ValueKey<String>('library'));
      case ShellDestination.favorites:
        return const LibraryScreen(
          key: ValueKey<String>('favorites'),
          initialFavoritesOnly: true,
        );
      case ShellDestination.history:
        return const HistoryScreen();
      case ShellDestination.settings:
        return const SettingsScreen();
    }
  }
}

class _DestinationSpec {
  const _DestinationSpec(
    this.destination,
    this.label,
    this.icon,
    this.selectedIcon,
  );

  final ShellDestination destination;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Shown when the database could not be opened.
///
/// The path is included because the most likely causes are a locked file or a
/// permissions problem in the user data folder, and the path is what the user
/// needs in order to fix either.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, this.onRetry});

  final String message;

  /// Null when there is nothing to retry, as in [StartupFailureApp].
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 36,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'OpenCue could not open its database.',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SelectableText(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
