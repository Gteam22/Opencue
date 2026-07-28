import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// Version, publisher, privacy statement, and a note on intended use.
///
/// The privacy section is written as plain statements of fact about this build,
/// not as a policy document, because everything it describes is verifiable from
/// the source: no network client and no sensor package is declared anywhere.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('settings.about'))),
      body: ListView(
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const OpenCueMark(size: 40),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppInfo.appName,
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          'Version ${AppInfo.version}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SectionCard(
                  title: strings.t('about.title'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(strings.t('about.what')),
                      const SizedBox(height: 14),
                      _Fact(
                        label: strings.t('about.publisher'),
                        value: AppInfo.publisher,
                      ),
                      _Fact(
                        label: strings.t('about.license'),
                        value: 'MIT',
                      ),
                      _Fact(
                        label: strings.t('about.repository'),
                        value: AppInfo.repositoryUrl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.f(
                          'about.starterLibraryNote',
                          <Object?>[state.lineCount],
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('about.privacyTitle'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final key in const <String>[
                        'about.privacyLocal',
                        'about.privacyNoCamera',
                        'about.privacyNoMic',
                        'about.privacyNoProfiling',
                        'about.privacyNotes',
                        'about.privacyNoTelemetry',
                        'about.privacyFuture',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.lock_outline,
                                size: 15,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(strings.t(key))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('about.respectTitle'),
                  child: Text(strings.t('about.respect')),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
