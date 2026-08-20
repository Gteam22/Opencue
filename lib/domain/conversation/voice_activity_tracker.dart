/// Pure-Dart VAD timing logic, kept independent from microphone and widgets so
/// silence behaviour is deterministic in tests.
class VoiceActivityTracker {
  VoiceActivityTracker({
    this.silenceDuration = const Duration(milliseconds: 700),
    this.minimumSpeechDuration = const Duration(milliseconds: 180),
    this.speechDebounce = const Duration(milliseconds: 100),
    this.preRollDuration = const Duration(milliseconds: 300),
    this.levelMargin = 3.5,
  });

  final Duration silenceDuration;
  final Duration minimumSpeechDuration;
  final Duration speechDebounce;

  /// The recognizer is already running while VAD waits, so the platform STT
  /// engine retains this lead-in before OpenCue declares speech active. Raw
  /// PCM is never exposed by `speech_to_text`, so this is transcript pre-roll
  /// rather than a separately retained audio buffer.
  final Duration preRollDuration;
  final double levelMargin;

  double? _noiseFloor;
  double? _smoothedLevel;
  DateTime? _voiceCandidateAt;
  DateTime? _speechStartedAt;
  DateTime? _lastVoiceAt;

  bool get heardSpeech => _speechStartedAt != null;
  double? get noiseFloor => _noiseFloor;
  DateTime? get speechStartedAt => _speechStartedAt;

  void reset() {
    _noiseFloor = null;
    _smoothedLevel = null;
    _voiceCandidateAt = null;
    _speechStartedAt = null;
    _lastVoiceAt = null;
  }

  void addLevel(double level, DateTime now) {
    final previousSmoothed = _smoothedLevel;
    final smoothed = previousSmoothed == null
        ? level
        : previousSmoothed * 0.65 + level * 0.35;
    _smoothedLevel = smoothed;
    final floor = _noiseFloor;
    if (floor == null) {
      _noiseFloor = smoothed;
      return;
    }

    // Once speech begins, use hysteresis so normal syllable gaps do not look
    // like end-of-turn silence. Before speech, require sustained energy above
    // an adaptive room-noise floor to debounce clinks and microphone pops.
    final margin = heardSpeech ? levelMargin * 0.55 : levelMargin;
    final voiced = smoothed >= floor + margin ||
        level >= floor + margin * 1.15;
    if (voiced) {
      _voiceCandidateAt ??= now;
      if (heardSpeech ||
          now.difference(_voiceCandidateAt!) >= speechDebounce) {
        _speechStartedAt ??= _voiceCandidateAt;
        _lastVoiceAt = now;
      }
    } else if (!heardSpeech) {
      _voiceCandidateAt = null;
      // Adapt slowly while waiting, without chasing a sudden voice peak.
      _noiseFloor = floor * 0.94 + smoothed * 0.06;
    }
  }

  /// Treats a native partial transcript as authoritative speech evidence.
  /// This is a fallback for devices whose RMS scale is too compressed for
  /// energy-only detection; the recognizer has already retained the lead-in.
  void confirmSpeech(DateTime now) {
    _voiceCandidateAt ??= now.subtract(preRollDuration);
    _speechStartedAt ??= _voiceCandidateAt;
    _lastVoiceAt = now;
  }

  bool shouldStop(DateTime now) {
    final started = _speechStartedAt;
    final lastVoice = _lastVoiceAt;
    if (started == null || lastVoice == null) return false;
    if (now.difference(started) < minimumSpeechDuration) return false;
    return now.difference(lastVoice) >= silenceDuration;
  }
}
