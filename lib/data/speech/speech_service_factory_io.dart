import 'dart:io';

import '../../domain/speech/speech_service.dart';
import 'flutter_tts_speech_service.dart';

/// Android is the only platform with a wired TTS implementation.
///
/// flutter_tts also supports iOS and Windows, but the Windows path is left off
/// deliberately: the desktop build has been broken by a plugin's native code
/// before, and speech is not a desktop feature the product needs. Enabling
/// Windows later means returning true here for it and testing the desktop
/// build, nothing more.
bool get platformHasSpeechImplementation => Platform.isAndroid;

SpeechService createPlatformSpeechService() => FlutterTtsSpeechService();
