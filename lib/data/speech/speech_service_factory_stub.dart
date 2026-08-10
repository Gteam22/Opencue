import '../../domain/speech/speech_service.dart';

/// Web fallback: references neither dart:io nor flutter_tts, so a web build
/// never pulls in the plugin. Speech is unsupported here.
bool get platformHasSpeechImplementation => false;

SpeechService createPlatformSpeechService() => const NullSpeechService();
