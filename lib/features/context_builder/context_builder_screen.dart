import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/context/context_draft.dart';
import '../../domain/context/context_provider.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/context_snapshot.dart';
import '../../domain/recommendation/recommendation_models.dart';
import '../recommendations/recommendations_screen.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// Where the user describes the situation.
///
/// Only the location has a meaningful default to beat; everything else can be
/// left alone. The controls are chips rather than dropdowns because this screen
/// gets used standing up, one-handed, in a hurry.
class ContextBuilderScreen extends StatefulWidget {
  const ContextBuilderScreen({
    this.initial,
    this.initialDraft,
    this.returnsDraft = false,
    super.key,
  });

  /// Pre-fills the form, used when coming back to adjust a situation.
  final ContextSnapshot? initial;

  /// Pre-fills the form from the shared draft. When set, this screen is one
  /// of the surfaces editing that single draft rather than an independent
  /// form, and [returnsDraft] is implied.
  final ContextDraft? initialDraft;

  /// When true, the screen pops the edited [ContextDraft] instead of pushing
  /// the recommendations screen itself. Used when the composer opened it.
  final bool returnsDraft;

  @override
  State<ContextBuilderScreen> createState() => _ContextBuilderScreenState();
}

class _ContextBuilderScreenState extends State<ContextBuilderScreen> {
  late ContextSnapshot _snapshot;
  late int _directness;
  Set<Tone> _preferredTones = <Tone>{};
  final TextEditingController _notes = TextEditingController();
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _snapshot = draft?.toSnapshot() ?? widget.initial ?? ContextSnapshot();
    _notes.text = _snapshot.userNotes ?? '';
    if (draft != null) {
      _preferredTones = draft.preferredTones.toSet();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      // The default directness comes from settings so a user who always wants
      // gentle suggestions does not reset the slider every time.
      _directness = widget.initialDraft?.directness ??
          AppScope.of(context).settings.defaultDirectness;
      _initialised = true;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _update(ContextSnapshot next) => setState(() => _snapshot = next);

  Future<void> _showSuggestions() async {
    final notes = _notes.text.trim();
    // ManualContextProvider is the Version 1 implementation of
    // ContextProvider. Routing through it here rather than passing the
    // snapshot directly is what keeps a future provider a drop-in swap.
    final provider = ManualContextProvider(
      _snapshot.copyWith(
        userNotes: notes.isEmpty ? null : notes,
        clearUserNotes: notes.isEmpty,
      ),
    );
    final captured = await provider.captureContext();
    if (!mounted) return;

    if (widget.returnsDraft || widget.initialDraft != null) {
      // The composer opened this editor to amend the shared draft, so hand
      // the result back rather than starting a second navigation branch.
      final edited = ContextDraft.fromSnapshot(
        captured,
        origin: DraftOrigin.fromUser,
        venue: widget.initialDraft?.venue,
        preferredTones: _preferredTones,
        directness: _directness,
      );
      Navigator.of(context).pop(edited);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecommendationsScreen(
          situation: captured,
          preferences: RecommendationPreferences(
            desiredDirectness: _directness,
            preferredTones: _preferredTones,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('context.title'))),
      body: ListView(
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.t('context.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),

                SectionCard(
                  title: strings.t('context.location'),
                  child: SingleSelectChips<LocationTag>(
                    values: LocationTag.values,
                    selected: _snapshot.location,
                    labelFor: strings.location,
                    onChanged: (value) =>
                        _update(_snapshot.copyWith(location: value)),
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.groupSize'),
                  child: SingleSelectChips<GroupSize>(
                    values: GroupSize.values,
                    selected: _snapshot.groupSize,
                    labelFor: strings.groupSize,
                    onChanged: (value) =>
                        _update(_snapshot.copyWith(groupSize: value)),
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.noiseLevel'),
                  child: SingleSelectChips<NoiseLevel>(
                    values: NoiseLevel.values,
                    selected: _snapshot.noiseLevel,
                    labelFor: strings.noiseLevel,
                    onChanged: (value) =>
                        _update(_snapshot.copyWith(noiseLevel: value)),
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.cues'),
                  subtitle: strings.t('context.cuesHint'),
                  child: MultiSelectChips<ObservableCue>(
                    values: ObservableCue.values,
                    selected: _snapshot.observableCues,
                    labelFor: strings.cue,
                    onChanged: (value) =>
                        _update(_snapshot.copyWith(observableCues: value)),
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.activity'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(strings.t('context.activityNone')),
                        selected: _snapshot.activity == null,
                        onSelected: (_) => _update(
                          _snapshot.copyWith(clearActivity: true),
                        ),
                      ),
                      for (final value in ActivityTag.values)
                        ChoiceChip(
                          label: Text(strings.activity(value)),
                          selected: _snapshot.activity == value,
                          onSelected: (_) =>
                              _update(_snapshot.copyWith(activity: value)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.checks'),
                  child: Column(
                    children: <Widget>[
                      _Check(
                        label: strings.t('context.eyeContact'),
                        value: _snapshot.eyeContact,
                        onChanged: (v) =>
                            _update(_snapshot.copyWith(eyeContact: v)),
                      ),
                      _Check(
                        label: strings.t('context.conversationStarted'),
                        value: _snapshot.conversationAlreadyStarted,
                        onChanged: (v) => _update(
                          _snapshot.copyWith(conversationAlreadyStarted: v),
                        ),
                      ),
                      const Divider(height: 20),
                      // The five below raise the advisory. They are grouped and
                      // labelled so it is obvious why suggestions stop.
                      _Check(
                        label: strings.t('context.personOccupied'),
                        value: _snapshot.personAppearsOccupied,
                        isCaution: true,
                        onChanged: (v) => _update(
                          _snapshot.copyWith(personAppearsOccupied: v),
                        ),
                      ),
                      _Check(
                        label: strings.t('context.isWorking'),
                        value: _snapshot.isWorking,
                        isCaution: true,
                        onChanged: (v) =>
                            _update(_snapshot.copyWith(isWorking: v)),
                      ),
                      _Check(
                        label: strings.t('context.headphones'),
                        value: _snapshot.isUsingHeadphones,
                        isCaution: true,
                        onChanged: (v) => _update(
                          _snapshot.copyWith(isUsingHeadphones: v),
                        ),
                      ),
                      _Check(
                        label: strings.t('context.movingQuickly'),
                        value: _snapshot.personIsMovingQuickly,
                        isCaution: true,
                        onChanged: (v) => _update(
                          _snapshot.copyWith(personIsMovingQuickly: v),
                        ),
                      ),
                      _Check(
                        label: strings.t('context.isolated'),
                        value: _snapshot.isIsolatedOrUnsafeSetting,
                        isCaution: true,
                        onChanged: (v) => _update(
                          _snapshot.copyWith(isIsolatedOrUnsafeSetting: v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.directness'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DirectnessSlider(
                        value: _directness,
                        onChanged: (v) => setState(() => _directness = v),
                      ),
                      const SizedBox(height: 12),
                      Text(strings.t('context.tonePreference')),
                      const SizedBox(height: 8),
                      MultiSelectChips<Tone>(
                        values: Tone.values,
                        selected: _preferredTones,
                        labelFor: strings.tone,
                        onChanged: (v) =>
                            setState(() => _preferredTones = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gap),

                SectionCard(
                  title: strings.t('context.notes'),
                  child: TextField(
                    controller: _notes,
                    maxLines: 3,
                    minLines: 2,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _showSuggestions,
                    icon: const Icon(Icons.search),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(strings.t('context.showSuggestions')),
                    ),
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

/// A full-width switch row with a large hit target.
class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isCaution = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Marks one of the five conditions that stop suggestions entirely.
  final bool isCaution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: false,
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
