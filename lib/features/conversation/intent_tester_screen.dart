import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/conversation/conversation_assist_controller.dart';
import '../../domain/conversation/conversation_models.dart';
import '../../domain/conversation/conversation_recognition_service.dart';
import '../shared/app_scope.dart';
import '../shared/widgets.dart';

class IntentTesterScreen extends StatefulWidget {
  const IntentTesterScreen({super.key});

  @override
  State<IntentTesterScreen> createState() => _IntentTesterScreenState();
}

class _IntentTesterScreenState extends State<IntentTesterScreen> {
  final TextEditingController _input = TextEditingController(
    text: '目の色が綺麗',
  );
  late final ConversationAssistController _controller;
  ConversationSuggestionResult? _result;

  @override
  void initState() {
    super.initState();
    _controller = ConversationAssistController(
      recognition: const NullConversationRecognitionService(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final state = AppScope.read(context);
    await _controller.onUtteranceFinalized(
      _input.text,
      library: state.lines,
      preferences: ConversationPreferences(
        adultContentEnabled:
            state.settings.conversationAssistAdultContentEnabled,
      ),
      source: FinalizedUtteranceSource.manual,
    );
    if (!mounted) return;
    setState(() {
      _result = _controller.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final result = _result;
    final diagnostics = _controller.diagnostics;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('intentTester.title'))),
      body: ListView(
        children: <Widget>[
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  key: const Key('intent-tester-input'),
                  controller: _input,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: strings.t('intentTester.input'),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _test(),
                ),
                const SizedBox(height: AppTheme.gap),
                FilledButton.icon(
                  onPressed: _test,
                  icon: const Icon(Icons.science_outlined),
                  label: Text(strings.t('intentTester.run')),
                ),
                if (result != null) ...<Widget>[
                  const SizedBox(height: 20),
                  _IntentResult(result: result),
                ],
                if (diagnostics != null) ...<Widget>[
                  const SizedBox(height: AppTheme.gap),
                  SectionCard(
                    title: strings.t('assist.pipelineDiagnostics'),
                    child: SelectableText(
                      'Intent: ${diagnostics.intentId}\n'
                      'Confidence: '
                      '${diagnostics.confidence.toStringAsFixed(2)}\n'
                      'Matcher: ${diagnostics.matcher.name}\n'
                      'Action: ${diagnostics.action.name}\n'
                      'Responses found: '
                      '${diagnostics.responsesFound}\n'
                      'Displayed: '
                      '${diagnostics.responsesDisplayed}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntentResult extends StatelessWidget {
  const _IntentResult({required this.result});

  final ConversationSuggestionResult result;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final matches = result.interpretation.intentMatches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionCard(
          title: strings.t('intentTester.detected'),
          child: matches.isEmpty
              ? Text(strings.t('intentTester.none'))
              : Column(
                  children: <Widget>[
                    for (final match in matches)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: SelectableText(match.id),
                        subtitle: Text(match.definition.description),
                        trailing: Text(
                          match.confidence.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppTheme.gap),
        SectionCard(
          title: strings.t('assist.suggestions'),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < result.suggestions.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    child: Text('${i + 1}'),
                  ),
                  title: SelectableText(
                    result.suggestions[i].line.japaneseText,
                  ),
                  subtitle: result.suggestions[i].line.englishMeaning == null
                      ? null
                      : Text(result.suggestions[i].line.englishMeaning!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
