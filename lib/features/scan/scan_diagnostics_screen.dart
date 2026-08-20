import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/scan/environmental_observation.dart';
import '../../domain/scan/vision_analyzer.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// Everything about the last scan, for testing on a real handset.
///
/// This is where the raw decimal confidences live: useful when tuning
/// heuristics against a real room, misleading in the ordinary interface. It is
/// reachable only when developer mode is on.
///
/// It never displays a captured image, whatever the retention setting is.
class ScanDiagnosticsScreen extends StatelessWidget {
  const ScanDiagnosticsScreen({
    required this.observation,
    this.cleanupReport,
    super.key,
  });

  final EnvironmentalObservation observation;
  final ScanResult? cleanupReport;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final report = cleanupReport;

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('diagnostics.title'))),
      body: ListView(
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionCard(
                  title: strings.t('diagnostics.cleanup'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Row('Deleted', '${report?.temporaryFilesDeleted ?? 0}'),
                      _Row(
                        'Remaining',
                        '${report?.temporaryFilesRemaining ?? 0}',
                      ),
                      const SizedBox(height: 8),
                      if (report?.isClean ?? true)
                        Text(
                          strings.t('diagnostics.cleanupOk'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Text(
                          'Files were retained. This is expected only if '
                          'debug retention is switched on.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('diagnostics.timing'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Row(
                        'Analysis',
                        '${observation.processingDuration.inMilliseconds} ms',
                      ),
                      _Row('Frames', '${observation.frameCount}'),
                      _Row('Analyzer', observation.modelInformation),
                      _Row('Source', observation.source.name),
                      _Row(
                        'Captured',
                        observation.capturedAt.toIso8601String(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('diagnostics.rawLabels'),
                  subtitle: '${observation.detectedLabels.length} kept after '
                      'the confidence floor and stop list',
                  child: observation.detectedLabels.isEmpty
                      ? Text(
                          'None',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final label in observation.detectedLabels)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '${label.text}  '
                                  '${label.confidence.toStringAsFixed(3)}  '
                                  '(frame ${label.frameIndex})',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('diagnostics.normalised'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Row(
                        'Location',
                        '${observation.location.value?.name ?? "-"}  '
                            '${observation.location.confidence}',
                      ),
                      _Row(
                        'Activity',
                        '${observation.activity.value?.name ?? "-"}  '
                            '${observation.activity.confidence}',
                      ),
                      _Row(
                        'Noise',
                        '${observation.noiseLevel.value?.name ?? "-"}  '
                            '${observation.noiseLevel.confidence}',
                      ),
                      const SizedBox(height: 8),
                      Text('Cues', style: theme.textTheme.labelMedium),
                      for (final entry in observation.observableCues.entries)
                        Text(
                          '  ${entry.key.name}  ${entry.value}  '
                          'evidence: ${entry.value.evidence.join(", ")}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (observation.warnings.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text('Warnings', style: theme.textTheme.labelMedium),
                        for (final warning in observation.warnings)
                          Text(warning, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
