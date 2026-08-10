import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/conversation/conversation_models.dart';
import '../../domain/conversation/conversation_response_engine.dart';
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
  final ConversationResponseEngine _engine =
      const ConversationResponseEngine();
  ConversationSuggestionResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _test() {
    final state = AppScope.read(context);
    setState(() {
      _result = _engine.suggest(
        transcript: _input.text,
        library: state.lines,
        preferences: ConversationPreferences(
          adultContentEnabled:
              state.settings.conversationAssistAdultContentEnabled,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final result = _result;
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
