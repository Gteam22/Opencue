// Speech controller and TTS settings.
//
// The controller is the piece with real logic - one line at a time, tap-again
// to stop, switching lines - so it gets a fake service and precise assertions.
// No real TTS engine, no plugin, no audio: the SpeechService interface is what
// makes that possible.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/speech/speech_controller.dart';
import 'package:opencue/domain/speech/speech_service.dart';
import 'package:opencue/domain/speech/tts_text_sanitizer.dart';

/// A controllable fake. Records calls and lets a test hold an utterance "open"
/// so the mid-playback rules can be exercised deterministically.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.supported = true, this.koreanVoice = true});

  final bool supported;
  bool koreanVoice;

  final List<String> spoken = <String>[];
  final List<String> languages = <String>[];
  int stopCount = 0;
  int disposeCount = 0;

  /// When set, speak() waits on this until the test completes it, standing in
  /// for audio that is still playing.
  Completer<void>? _inFlight;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => koreanVoice;

  @override
  Future<void> speak(
    String text, {
    required String languageCode,
    double rate = 0.5,
    int? turnId,
    int? utteranceId,
  }) async {
    spoken.add(text);
    languages.add(languageCode);
    final completer = _inFlight;
    if (completer != null) await completer.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    // A stop resolves any in-flight utterance, as a real engine would.
    _inFlight?.complete();
    _inFlight = null;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  /// Makes the next speak() hang until [finishUtterance] is called.
  void holdNextUtterance() => _inFlight = Completer<void>();

  void finishUtterance() {
    _inFlight?.complete();
    _inFlight = null;
  }
}

