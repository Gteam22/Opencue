import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/opener_line.dart';
import '../../l10n/app_localizations.dart';
import 'app_scope.dart';
import 'korean_speak_button.dart';

/// The OpenCue mark: a speech bubble with a small compass needle inside.
///
/// Drawn rather than shipped as a bitmap so it stays crisp at any size and
/// follows the theme's colours. The same shape is rendered to .ico for the
/// installer by tool/make_icon.py.
class OpenCueMark extends StatelessWidget {
  const OpenCueMark({this.size = 28, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(resolved)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * unit
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Speech bubble body.
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * unit, 4 * unit, 26 * unit, 20 * unit),
      Radius.circular(6 * unit),
    );
    canvas.drawRRect(bubble, stroke);

    // Tail, bottom left.
    final tail = Path()
      ..moveTo(10 * unit, 24 * unit)
      ..lineTo(10 * unit, 29 * unit)
      ..lineTo(16 * unit, 24 * unit);
    canvas.drawPath(tail, stroke);

    // Compass needle: a filled triangle pointing north-east, plus its
    // counterweight. Reads as "which way to go" rather than as decoration.
    final needle = Path()
      ..moveTo(21 * unit, 9.5 * unit)
      ..lineTo(15 * unit, 18.5 * unit)
      ..lineTo(19.5 * unit, 16 * unit)
      ..close();
    canvas.drawPath(needle, Paint()..color = color);

    final counterweight = Path()
      ..moveTo(21 * unit, 9.5 * unit)
      ..lineTo(16.5 * unit, 12 * unit)
      ..lineTo(19.5 * unit, 16 * unit)
      ..close();
    canvas.drawPath(
      counterweight,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * unit,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

/// A titled block with an outlined container. Used throughout the forms.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (title != null || subtitle != null)
              const SizedBox(height: AppTheme.gap),
            child,
          ],
        ),
      ),
    );
  }
}

