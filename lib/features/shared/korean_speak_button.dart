library;

import 'package:flutter/material.dart';

import '../../domain/enums/enums.dart';
import '../../domain/speech/speech_controller.dart';
import 'app_scope.dart';

/// Concrete speech rates for each preset.
///
/// Lives here, in the presentation layer, so the domain enum stays free of
/// playback numbers. The values are flutter_tts's 0.0–1.0 scale, where about
/// 0.5 is a natural Android pace; slow and fast step either side of it.
extension SpeechRatePresetValue on SpeechRatePreset {
  double get rate {
    switch (this) {
      case SpeechRatePreset.slow:
        return 0.35;
      case SpeechRatePreset.normal:
        return 0.5;
      case SpeechRatePreset.fast:
        return 0.65;
    }
  }
}

/// Compact Japanese playback control. It sends only `japaneseText` to TTS.
class JapaneseSpeakButton extends StatefulWidget {
  const JapaneseSpeakButton({
    required this.lineId,
    required this.japaneseText,
    this.size = 20,
    super.key,
  });

  final String lineId;
  final String japaneseText;
  final double size;

  @override
  State<JapaneseSpeakButton> createState() => _JapaneseSpeakButtonState();
}

class _JapaneseSpeakButtonState extends State<JapaneseSpeakButton> {
  @override
  void initState() {
    super.initState();
    final controller = AppScope.speech(context);
    if (controller.isSupported) controller.ensureJapaneseChecked();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.speech(context);
    final settings = AppScope.of(context).settings;
    final strings = AppScope.strings(context);
    if (!controller.isSupported ||
        !settings.japaneseTtsEnabled ||
        widget.japaneseText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.japaneseAvailable == false) {
          return _IconButtonInline(
            icon: Icons.volume_off_outlined,
            size: widget.size,
            tooltip: strings.t('tts.japaneseUnavailable'),
            muted: true,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  strings.t('tts.japaneseUnavailableDetail'),
                ),
              ),
            ),
          );
        }
        final speaking = controller.isSpeakingLanguage(
          widget.lineId,
          SpeechController.japaneseLocale,
        );
        return _IconButtonInline(
          icon: speaking
              ? Icons.stop_circle_outlined
              : Icons.volume_up_outlined,
          size: widget.size,
          tooltip: speaking
              ? strings.t('tts.stop')
              : strings.t('tts.speakJapanese'),
          highlighted: speaking,
          onPressed: () => controller.toggleJapanese(
            lineId: widget.lineId,
            japaneseText: widget.japaneseText,
            rate: settings.speechRate.rate,
          ),
        );
      },
    );
  }
}

/// A small speak-aloud button for a Korean line.
///
/// Unobtrusive by design: an icon button sized to sit inline before the Korean
/// text. It reads the line's Korean Hangul aloud — never the romanization —
/// and shows a stop icon while that line is the one speaking. All the playback
/// rules (one at a time, tap-again-to-stop, switch lines) live in
/// [SpeechController]; this widget only reflects its state and forwards taps.
///
/// It renders nothing at all when speech is unsupported on the platform, when
/// the user has turned Korean TTS off, or when no Korean voice is installed, so
/// a caller can place it unconditionally next to any Korean line.
class KoreanSpeakButton extends StatefulWidget {
  const KoreanSpeakButton({
    required this.lineId,
    required this.koreanText,
    this.size = 20,
    super.key,
  });

  final String lineId;
  final String koreanText;
  final double size;

  @override
  State<KoreanSpeakButton> createState() => _KoreanSpeakButtonState();
}

class _KoreanSpeakButtonState extends State<KoreanSpeakButton> {
  @override
  void initState() {
    super.initState();
    // Kick off the one-time Korean availability check. The controller caches
    // it, so many buttons share a single platform query.
    final controller = AppScope.speech(context);
    if (controller.isSupported) {
      controller.ensureKoreanChecked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.speech(context);
    final settings = AppScope.of(context).settings;
    final strings = AppScope.strings(context);

    // Hidden entirely unless speech is supported, enabled, and the text exists.
    if (!controller.isSupported ||
        !settings.koreanTtsEnabled ||
        widget.koreanText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final available = controller.koreanAvailable;

        // No Korean voice on the device: a muted icon that, when tapped,
        // explains rather than silently doing nothing.
        if (available == false) {
          return _IconButtonInline(
            icon: Icons.volume_off_outlined,
            size: widget.size,
            tooltip: strings.t('tts.unavailable'),
            muted: true,
            onPressed: () => _showUnavailable(context, strings.t),
          );
        }

        final speaking = controller.isSpeakingLanguage(
          widget.lineId,
          SpeechController.koreanLocale,
        );
        return _IconButtonInline(
          icon: speaking
              ? Icons.stop_circle_outlined
              : Icons.volume_up_outlined,
          size: widget.size,
          tooltip: speaking
              ? strings.t('tts.stop')
              : strings.t('tts.speak'),
          highlighted: speaking,
          onPressed: () => controller.toggleKorean(
            lineId: widget.lineId,
            koreanText: widget.koreanText,
            rate: settings.speechRate.rate,
          ),
        );
      },
    );
  }

  void _showUnavailable(BuildContext context, String Function(String) t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('tts.unavailableDetail'))),
    );
  }
}

/// A compact icon button that sits inline with text without the default
/// 48-pixel tap target padding pushing everything apart.
class _IconButtonInline extends StatelessWidget {
  const _IconButtonInline({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
    this.muted = false,
  });

  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = muted
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : highlighted
            ? scheme.primary
            : scheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: size,
        containedInkWell: false,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
