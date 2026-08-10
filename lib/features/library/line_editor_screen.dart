import 'package:flutter/material.dart';

import '../../core/id_generator.dart';
import '../../core/theme.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/opener_line.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

/// Add or edit a line.
///
/// Japanese text is the only required field. Everything else affects when the
/// line gets suggested, and the form says so rather than presenting twelve
/// equally weighted inputs.
class LineEditorScreen extends StatefulWidget {
  const LineEditorScreen({this.existing, super.key});

  /// Null when creating a new line.
  final OpenerLine? existing;

  @override
  State<LineEditorScreen> createState() => _LineEditorScreenState();
}

class _LineEditorScreenState extends State<LineEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _japanese = TextEditingController();
  final TextEditingController _english = TextEditingController();
  final TextEditingController _followUp = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  late LineCategory _category;
  late Set<LocationTag> _locations;
  late Set<ActivityTag> _activities;
  late Set<ObservableCue> _cues;
  late Set<GroupSize> _groupSizes;
  late Set<NoiseLevel> _noiseLevels;
  late Set<Tone> _tones;
  late int _directness;
  late Set<UseCondition> _conditions;
  late Set<AvoidCondition> _avoidConditions;
  bool _dirty = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final line = widget.existing;
    _japanese.text = line?.japaneseText ?? '';
    _english.text = line?.englishMeaning ?? '';
    _followUp.text = line?.followUpSuggestion ?? '';
    _notes.text = line?.notes ?? '';
    _category = line?.category ?? LineCategory.universal;
    _locations = line?.locations.toSet() ?? <LocationTag>{};
    _activities = line?.activities.toSet() ?? <ActivityTag>{};
    _cues = line?.observableCues.toSet() ?? <ObservableCue>{};
    _groupSizes = line?.groupSizes.toSet() ?? <GroupSize>{};
    _noiseLevels = line?.noiseLevels.toSet() ??
        <NoiseLevel>{NoiseLevel.quiet, NoiseLevel.normal};
    _tones = line?.tones.toSet() ?? <Tone>{Tone.friendly};
    _directness = line?.directness ?? 2;
    _conditions = line?.conditions.toSet() ?? <UseCondition>{};
    _avoidConditions = line?.avoidConditions.toSet() ?? <AvoidCondition>{};

    for (final controller in <TextEditingController>[
      _japanese,
      _english,
      _followUp,
      _notes,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _japanese.dispose();
    _english.dispose();
    _followUp.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _change(VoidCallback mutate) {
    setState(() {
      mutate();
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final strings = AppScope.read(context).strings;
    return confirmAction(
      context,
      title: strings.t('editor.unsavedTitle'),
      body: strings.t('editor.unsavedBody'),
      confirmLabel: strings.t('action.delete'),
    );
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    final strings = state.strings;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tones.isEmpty) {
      showBriefMessage(context, strings.t('validation.toneRequired'));
      return;
    }

    final now = DateTime.now().toUtc();
    final existing = widget.existing;
    final line = OpenerLine(
      id: existing?.id ?? IdGenerator().lineId(),
      japaneseText: _japanese.text.trim(),
      englishMeaning: _english.text.trim().isEmpty
          ? null
          : _english.text.trim(),
      translations: existing?.translations,
      koreanRomanization: existing?.koreanRomanization,
      category: _category,
      locations: _locations,
      activities: _activities,
      observableCues: _cues,
      groupSizes: _groupSizes,
      noiseLevels: _noiseLevels,
      tones: _tones,
      directness: _directness,
      boldness: existing?.boldness,
      usageType: existing?.usageType,
      topics: existing?.topics,
      manualOnly: existing?.manualOnly ?? false,
      ttsJapanese: existing?.ttsJapanese ?? true,
      ttsKorean: existing?.ttsKorean ?? true,
      conditions: _conditions,
      avoidConditions: _avoidConditions,
      followUpSuggestion:
          _followUp.text.trim().isEmpty ? null : _followUp.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      isFavorite: existing?.isFavorite ?? false,
      // A line created or edited here belongs to the user, so it becomes
      // freely deletable. Restoring the starter library brings the original
      // back by id if this was a seed line.
      isUserCreated: existing?.isUserCreated ?? true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      timesShown: existing?.timesShown ?? 0,
      timesUsed: existing?.timesUsed ?? 0,
      positiveResults: existing?.positiveResults ?? 0,
      neutralResults: existing?.neutralResults ?? 0,
      negativeResults: existing?.negativeResults ?? 0,
    );

    final problems = line.validationErrors();
    if (problems.isNotEmpty) {
      showBriefMessage(context, strings.message(problems.first));
      return;
    }

    await state.saveLine(line, isNew: _isNew);
    if (!mounted) return;
    showBriefMessage(context, strings.t('editor.saved'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);

    return PopScope<void>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isNew
                ? strings.t('editor.newTitle')
                : strings.t('editor.editTitle'),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 18),
                label: Text(strings.t('action.save')),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              ContentColumn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionCard(
                      title: strings.t('editor.japanese'),
                      subtitle: strings.t('editor.japaneseHint'),
                      child: TextFormField(
                        controller: _japanese,
                        autofocus: _isNew,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? strings.t('validation.japaneseRequired')
                                : null,
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.english'),
                      subtitle: strings.t('editor.englishHint'),
                      child: TextFormField(
                        controller: _english,
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.category'),
                      child: SingleSelectChips<LineCategory>(
                        values: LineCategory.values,
                        selected: _category,
                        labelFor: strings.category,
                        onChanged: (value) =>
                            _change(() => _category = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.locations'),
                      subtitle: strings.t('editor.locationsHint'),
                      child: MultiSelectChips<LocationTag>(
                        values: LocationTag.values,
                        selected: _locations,
                        labelFor: strings.location,
                        onChanged: (value) =>
                            _change(() => _locations = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.cues'),
                      child: MultiSelectChips<ObservableCue>(
                        values: ObservableCue.values,
                        selected: _cues,
                        labelFor: strings.cue,
                        onChanged: (value) => _change(() => _cues = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.groupSizes'),
                      child: MultiSelectChips<GroupSize>(
                        values: GroupSize.values,
                        selected: _groupSizes,
                        labelFor: strings.groupSize,
                        onChanged: (value) =>
                            _change(() => _groupSizes = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.noiseLevels'),
                      child: MultiSelectChips<NoiseLevel>(
                        values: NoiseLevel.values,
                        selected: _noiseLevels,
                        labelFor: strings.noiseLevel,
                        onChanged: (value) =>
                            _change(() => _noiseLevels = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.activities'),
                      child: MultiSelectChips<ActivityTag>(
                        values: ActivityTag.values,
                        selected: _activities,
                        labelFor: strings.activity,
                        onChanged: (value) =>
                            _change(() => _activities = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.tones'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          MultiSelectChips<Tone>(
                            values: Tone.values,
                            selected: _tones,
                            labelFor: strings.tone,
                            onChanged: (value) =>
                                _change(() => _tones = value),
                          ),
                          const SizedBox(height: 16),
                          Text(strings.t('editor.directness')),
                          DirectnessSlider(
                            value: _directness,
                            onChanged: (value) =>
                                _change(() => _directness = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.conditions'),
                      child: MultiSelectChips<UseCondition>(
                        values: UseCondition.values,
                        selected: _conditions,
                        labelFor: strings.useCondition,
                        onChanged: (value) =>
                            _change(() => _conditions = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.avoidConditions'),
                      child: MultiSelectChips<AvoidCondition>(
                        values: AvoidCondition.values,
                        selected: _avoidConditions,
                        labelFor: strings.avoidCondition,
                        onChanged: (value) =>
                            _change(() => _avoidConditions = value),
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.followUp'),
                      child: TextFormField(
                        controller: _followUp,
                        minLines: 2,
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.gap),

                    SectionCard(
                      title: strings.t('editor.notes'),
                      child: TextFormField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 5,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
