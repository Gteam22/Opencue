import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/enums/enums.dart';
import '../../domain/recommendation/recommendation_models.dart';
import '../../domain/scan/confidence.dart';
import '../../domain/scan/context_snapshot_mapper.dart';
import '../../domain/scan/environmental_observation.dart';
import '../../domain/scan/vision_analyzer.dart';
import '../recommendations/recommendations_screen.dart';
import '../../domain/context/context_draft.dart';
import '../../domain/models/context_snapshot.dart';
import '../../domain/scan/venue_category.dart';
import '../context_builder/context_composer_screen.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';
import 'scan_diagnostics_screen.dart';

/// Where the user reviews and corrects what the scan suggested.
///
/// Nothing reaches the recommendation engine without passing through here.
/// The screen makes two distinctions visible: what the scan proposed versus
/// what it could not see, and how sure it was about each proposal.
class ScanConfirmationScreen extends StatefulWidget {
  const ScanConfirmationScreen({
    required this.observation,
    this.cleanupReport,
    super.key,
  });

  final EnvironmentalObservation observation;

  /// Carried through only so the diagnostics screen can show cleanup counts.
  final ScanResult? cleanupReport;

  @override
  State<ScanConfirmationScreen> createState() =>
      _ScanConfirmationScreenState();
}

class _ScanConfirmationScreenState extends State<ScanConfirmationScreen> {
  static const ContextSnapshotMapper _mapper = ContextSnapshotMapper();

  late LocationTag? _location;
  late ActivityTag? _activity;
  late NoiseLevel? _noise;
  late Set<ObservableCue> _cues;

  // Never scanned. Unset until the user answers.
  GroupSize? _groupSize;
  bool _eyeContact = false;
  bool _conversationStarted = false;
  bool _occupied = false;
  bool _movingQuickly = false;
  bool _working = false;
  bool _headphones = false;
  bool _isolated = false;

  @override
  void initState() {
    super.initState();
    final initial = _mapper.initialFrom(widget.observation);
    _location = initial.location;
    _activity = initial.activity;
    _noise = initial.noiseLevel;
    _cues = initial.observableCues.toSet();
  }

  /// The scan's venue subtype, or null when it did not identify one.
  ///
  /// `VenueCategory.unknown` means "no guess", and passing it through as a
  /// subtype would put a meaningless chip on the results screen.
  VenueCategory? get _venue {
    final category = widget.observation.venue.category;
    return category == VenueCategory.unknown ? null : category;
  }

  /// The user's current answers, as the engine's snapshot.
  ///
  /// Shared by the confirm button and the radial correction path so the two
  /// cannot describe the same form differently.
  ContextSnapshot _asSnapshot() {
    return ContextSnapshot(
      location: _location,
      activity: _activity,
      groupSize: _groupSize,
      noiseLevel: _noise,
      observableCues: _cues,
      eyeContact: _eyeContact,
      conversationAlreadyStarted: _conversationStarted,
      personAppearsOccupied: _occupied,
      isWorking: _working,
      isUsingHeadphones: _headphones,
      personIsMovingQuickly: _movingQuickly,
      isIsolatedOrUnsafeSetting: _isolated,
      source: ContextSource.cameraScan,
    );
  }

