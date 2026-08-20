import 'dart:convert';

import '../../domain/models/opener_line.dart';
import 'conversation_library.dart';

/// Parses the generated, manual-only multilingual conversation library.
class ConversationSeedLoader {
  const ConversationSeedLoader();

  List<OpenerLine> load({DateTime? createdAt}) {
    final decoded = jsonDecode(conversationLibraryJson);
    if (decoded is! Map<String, Object?> ||
        decoded['manualBrowsingOnly'] != true) {
      throw const FormatException(
        'Conversation library must declare manualBrowsingOnly.',
      );
    }
    final rawLines = decoded['lines'];
    if (rawLines is! List) {
      throw const FormatException('Conversation library has no lines array.');
    }
    final stamp = createdAt ?? DateTime.now().toUtc();
    return <OpenerLine>[
      for (final entry in rawLines)
        if (entry is Map<String, Object?>)
          OpenerLine.fromJson(entry).copyWith(
            manualOnly: true,
            isUserCreated: false,
            createdAt: stamp,
            updatedAt: stamp,
          )
        else
          throw const FormatException(
            'Conversation library entry is not an object.',
          ),
    ];
  }
}
