import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/conversation/speech_to_text_recognition_service.dart';
import '../../domain/conversation/conversation_assist_controller.dart';
import '../../domain/conversation/conversation_models.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/opener_line.dart';
import '../library/line_detail_screen.dart';
import '../shared/app_scope.dart';
import '../shared/korean_speak_button.dart';
import '../shared/widgets.dart';

class ConversationAssistScreen extends StatefulWidget {
  const ConversationAssistScreen({super.key});

  @override
  State<ConversationAssistScreen> createState() =>
      _ConversationAssistScreenState();
}

class _ConversationAssistScreenState extends State<ConversationAssistScreen> {
  late final ConversationAssistController _controller;
  final TextEditingController _transcript = TextEditingController();
  final FocusNode _transcriptFocus = FocusNode();
  ConversationPreferences _preferences = const ConversationPreferences();
  bool _loadedAdultPreference = false;

  @override
  void initState() {
    super.initState();
    _controller = ConversationAssistController(
      recognition: SpeechToTextRecognitionService(),
    )..addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedAdultPreference) {
      _loadedAdultPreference = true;
      _preferences = _preferences.copyWith(
        adultContentEnabled:
            AppScope.of(context).settings.conversationAssistAdultContentEnabled,
      );
    }
  }

  void _onControllerChanged() {
    if (!_transcriptFocus.hasFocus &&
        _transcript.text != _controller.transcript) {
      _transcript.value = TextEditingValue(
        text: _controller.transcript,
        selection: TextSelection.collapsed(
          offset: _controller.transcript.length,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _transcript.dispose();
    _transcriptFocus.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    final state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    if (_controller.listenModeActive) {
      await _controller.stop();
      return;
    }
    await _controller.start(
      library: state.lines,
      preferences: _preferences,
      speechController: state.speech,
      autoSpeak: state.settings.conversationAssistAutoSpeakEnabled,
      outputLanguageMode: state.settings.languageMode,
      speechRate: state.settings.speechRate.rate,
      japaneseTtsEnabled: state.settings.japaneseTtsEnabled,
      koreanTtsEnabled: state.settings.koreanTtsEnabled,
    );
  }

  Future<void> _suggestEditedText() async {
    await _controller.submitManualTranscript(
      _transcript.text,
      library: AppScope.read(context).lines,
      preferences: _preferences,
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('assist.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.t('assist.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                _ListenPanel(
                  controller: _controller,
                  onToggle: _listen,
                ),
                _AutoSpeakControl(
                  value: AppScope.of(context)
                      .settings
                      .conversationAssistAutoSpeakEnabled,
                  enabled: AppScope.speech(context).isSupported,
                  onChanged: _setAutoSpeak,
                ),
                const SizedBox(height: AppTheme.gap),
                _InputLanguageControl(controller: _controller),
                const SizedBox(height: AppTheme.gap),
                TextField(
                  key: const Key('assist-transcript'),
                  controller: _transcript,
                  focusNode: _transcriptFocus,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _suggestEditedText(),
                  decoration: InputDecoration(
                    labelText: strings.t('assist.transcript'),
                    hintText: strings.t('assist.transcriptHint'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: strings.t('assist.useEdited'),
                      onPressed: _suggestEditedText,
                      icon: const Icon(Icons.auto_awesome_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PreferenceControls(
                  preferences: _preferences,
                  onChanged: _setPreferences,
                  onAdultChanged: _setAdultContent,
                ),
                const SizedBox(height: 20),
                if (_controller.phase ==
                    ConversationAssistPhase.understanding)
                  const Center(child: CircularProgressIndicator()),
                if (_controller.result != null)
                  _Suggestions(
                    result: _controller.result!,
                    onMore: _controller.more,
                    feedbackFor: _controller.feedbackFor,
                    onAccepted: _acceptSuggestion,
                    onDismissed: (line) =>
                        _controller.dismissSuggestion(line.id),
                  ),
                if (AppScope.of(context).settings.developerMode &&
                    _controller.diagnostics != null) ...<Widget>[
                  const SizedBox(height: 20),
                  _PipelineDiagnosticsCard(
                    diagnostics: _controller.diagnostics!,
                  ),
                ],
                if (_controller.history.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  _SessionHistory(turns: _controller.history),
                ],
                const SizedBox(height: 16),
                Text(
                  strings.t('assist.privacy'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setPreferences(ConversationPreferences value) {
    setState(() => _preferences = value);
    _controller.setPreferences(value);
  }

  Future<void> _setAutoSpeak(bool enabled) async {
    _controller.setAutoSpeak(enabled);
    final state = AppScope.read(context);
    await state.updateSettings(
      state.settings.copyWith(
        conversationAssistAutoSpeakEnabled: enabled,
      ),
    );
  }

  Future<void> _setAdultContent(bool enabled) async {
    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppScope.strings(context).t('assist.adultConfirmTitle')),
          content: Text(AppScope.strings(context).t('assist.adultConfirmBody')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppScope.strings(context).t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppScope.strings(context).t('assist.adultEnable')),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    final next = _preferences.copyWith(
      adultContentEnabled: enabled,
      maxBoldness: enabled
          ? _preferences.maxBoldness
          : (_preferences.maxBoldness.index >
                  ConversationBoldness.flirty.index
              ? ConversationBoldness.flirty
              : _preferences.maxBoldness),
    );
    setState(() => _preferences = next);
    _controller.setPreferences(next);
    final state = AppScope.read(context);
    await state.updateSettings(
      state.settings.copyWith(
        conversationAssistAdultContentEnabled: enabled,
      ),
    );
  }

  Future<void> _acceptSuggestion(OpenerLine line) async {
    if (_controller.feedbackFor(line.id) ==
        SuggestionFeedbackKind.accepted) {
      return;
    }
    _controller.acceptSuggestion(line.id);
    final state = AppScope.read(context);
    await state.recordOutcome(
      line: line,
      outcome: InteractionOutcome.positive,
      notes: 'Conversation Assist intent: '
          '${_controller.result?.interpretation.primaryIntentId ?? 'unknown'}',
    );
  }
}

class _ListenPanel extends StatelessWidget {
  const _ListenPanel({
    required this.controller,
    required this.onToggle,
  });

  final ConversationAssistController controller;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    final listening = controller.isListening;
    final phase = controller.phase;
    final status = switch (phase) {
      ConversationAssistPhase.idle => strings.t('assist.ready'),
      ConversationAssistPhase.initializing => strings.t('assist.initializing'),
      ConversationAssistPhase.waitingForSpeech =>
        strings.t('assist.waitingForSpeech'),
      ConversationAssistPhase.hearingSpeech =>
        strings.t('assist.hearingSpeech'),
      ConversationAssistPhase.understanding =>
        strings.t('assist.understanding'),
      ConversationAssistPhase.speaking => strings.t('assist.speaking'),
      ConversationAssistPhase.suggestions => strings.t('assist.readyAgain'),
      ConversationAssistPhase.noSpeech => strings.t('assist.noSpeech'),
      ConversationAssistPhase.unavailable => strings.t('assist.unavailable'),
      ConversationAssistPhase.permissionDenied =>
        strings.t('assist.permissionDenied'),
      ConversationAssistPhase.error =>
        controller.errorMessage ?? strings.t('assist.error'),
    };
    return Card(
      color: listening ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              height: 64,
              child: FilledButton(
                key: const Key('assist-listen'),
                onPressed: phase == ConversationAssistPhase.initializing
                    ? null
                    : onToggle,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  listening
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    listening
                        ? strings.t('assist.stopListening')
                        : strings.t('assist.startListening'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(status),
                  if (phase == ConversationAssistPhase.hearingSpeech ||
                      phase == ConversationAssistPhase.understanding ||
                      phase == ConversationAssistPhase.speaking) ...<Widget>[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: null,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoSpeakControl extends StatelessWidget {
  const _AutoSpeakControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        key: const Key('assist-auto-speak'),
        contentPadding: EdgeInsets.zero,
        title: Text(AppScope.strings(context).t('assist.autoSpeak')),
        subtitle: Text(
          AppScope.strings(context).t(
            enabled
                ? 'assist.autoSpeakHint'
                : 'assist.autoSpeakUnavailable',
          ),
        ),
        value: enabled && value,
        onChanged: enabled ? onChanged : null,
      );
}

class _InputLanguageControl extends StatelessWidget {
  const _InputLanguageControl({required this.controller});

  final ConversationAssistController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return Row(
      children: <Widget>[
        Text(strings.t('assist.inputLanguage')),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<ConversationInputLanguage>(
            value: controller.inputLanguage,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: <DropdownMenuItem<ConversationInputLanguage>>[
              for (final value in ConversationInputLanguage.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(strings.t('assist.language.${value.name}')),
                ),
            ],
            onChanged: controller.isListening
                ? null
                : (value) {
                    if (value != null) controller.setInputLanguage(value);
                  },
          ),
        ),
      ],
    );
  }
}

class _PreferenceControls extends StatelessWidget {
  const _PreferenceControls({
    required this.preferences,
    required this.onChanged,
    required this.onAdultChanged,
  });

  final ConversationPreferences preferences;
  final ValueChanged<ConversationPreferences> onChanged;
  final ValueChanged<bool> onAdultChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return SectionCard(
      title: strings.t('assist.style'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tone in ConversationToneBias.values)
                ChoiceChip(
                  label: Text(strings.t('assist.tone.${tone.name}')),
                  selected: preferences.tone == tone,
                  onSelected: (_) => onChanged(
                    preferences.copyWith(tone: tone),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(strings.t('assist.boldness')),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final boldness in ConversationBoldness.values)
                ChoiceChip(
                  label: Text(strings.boldness(boldness)),
                  selected: preferences.maxBoldness == boldness,
                  onSelected: !preferences.adultContentEnabled &&
                          boldness.index > ConversationBoldness.flirty.index
                      ? null
                      : (_) => onChanged(
                            preferences.copyWith(maxBoldness: boldness),
                          ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.t('assist.adultContent')),
            subtitle: Text(strings.t('assist.adultContentHint')),
            value: preferences.adultContentEnabled,
            onChanged: onAdultChanged,
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.result,
    required this.onMore,
    required this.feedbackFor,
    required this.onAccepted,
    required this.onDismissed,
  });

  final ConversationSuggestionResult result;
  final VoidCallback onMore;
  final SuggestionFeedbackKind? Function(String lineId) feedbackFor;
  final ValueChanged<OpenerLine> onAccepted;
  final ValueChanged<OpenerLine> onDismissed;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.f('assist.cuesFor', <Object?>[result.transcript]),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (result.interpretation.primaryIntent != null)
          Text(
            strings.f(
              'assist.understoodAs',
              <Object?>[
                result.interpretation.primaryIntent!.definition.description,
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                strings.t('assist.suggestions'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: onMore,
              icon: const Icon(Icons.refresh),
              label: Text(strings.t('assist.more')),
            ),
          ],
        ),
        if (result.usedSafeFallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              strings.t('assist.safeFallback'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (result.lowRecognitionConfidence)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              strings.t('assist.lowConfidence'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        for (var i = 0; i < result.suggestions.length; i++)
          _SuggestionCard(
            line: result.suggestions[i].line,
            slot: result.suggestions[i].slot,
            feedback: feedbackFor(result.suggestions[i].line.id),
            onAccepted: onAccepted,
            onDismissed: onDismissed,
          ),
      ],
    );
  }
}

class _PipelineDiagnosticsCard extends StatelessWidget {
  const _PipelineDiagnosticsCard({required this.diagnostics});

  final ConversationPipelineDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final values = <(String, String)>[
      ('Raw transcript', diagnostics.rawTranscript),
      ('Normalized', diagnostics.normalizedTranscript),
      ('Finalized', '${diagnostics.finalized}'),
      ('Intent', diagnostics.intentId),
      ('Confidence', diagnostics.confidence.toStringAsFixed(2)),
      ('Matcher', diagnostics.matcher.name),
      ('Responses found', '${diagnostics.responsesFound}'),
      ('Displayed', '${diagnostics.responsesDisplayed}'),
      ('Action', diagnostics.action.name),
      ('Source', diagnostics.source.name),
      ('Matcher reasons', diagnostics.matcherReasons.join(', ')),
      ('Response hints', diagnostics.responseHints.join(', ')),
      (
        'Reel slots',
        diagnostics.reelSlotLineIds.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', '),
      ),
      ('Excluded already shown', '${diagnostics.excludedAlreadyShown}'),
      ('More generation', '${diagnostics.moreGeneration} (same intent)'),
      (
        'Top response scores',
        diagnostics.topResponseScores.entries
            .map((entry) => '${entry.key}: ${entry.value.toStringAsFixed(1)}')
            .join(', '),
      ),
      (
        'Display text',
        diagnostics.displayTexts.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' | '),
      ),
      (
        'TTS text',
        diagnostics.ttsTexts.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' | '),
      ),
    ];
    return SectionCard(
      title: strings.t('assist.pipelineDiagnostics'),
      child: Column(
        children: <Widget>[
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 116,
                    child: Text(
                      value.$1,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(child: SelectableText(value.$2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.line,
    required this.slot,
    required this.feedback,
    required this.onAccepted,
    required this.onDismissed,
  });

  final OpenerLine line;
  final ConversationReelSlot? slot;
  final SuggestionFeedbackKind? feedback;
  final ValueChanged<OpenerLine> onAccepted;
  final ValueChanged<OpenerLine> onDismissed;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          onAccepted(line);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LineDetailScreen(lineId: line.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      switch (slot) {
                        ConversationReelSlot.standard =>
                          strings.t('assist.reel.standard'),
                        ConversationReelSlot.funny =>
                          strings.t('assist.reel.funny'),
                        ConversationReelSlot.flirty =>
                          strings.t('assist.reel.flirty'),
                        null => strings.t('assist.reel.standard'),
                      },
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    LineText(line: line, selectable: false),
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: strings.t('assist.accept'),
                    onPressed: () => onAccepted(line),
                    icon: Icon(
                      feedback == SuggestionFeedbackKind.accepted
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: strings.t('assist.dismiss'),
                    onPressed: () => onDismissed(line),
                    icon: Icon(
                      feedback == SuggestionFeedbackKind.dismissed
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: strings.t('assist.copy'),
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: line.japaneseText),
                    ),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionHistory extends StatelessWidget {
  const _SessionHistory({required this.turns});

  final List<ConversationTurn> turns;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    return SectionCard(
      title: strings.t('assist.sessionHistory'),
      child: Column(
        children: <Widget>[
          for (final turn in turns)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                turn.speaker == ConversationSpeaker.other
                    ? Icons.record_voice_over_outlined
                    : Icons.reply_rounded,
              ),
              title: Text(turn.transcript, maxLines: 2),
              trailing: Text(
                strings.t('assist.detected.${turn.language.name}'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