  Future<void> _useContext() async {
    final state = AppScope.read(context);
    final confirmed = ConfirmedScanContext(
      observationId: widget.observation.id,
      location: _location,
      activity: _activity,
      groupSize: _groupSize,
      noiseLevel: _noise,
      observableCues: _cues,
      eyeContact: _eyeContact,
      conversationAlreadyStarted: _conversationStarted,
      personAppearsOccupied: _occupied,
      personIsMovingQuickly: _movingQuickly,
      isWorking: _working,
      isUsingHeadphones: _headphones,
      isIsolatedOrUnsafeSetting: _isolated,
    );

    // Routed through CameraContextProvider rather than mapped inline, so the
    // scan path satisfies the same ContextProvider contract as manual entry.
    final provider = CameraContextProvider(confirmed);
    final snapshot = await provider.captureContext();
    if (!mounted) return;

    // Every value the scan established is marked `fromScan`, so the radial
    // menu opens with them preselected and visibly distinguishable from
    // anything the user then corrects. `scanDraft` keeps the original so
    // *Use scan* can restore it after edits.
    final scanDraft = ContextDraft.fromSnapshot(
      snapshot,
      venue: _venue,
      directness: state.settings.defaultDirectness,
    );

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RecommendationsScreen(
          situation: snapshot,
          draft: scanDraft,
          scanDraft: scanDraft,
          preferences: RecommendationPreferences(
            desiredDirectness: state.settings.defaultDirectness,
          ),
        ),
      ),
    );
  }

  /// Corrects the scan through the radial menu instead of this form.
  ///
  /// The brief's requirement is that a correction takes about one gesture and
  /// does not send the user to a multi-page form, so this is offered
  /// alongside the confirmation controls rather than replacing them.
  Future<void> _adjustRadially() async {
    final state = AppScope.read(context);
    final scanDraft = ContextDraft.fromSnapshot(
      _asSnapshot(),
      venue: _venue,
      directness: state.settings.defaultDirectness,
    );
    final adjusted = await ContextComposerScreen.push(
      context,
      initialDraft: scanDraft,
      scanDraft: scanDraft,
    );
    if (adjusted == null || !mounted) return;
    setState(() {
      _location = adjusted.location;
      _activity = adjusted.activity;
      _groupSize = adjusted.groupSize;
      _noise = adjusted.noiseLevel;
      _cues = adjusted.cues.toSet();
      _eyeContact = adjusted.eyeContact;
      _conversationStarted = adjusted.conversationStarted;
      _occupied = adjusted.cautions.contains(AvoidCondition.personOccupied);
      _working = adjusted.cautions.contains(AvoidCondition.personWorking);
      _headphones = adjusted.cautions.contains(AvoidCondition.headphonesOn);
      _movingQuickly =
          adjusted.cautions.contains(AvoidCondition.movingQuickly);
      _isolated =
          adjusted.cautions.contains(AvoidCondition.isolatedSetting);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final observation = widget.observation;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('confirm.title')),
        actions: <Widget>[
          IconButton(
            tooltip: strings.t('context.adjust'),
            icon: const Icon(Icons.explore_outlined),
            onPressed: _adjustRadially,
          ),
          if (AppScope.of(context).settings.developerMode)
            IconButton(
              tooltip: strings.t('diagnostics.title'),
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScanDiagnosticsScreen(
                    observation: observation,
                    cleanupReport: widget.cleanupReport,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.t('confirm.subtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final warning in observation.warnings) ...<Widget>[
                  const SizedBox(height: 12),
                  _Warning(text: strings.t(warning)),
                ],
                const SizedBox(height: 20),

                // ---- What the scan proposed -------------------------------
                SectionCard(
                  title: strings.t('confirm.detected'),
                  subtitle: strings.t('scan.confidence.pleaseConfirm'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ConfidenceLine(
                        label: strings.t('context.location'),
                        inferred: observation.location,
                        rendered: _location == null
                            ? null
                            : strings.location(_location!),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final value in LocationTag.values)
                            ChoiceChip(
                              label: Text(strings.location(value)),
                              selected: _location == value,
                              onSelected: (on) => setState(
                                () => _location = on ? value : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.cues'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MultiSelectChips<ObservableCue>(
                        values: ObservableCue.values,
                        selected: _cues,
                        labelFor: (cue) {
                          final confidence =
                              observation.observableCues[cue];
                          final base = strings.cue(cue);
                          if (confidence == null) return base;
                          return '$base · '
                              '${strings.t(_levelKey(confidence.level))}';
                        },
                        onChanged: (next) => setState(() => _cues = next),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.noiseLevel'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final value in NoiseLevel.values)
                        ChoiceChip(
                          label: Text(strings.noiseLevel(value)),
                          selected: _noise == value,
                          onSelected: (on) =>
                              setState(() => _noise = on ? value : null),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.activity'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final value in ActivityTag.values)
                        ChoiceChip(
                          label: Text(strings.activity(value)),
                          selected: _activity == value,
                          onSelected: (on) =>
                              setState(() => _activity = on ? value : null),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ---- What the scan cannot see -----------------------------
                Text(
                  strings.t('confirm.notDetected'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                SectionCard(
                  title: strings.t('context.groupSize'),
                  subtitle: strings.t('confirm.groupSizeNotScanned'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final value in GroupSize.values)
                        ChoiceChip(
                          label: Text(strings.groupSize(value)),
                          selected: _groupSize == value,
                          onSelected: (on) => setState(
                            () => _groupSize = on ? value : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.checks'),
                  child: Column(
                    children: <Widget>[
                      _Toggle(
                        label: strings.t('context.eyeContact'),
                        value: _eyeContact,
                        onChanged: (v) => setState(() => _eyeContact = v),
                      ),
                      _Toggle(
                        label: strings.t('context.conversationStarted'),
                        value: _conversationStarted,
                        onChanged: (v) =>
                            setState(() => _conversationStarted = v),
                      ),
                      const Divider(height: 20),
                      _Toggle(
                        label: strings.t('context.personOccupied'),
                        value: _occupied,
                        isCaution: true,
                        onChanged: (v) => setState(() => _occupied = v),
                      ),
                      _Toggle(
                        label: strings.t('context.isWorking'),
                        value: _working,
                        isCaution: true,
                        onChanged: (v) => setState(() => _working = v),
                      ),
                      _Toggle(
                        label: strings.t('context.headphones'),
                        value: _headphones,
                        isCaution: true,
                        onChanged: (v) => setState(() => _headphones = v),
                      ),
                      _Toggle(
                        label: strings.t('context.movingQuickly'),
                        value: _movingQuickly,
                        isCaution: true,
                        onChanged: (v) => setState(() => _movingQuickly = v),
                      ),
                      _Toggle(
                        label: strings.t('context.isolated'),
                        value: _isolated,
                        isCaution: true,
                        onChanged: (v) => setState(() => _isolated = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _useContext,
                    icon: const Icon(Icons.check),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(strings.t('confirm.use')),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(strings.t('scan.rescan')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        child: Text(strings.t('scan.cancel')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _levelKey(ConfidenceLevel level) =>
      'scan.confidence.${level.name}';
}

/// Shows how sure the scan was, in words rather than a percentage.
class _ConfidenceLine extends StatelessWidget {
  const _ConfidenceLine({
    required this.label,
    required this.inferred,
    required this.rendered,
  });

  final String label;
  final Inferred<Object> inferred;
  final String? rendered;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final levelKey = 'scan.confidence.${inferred.level.name}';
    final text = rendered == null
        ? strings.t('scan.confidence.unknown')
        : '${strings.t(levelKey)} $rendered';

    return Row(
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyLarge),
        ),
        if (inferred.level.needsMarker && rendered != null)
          const Icon(Icons.help_outline, size: 16),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isCaution = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isCaution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isCaution && value
              ? theme.colorScheme.error
              : theme.colorScheme.onSurface,
        ),
      ),
      secondary: isCaution
          ? Icon(
              Icons.report_gmailerrorred_outlined,
              size: 20,
              color: value
                  ? theme.colorScheme.error
                  : theme.colorScheme.outlineVariant,
            )
          : null,
    );
  }
}
