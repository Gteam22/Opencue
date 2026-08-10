/// Pure-Dart VAD timing logic, kept independent from microphone and widgets so
/// silence behaviour is deterministic in tests.
class VoiceActivityTracker {
  VoiceActivityTracker({
    this.silenceDuration = const Duration(milliseconds: 1400),
    this.minimumSpeechDuration = const Duration(milliseconds: 180),
    this.levelMargin = 4.0,
  });

  final Duration silenceDuration;
  final Duration minimumSpeechDuration;
  final double levelMargin;

  double? _noiseFloor;
  DateTime? _speechStartedAt;
  DateTime? _lastVoiceAt;

  bool get heardSpeech => _speechStartedAt != null;

  void reset() {
    _noiseFloor = null;
    _speechStartedAt = null;
    _lastVoiceAt = null;
  }

  void addLevel(double level, DateTime now) {
    final floor = _noiseFloor;
    if (floor == null) {
      _noiseFloor = level;
      return;
    }
    final voiced = level >= floor + levelMargin;
    if (voiced) {
      _speechStartedAt ??= now;
      _lastVoiceAt = now;
    } else if (!heardSpeech) {
      // Slowly adapt before speech begins, never chasing a sudden voice peak.
      _noiseFloor = floor * 0.9 + level * 0.1;
    }
  }

  bool shouldStop(DateTime now) {
    final started = _speechStartedAt;
    final lastVoice = _lastVoiceAt;
    if (started == null || lastVoice == null) return false;
    if (now.difference(started) < minimumSpeechDuration) return false;
    return now.difference(lastVoice) >= silenceDuration;
  }
}