/// A wrap of choice chips for picking exactly one enum value.
class SingleSelectChips<T extends Enum> extends StatelessWidget {
  const SingleSelectChips({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final value in values)
          ChoiceChip(
            label: Text(labelFor(value)),
            selected: selected == value,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }
}

/// A wrap of filter chips for picking any number of enum values.
class MultiSelectChips<T extends Enum> extends StatelessWidget {
  const MultiSelectChips({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T value) labelFor;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final value in values)
          FilterChip(
            label: Text(labelFor(value)),
            selected: selected.contains(value),
            onSelected: (isSelected) {
              final next = selected.toSet();
              if (isSelected) {
                next.add(value);
              } else {
                next.remove(value);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// The 1-5 directness slider with a written label for the current value.
class DirectnessSlider extends StatelessWidget {
  const DirectnessSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Slider(
          value: value.toDouble(),
          min: kMinDirectness.toDouble(),
          max: kMaxDirectness.toDouble(),
          divisions: kMaxDirectness - kMinDirectness,
          label: '$value',
          onChanged: (next) => onChanged(next.round()),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '$value · ${strings.directnessLabel(value)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The "this may not be a good time" banner.
///
/// Uses the theme's error container rather than a hand-picked red so it stays
/// legible in both themes, and states the specific selections that caused it.
class AdvisoryBanner extends StatelessWidget {
  const AdvisoryBanner({
    required this.reasons,
    this.onChangeSituation,
    this.onBrowseLibrary,
    super.key,
  });

  final List<AvoidCondition> reasons;
  final VoidCallback? onChangeSituation;
  final VoidCallback? onBrowseLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppScope.strings(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.error.withValues(
          alpha: 0.4,
        )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.pause_circle_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.t('advisory.title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              strings.t('advisory.becauseYouSelected'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            for (final reason in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '· ${strings.avoidCondition(reason)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            strings.t('advisory.explain'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onChangeSituation != null)
                FilledButton.tonal(
                  onPressed: onChangeSituation,
                  child: Text(strings.t('advisory.changeSituation')),
                ),
              if (onBrowseLibrary != null)
                OutlinedButton(
                  onPressed: onBrowseLibrary,
                  child: Text(strings.t('advisory.browseInstead')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Japanese line above, English meaning below.
///
/// The Japanese text always leads, in every language mode, because that is the
/// text the user is going to say out loud.
class LineText extends StatelessWidget {
  const LineText({
    required this.line,
    this.japaneseStyle,
    this.showEnglish = true,
    this.selectable = true,
    super.key,
  });

  final OpenerLine line;
  final TextStyle? japaneseStyle;
  final bool showEnglish;

  /// Whether the Japanese can be selected and copied.
  ///
  /// True where the line is the subject of the screen — the recommendation
  /// card, the detail screen — because copying the text you are about to say
  /// is genuinely useful. False inside a tappable row: SelectableText installs
  /// its own gesture recognisers and wins over an enclosing InkWell, so a tap
  /// on the text would start selecting it instead of opening the row.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.strings(context);
    final mode = strings.mode;
    final english = line.englishMeaning;
    final wantsEnglish =
        showEnglish && strings.showEnglishMeaning && english != null;
    final japaneseStyleResolved =
        japaneseStyle ?? AppTheme.japaneseBody(context);

    // A line is one entry in every language. In Both mode its Japanese and
    // Korean readings appear together, Japanese first, rather than as two
    // unrelated rows. When Korean is selected but this particular line has no
    // Korean twin, the Japanese still shows so the list never has a hole.
    final korean = line.koreanText;
    final showJapanese = mode.showsJapanese || korean == null;
    final showKorean = mode.showsKorean && korean != null;
    final romanization = line.koreanRomanization;
    final wantsRomanization = showKorean &&
        strings.showKoreanRomanization &&
        romanization != null &&
        romanization.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showJapanese)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (line.ttsJapanese)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: JapaneseSpeakButton(
                    lineId: line.id,
                    japaneseText: line.japaneseText,
                  ),
                ),
              Expanded(
                child: selectable
                    ? SelectableText(
                        line.japaneseText,
                        style: japaneseStyleResolved,
                      )
                    : Text(line.japaneseText, style: japaneseStyleResolved),
              ),
            ],
          ),
        if (showJapanese && showKorean) const SizedBox(height: 8),
        if (showKorean) ...<Widget>[
          // The speaker sits inline before the Korean, as the brief shows:
          //   🔊 안녕하세요. ...
          // It hides itself when speech is off or unavailable, so the Korean
          // still lays out cleanly on platforms and settings without TTS.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (line.ttsKorean)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: KoreanSpeakButton(
                    lineId: line.id,
                    koreanText: korean,
                  ),
                ),
              Expanded(
                child: selectable
                    ? SelectableText(
                        korean,
                        style: AppTheme.koreanBody(context),
                      )
                    : Text(korean, style: AppTheme.koreanBody(context)),
              ),
            ],
          ),
          if (wantsRomanization) ...<Widget>[
            const SizedBox(height: 2),
            Text(romanization, style: AppTheme.koreanRomanization(context)),
          ],
        ],
        if (wantsEnglish) ...<Widget>[
          const SizedBox(height: 6),
          Text(english, style: AppTheme.englishMeaning(context)),
        ],
      ],
    );
  }
}

/// A small outlined label used for categories, tones and counters.
class MetaTag extends StatelessWidget {
  const MetaTag(this.label, {this.icon, this.emphasised = false, super.key});

  final String label;
  final IconData? icon;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = emphasised
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final foreground = emphasised
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// A bulleted list of conditions, used for "use it when" and "avoid when".
class ConditionList extends StatelessWidget {
  const ConditionList({
    required this.title,
    required this.items,
    this.icon,
    this.isWarning = false,
    super.key,
  });

  final String title;
  final List<String> items;
  final IconData? icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = isWarning
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: Text(
              '· $item',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Standard empty state: an icon, a headline and a hint.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (hint != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Constrains content to a comfortable reading width on a wide monitor.
class ContentColumn extends StatelessWidget {
  const ContentColumn({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

/// Asks for confirmation before a destructive action.
///
/// Returns true only on an explicit confirm. Every caller in the app awaits
/// this before deleting anything.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  String? extraNote,
  required String confirmLabel,
  bool isDestructive = true,
}) async {
  final strings = AppScope.strings(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(body),
            if (extraNote != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                extraNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.t('action.cancel')),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Shows a short confirmation message.
void showBriefMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

/// Human-readable condition lists for a line, resolved through l10n.
List<String> useConditionLabels(AppLocalizations strings, OpenerLine line) =>
    line.conditions.map(strings.useCondition).toList();

List<String> avoidConditionLabels(AppLocalizations strings, OpenerLine line) =>
    line.avoidConditions.map(strings.avoidCondition).toList();