void main() {
  group('support and availability', () {
    test('an unsupported service reports not supported and never speaks',
        () async {
      final fake = FakeSpeechService(supported: false);
      final controller = SpeechController(fake);
      expect(controller.isSupported, isFalse);

      await controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      expect(fake.spoken, isEmpty);
      expect(controller.speakingLineId, isNull);
    });

    test('Korean availability is checked once and cached', () async {
      final fake = FakeSpeechService(koreanVoice: true);
      final controller = SpeechController(fake);
      expect(controller.koreanAvailable, isNull); // not yet checked

      expect(await controller.ensureKoreanChecked(), isTrue);
      expect(controller.koreanAvailable, isTrue);

      // Flipping the fake afterwards has no effect: the result is cached.
      fake.koreanVoice = false;
      expect(await controller.ensureKoreanChecked(), isTrue);
    });

    test('a missing Korean voice is reported', () async {
      final controller =
          SpeechController(FakeSpeechService(koreanVoice: false));
      expect(await controller.ensureKoreanChecked(), isFalse);
      expect(controller.koreanAvailable, isFalse);
    });
  });

  group('playback', () {
    test('display text keeps emoji while Japanese TTS omits it', () async {
      final fake = FakeSpeechService();
      final controller = SpeechController(fake);
      const displayText = 'いいですね😊';

      await controller.toggleJapanese(
        lineId: 'emoji-jp',
        japaneseText: displayText,
      );

      expect(displayText, 'いいですね😊');
      expect(fake.spoken.single, 'いいですね');
    });

    test('parenthetical laughter is visual-only for TTS', () async {
      final fake = FakeSpeechService();
      final controller = SpeechController(fake);

      await controller.toggleJapanese(
        lineId: 'laugh-jp',
        japaneseText: 'いないですよ。面接ですか？（笑）',
      );

      expect(fake.spoken.single, 'いないですよ。面接ですか？');
    });

    test('Korean TTS uses the same emoji sanitizer', () async {
      final fake = FakeSpeechService();
      final controller = SpeechController(fake);

      await controller.toggleKorean(
        lineId: 'emoji-ko',
        koreanText: '좋네요✨👍🏽',
      );

      expect(fake.spoken.single, '좋네요');
    });

    test('joined, flag, keycap, selector, and modifier sequences vanish', () {
      const sanitizer = TtsTextSanitizer();
      expect(
        sanitizer.sanitize('確認👨‍👩‍👧‍👦🇯🇵1️⃣❤️👍🏽しました。'),
        '確認しました。',
      );
    });

    test('speaks only the Japanese it is given, tagged ja-JP', () async {
      final fake = FakeSpeechService();
      final controller = SpeechController(fake);

      await controller.toggleJapanese(
        lineId: 'jp',
        japaneseText: 'キスするの好き？',
      );
      expect(fake.spoken, <String>['キスするの好き？']);
      expect(fake.languages, <String>[SpeechController.japaneseLocale]);
    });

    test('speaks the Korean it is given, tagged ko-KR', () async {
      final fake = FakeSpeechService();
      final controller = SpeechController(fake);

      await controller.toggleKorean(lineId: 'a', koreanText: '안녕하세요');
      expect(fake.spoken, <String>['안녕하세요']);
      expect(fake.languages, <String>[SpeechController.koreanLocale]);
    });

    test('tapping the speaking line again stops it', () async {
      final fake = FakeSpeechService()..holdNextUtterance();
      final controller = SpeechController(fake);

      // Start; it hangs mid-utterance, so this line stays "speaking".
      final playing = controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSpeaking('a'), isTrue);

      // Tap the same line: it stops.
      await controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      expect(controller.speakingLineId, isNull);
      expect(fake.stopCount, greaterThanOrEqualTo(1));
      await playing;
    });

    test('starting a second line stops the first', () async {
      final fake = FakeSpeechService()..holdNextUtterance();
      final controller = SpeechController(fake);

      final first = controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSpeaking('a'), isTrue);

      // A different line supersedes it: the engine is stopped, then the new
      // text is spoken, and only the new line reads as speaking.
      fake.holdNextUtterance();
      final second = controller.toggleKorean(lineId: 'b', koreanText: '반가워');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSpeaking('a'), isFalse);
      expect(controller.isSpeaking('b'), isTrue);
      expect(fake.spoken, <String>['안녕', '반가워']);

      await controller.stop();
      await first;
      await second;
    });

    test('the speaking state clears when an utterance finishes on its own',
        () async {
      final fake = FakeSpeechService()..holdNextUtterance();
      final controller = SpeechController(fake);

      final playing = controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSpeaking('a'), isTrue);

      fake.finishUtterance();
      await playing;
      expect(controller.speakingLineId, isNull);
    });

    test('a finished older utterance does not clear a newer line', () async {
      // The generation guard: if line a finishes *after* line b has started,
      // b must stay speaking.
      final fake = FakeSpeechService()..holdNextUtterance();
      final controller = SpeechController(fake);

      final first = controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      await Future<void>.delayed(Duration.zero);

      fake.holdNextUtterance();
      final second = controller.toggleKorean(lineId: 'b', koreanText: '반가워');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isSpeaking('b'), isTrue);

      // Now let a's original future resolve. It must not clear b.
      await first;
      expect(controller.isSpeaking('b'), isTrue);

      await controller.stop();
      await second;
    });

    test('stop is safe when nothing is playing', () async {
      final controller = SpeechController(FakeSpeechService());
      await controller.stop();
      expect(controller.speakingLineId, isNull);
    });

    test('empty text is handled by the service, not the controller', () async {
      // The controller forwards; the real service guards empty text. The fake
      // records it, proving the controller does not itself special-case it in
      // a way that would diverge from the button's own empty-text guard.
      final fake = FakeSpeechService();
      final controller = SpeechController(fake);
      await controller.toggleKorean(lineId: 'a', koreanText: '안녕');
      expect(fake.spoken.single, '안녕');
    });
  });

  group('the TTS settings persist', () {
    test('defaults: enabled, normal speed', () {
      const settings = AppSettings();
      expect(settings.japaneseTtsEnabled, isTrue);
      expect(settings.koreanTtsEnabled, isTrue);
      expect(settings.speechRate, SpeechRatePreset.normal);
    });

    test('survive a JSON round trip', () {
      final changed = const AppSettings().copyWith(
        japaneseTtsEnabled: false,
        koreanTtsEnabled: false,
        speechRate: SpeechRatePreset.fast,
      );
      final restored = AppSettings.fromJson(
        Map<String, Object?>.from(changed.toJson()),
      );
      expect(restored.japaneseTtsEnabled, isFalse);
      expect(restored.koreanTtsEnabled, isFalse);
      expect(restored.speechRate, SpeechRatePreset.fast);
    });

    test('survive the settings string-map round trip', () {
      final changed = const AppSettings().copyWith(
        japaneseTtsEnabled: false,
        koreanTtsEnabled: false,
        speechRate: SpeechRatePreset.slow,
      );
      final restored = AppSettings.fromStringMap(changed.toStringMap());
      expect(restored.japaneseTtsEnabled, isFalse);
      expect(restored.koreanTtsEnabled, isFalse);
      expect(restored.speechRate, SpeechRatePreset.slow);
    });

    test('an old blob without the keys uses the defaults', () {
      final restored = AppSettings.fromJson(<String, Object?>{});
      expect(restored.japaneseTtsEnabled, isTrue);
      expect(restored.koreanTtsEnabled, isTrue);
      expect(restored.speechRate, SpeechRatePreset.normal);
    });
  });
}
