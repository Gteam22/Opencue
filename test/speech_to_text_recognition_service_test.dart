import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import
    'package:opencue/data/conversation/speech_to_text_recognition_service.dart';
import 'package:opencue/domain/conversation/conversation_models.dart';
import
    'package:opencue/domain/conversation/conversation_recognition_service.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  test('adapter delivers final words after capture has stopped', () async {
    final native = _FakeSpeech();
    final service = SpeechToTextRecognitionService(speech: native);
    final received = <String>[];
    await service.initialize(ConversationRecognitionCallbacks(
      onResult: (id, text, isFinal, confidence) => received.add('$id:$text'),
      onSoundLevel: (id, level) {},
      onStatus: (id, status) {},
      onError: (id, message, {required permanent, platformCode}) {},
    ));
    await service.start(
      sessionId: 1,
      language: ConversationInputLanguage.automatic,
    );
    native.status('notListening');
    native.result(_FinalResult());
    native.status('done');
    expect(received, <String>['1:Where are you from?']);
    await service.start(
      sessionId: 2,
      language: ConversationInputLanguage.automatic,
    );
    expect(native.listenCount, 2);
    await service.dispose();
  });

  test('adapter waits for pending native cancellation before restarting',
      () async {
    final native = _FakeSpeech();
    final service = SpeechToTextRecognitionService(speech: native);
    await service.initialize(ConversationRecognitionCallbacks(
      onResult: (id, text, isFinal, confidence) {},
      onSoundLevel: (id, level) {},
      onStatus: (id, status) {},
      onError: (id, message, {required permanent, platformCode}) {},
    ));
    await service.start(
      sessionId: 1,
      language: ConversationInputLanguage.automatic,
    );
    final gate = Completer<void>();
    native.cancelGate = gate;
    final cancellation = service.cancel(sessionId: 1);
    final restart = service.start(
      sessionId: 2,
      language: ConversationInputLanguage.automatic,
    );
    await Future<void>.delayed(Duration.zero);
    native.status('done');
    expect(native.listenCount, 1);
    gate.complete();
    await cancellation;
    await restart;
    expect(native.listenCount, 2);

    final secondGate = Completer<void>();
    native.cancelGate = secondGate;
    final secondCancellation = service.cancel(sessionId: 2);
    final stoppedRestart = service.start(
      sessionId: 3,
      language: ConversationInputLanguage.automatic,
    );
    final rejected = expectLater(stoppedRestart, throwsStateError);
    await service.cancel(sessionId: 3);
    secondGate.complete();
    await secondCancellation;
    await rejected;
    expect(native.listenCount, 2);
    await service.dispose();
  });
}

// Exercise the real adapter without depending on a platform microphone.
class _FakeSpeech implements SpeechToText {
  late void Function(String) status;
  late void Function(SpeechRecognitionResult) result;
  Completer<void>? cancelGate;
  int listenCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        status = invocation.namedArguments[#onStatus] as void Function(String);
        return Future<bool>.value(true);
      case #isListening:
        return false;
      case #locales:
        return Future<List<LocaleName>>.value(<LocaleName>[]);
      case #systemLocale:
        return Future<LocaleName?>.value(LocaleName('en-US', 'English'));
      case #listen:
        listenCount++;
        result = invocation.namedArguments[#onResult]
            as void Function(SpeechRecognitionResult);
        return Future<void>.value();
      case #cancel:
        return cancelGate?.future ?? Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class _FinalResult implements SpeechRecognitionResult {
  @override
  bool get finalResult => true;
  @override
  String get recognizedWords => 'Where are you from?';
  @override
  double get confidence => 0.95;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
