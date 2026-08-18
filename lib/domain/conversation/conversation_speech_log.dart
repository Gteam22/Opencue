import 'package:flutter/foundation.dart';

typedef ConversationSpeechLogSink = void Function(String message);

/// Structured, temporary lifecycle logging for Listen Mode stabilization.
///
/// Every line contains a UTC timestamp, the controller/adapter state and the
/// immutable session id so a physical-device trace can be read as one timeline.
class ConversationSpeechLogger {
  const ConversationSpeechLogger({this.sink});

  final ConversationSpeechLogSink? sink;

  void event({
    required int sessionId,
    required String state,
    required String event,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final fields = details.entries
        .map((entry) => '${entry.key}=${entry.value ?? '-'}')
        .join(' ');
    final line = '${DateTime.now().toUtc().toIso8601String()} '
        '[OpenCueSpeech] session=$sessionId state=$state event=$event'
        '${fields.isEmpty ? '' : ' $fields'}';
    final target = sink;
    if (target != null) {
      target(line);
    } else {
      debugPrint(line);
    }
  }

  void turn({
    required int turnId,
    required String state,
    required String event,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final fields = details.entries
        .map((entry) => '${entry.key}=${entry.value ?? '-'}')
        .join(' ');
    final line = '${DateTime.now().toUtc().toIso8601String()} '
        '[OpenCueListen] turn=$turnId state=$state event=$event'
        '${fields.isEmpty ? '' : ' $fields'}';
    final target = sink;
    if (target != null) {
      target(line);
    } else {
      debugPrint(line);
    }
  }
}
