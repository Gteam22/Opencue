import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/app_paths.dart';
import '../../core/theme.dart';
import '../../data/transfer/transfer_service.dart';
import '../../domain/enums/enums.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';
import 'about_screen.dart';

/// Preferences, backup, and the destructive actions.
///
/// Every irreversible option asks first and says exactly what it will remove.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.strings;
    final settings = state.settings;

    return ListView(
      children: <Widget>[
        ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionCard(
                title: strings.t('settings.language'),
                subtitle: strings.t('settings.languageHint'),
                child: SingleSelectChips<LanguageMode>(
                  values: LanguageMode.values,
                  selected: settings.languageMode,
                  labelFor: strings.languageMode,
                  onChanged: state.setLanguage,
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              SectionCard(
                title: strings.t('settings.theme'),
                child: SingleSelectChips<AppThemePreference>(
                  values: AppThemePreference.values,
                  selected: settings.themePreference,
                  labelFor: strings.theme,
                  onChanged: state.setTheme,
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              SectionCard(
                title: strings.t('settings.defaultDirectness'),
                subtitle: strings.t('settings.defaultDirectnessHint'),
                child: DirectnessSlider(
                  value: settings.defaultDirectness,
                  onChanged: (value) => state.updateSettings(
                    settings.copyWith(defaultDirectness: value),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              SectionCard(
                title: strings.t('settings.data'),
                subtitle: strings.t('settings.exportSubtitle'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.includeHistoryInExport,
                      onChanged: (value) => state.updateSettings(
                        settings.copyWith(includeHistoryInExport: value),
                      ),
                      title: Text(strings.t('settings.exportIncludeHistory')),
                      subtitle: Text(
                        strings.t('settings.exportIncludeHistoryNote'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _export,
                          icon: const Icon(Icons.file_download_outlined,
                              size: 18),
                          label: Text(strings.t('settings.export')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _import,
                          icon: const Icon(Icons.file_upload_outlined,
                              size: 18),
                          label: Text(strings.t('settings.import')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              SectionCard(
                title: strings.t('nav.library'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ActionRow(
                      title: strings.t('settings.restoreStarter'),
                      body: strings.t('settings.restoreStarterSubtitle'),
                      label: strings.t('action.restore'),
                      onPressed: _busy ? null : _restoreStarter,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              SectionCard(
                title: strings.t('settings.dangerZone'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ActionRow(
                      title: strings.t('settings.clearHistory'),
                      body: strings.t('settings.clearHistorySubtitle'),
                      label: strings.t('action.clear'),
                      isDestructive: true,
                      onPressed: _busy ? null : _clearHistory,
                    ),
                    const Divider(height: 24),
                    _ActionRow(
                      title: strings.t('settings.resetAll'),
                      body: strings.t('settings.resetAllSubtitle'),
                      label: strings.t('action.reset'),
                      isDestructive: true,
                      onPressed: _busy ? null : _resetAll,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.gap),

              SectionCard(
                title: strings.t('settings.about'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${AppInfo.appName} ${AppInfo.version}'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: Text(strings.t('settings.about')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // Export and import
  // -----------------------------------------------------------------

  Future<void> _export() async {
    final state = AppScope.read(context);
    final strings = state.strings;
    setState(() => _busy = true);
    try {
      final location = await getSaveLocation(
        suggestedName: AppPaths.suggestedExportFileName(DateTime.now()),
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
        ],
      );
      if (location == null) return;
      final json = state.buildExport(
        includeInteractions: state.settings.includeHistoryInExport,
      );
      await File(location.path).writeAsString(json);
      if (!mounted) return;
      showBriefMessage(
        context,
        strings.f('export.done', <Object?>[location.path]),
      );
    } on Object catch (error) {
      if (!mounted) return;
      showBriefMessage(
        context,
        strings.f('export.failed', <Object?>['$error']),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final state = AppScope.read(context);
    final strings = state.strings;
    setState(() => _busy = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
        ],
      );
      if (file == null) return;
      final raw = await file.readAsString();
      final result = state.transfer.parse(raw);

      if (!result.isSuccess) {
        if (!mounted) return;
        await _showImportProblem(result);
        return;
      }

      final payload = result.payload!;
      if (!mounted) return;
      final mode = await _askImportMode(payload, result.warnings);
      if (mode == null) return;

      final summary = await state.applyImport(payload: payload, mode: mode);
      if (!mounted) return;
      showBriefMessage(
        context,
        strings.f(
          'import.summary',
          <Object?>[
            summary.linesAdded,
            summary.linesRekeyed,
            summary.interactionsAdded,
          ],
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      showBriefMessage(
        context,
        strings.f('import.readFailed', <Object?>['$error']),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reports why a file could not be used, in plain language.
  Future<void> _showImportProblem(ImportResult result) async {
    final strings = AppScope.read(context).strings;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('import.failedTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final error in result.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('· ${strings.message(error)}'),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.t('action.close')),
          ),
        ],
      ),
    );
  }

  /// Merge or replace. There is no default: the two outcomes are too different
  /// to pick one on the user's behalf.
  Future<ImportMode?> _askImportMode(
    ImportPayload payload,
    List<String> warnings,
  ) {
    final strings = AppScope.read(context).strings;
    return showDialog<ImportMode>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(strings.t('settings.import')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.f(
                    'import.preview',
                    <Object?>[
                      payload.lines.length,
                      payload.interactions.length,
                    ],
                  ),
                ),
                if (payload.sourceAppVersion != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    strings.f(
                      'import.fromVersion',
                      <Object?>[payload.sourceAppVersion],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (warnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    strings.t('import.warningsTitle'),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  for (final warning in warnings.take(8))
                    Text(
                      '· ${strings.message(warning)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (warnings.length > 8)
                    Text(
                      strings.f(
                        'import.moreWarnings',
                        <Object?>[warnings.length - 8],
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  strings.t('import.chooseMode'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.t('action.cancel')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ImportMode.replace),
              child: Text(strings.t('import.replace')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ImportMode.merge),
              child: Text(strings.t('import.merge')),
            ),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // Destructive actions
  // -----------------------------------------------------------------

  Future<void> _restoreStarter() async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final confirmed = await confirmAction(
      context,
      title: strings.t('confirm.restoreStarterTitle'),
      body: strings.t('confirm.restoreStarterBody'),
      confirmLabel: strings.t('action.restore'),
      isDestructive: false,
    );
    if (!confirmed) return;
    final added = await state.restoreStarterLibrary();
    if (!mounted) return;
    showBriefMessage(
      context,
      strings.f('settings.restored', <Object?>[added]),
    );
  }

  Future<void> _clearHistory() async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final confirmed = await confirmAction(
      context,
      title: strings.t('confirm.clearHistoryTitle'),
      body: strings.t('confirm.clearHistoryBody'),
      extraNote: strings.t('settings.exportFirst'),
      confirmLabel: strings.t('action.clear'),
    );
    if (!confirmed) return;
    await state.clearHistory();
    if (!mounted) return;
    showBriefMessage(context, strings.t('confirm.done'));
  }

  Future<void> _resetAll() async {
    final state = AppScope.read(context);
    final strings = state.strings;
    final confirmed = await confirmAction(
      context,
      title: strings.t('confirm.resetAllTitle'),
      body: strings.t('confirm.resetAllBody'),
      extraNote: strings.t('settings.exportFirst'),
      confirmLabel: strings.t('action.reset'),
    );
    if (!confirmed) return;
    // Second confirmation: this is the only action that removes the user's
    // own written lines, and it cannot be undone from inside the app.
    final reallyConfirmed = await confirmAction(
      context,
      title: strings.t('settings.resetAllFinalTitle'),
      body: strings.t('settings.resetAllFinalBody'),
      confirmLabel: strings.t('action.reset'),
    );
    if (!reallyConfirmed) return;
    await state.resetAllData();
    if (!mounted) return;
    showBriefMessage(context, strings.t('confirm.done'));
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.body,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String title;
  final String body;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: onPressed,
          style: isDestructive
              ? OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                )
              : null,
          child: Text(label),
        ),
      ],
    );
  }
}
