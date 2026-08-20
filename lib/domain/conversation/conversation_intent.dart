enum ConversationFunction {
  question,
  compliment,
  tease,
  sharedInformation,
  invitation,
  softRejection,
  agreement,
  surprise,
  interest,
  greeting,
  thanks,
  apology,
  goodbye,
}

class ConversationIntentDefinition {
  const ConversationIntentDefinition({
    required this.id,
    required this.description,
    required this.examples,
    required this.keywords,
    required this.function,
    required this.contextTags,
    required this.responseHints,
    this.exclusions = const <String>[],
    this.priority = 50,
    this.confidenceThreshold = 0.58,
  });

  final String id;
  final String description;
  final List<String> examples;
  final List<String> keywords;
  final List<String> exclusions;
  final ConversationFunction function;
  final Set<String> contextTags;

  /// Terms used to retrieve a response family from the curated line library.
  /// These are data, not matching code, so expanding an intent does not touch
  /// the interpreter or UI.
  final List<String> responseHints;
  final int priority;
  final double confidenceThreshold;
}

class ConversationIntentMatch {
  const ConversationIntentMatch({
    required this.definition,
    required this.confidence,
    required this.reasons,
  });

  final ConversationIntentDefinition definition;
  final double confidence;
  final List<String> reasons;

  String get id => definition.id;
  ConversationFunction get function => definition.function;
}

