import '../enums/enums.dart';
import '../models/context_snapshot.dart';
import '../models/opener_line.dart';
import 'recommendation_models.dart';

/// Ranks openers against a situation.
///
/// The engine is deterministic: the same library, situation, preferences and
/// recently-shown set always produce the same ordering, with ties broken by
/// line id. That makes every rule below directly testable and means the app
/// never appears to change its mind for no reason.
///
/// There are no Flutter imports here and there is no I/O. The engine does not
/// know where lines came from, so a future camera or smart-glasses context
/// provider can feed it a ContextSnapshot with no change to this file.
///
/// The engine does not promise that a recommendation will be well received. It
/// ranks lines for situational appropriateness, and nothing more.
class RecommendationEngine {
  const RecommendationEngine();

  // Weights are integers so that scoring is exactly reproducible.
  static const int wLocationMatch = 30;
  static const int wUniversalLine = 12;
  static const int wLocationMismatch = -26;
  static const int wCueMatch = 14;
  static const int wCueCap = 28;
  static const int wCueNotObserved = -20;
  static const int wActivityMatch = 8;
  static const int wGroupSizeMatch = 15;
  static const int wGroupSizeMismatch = -20;

  /// Nobody is in frame, so a line addressed at a person has nothing to
  /// address. Heavy enough to bury such lines without hard-excluding them:
  /// the scan may simply have missed someone standing off to the side.
  static const int wPersonSpecificLineNoPeople = -45;

  /// Two people, and the line speaks to both. This is the case the
  /// withOneFriend category exists for - the alternative is talking past
  /// somebody's friend as though they were not there.
  static const int wAddressesBothPeople = 18;

  /// Group size is unknown, and the line does not assume one.
  static const int wGroupNeutralWording = 10;
  static const int wSinglePersonLineWithCompanions = -40;
  static const int wNoiseMatch = 10;
  static const int wNoiseNear = 4;
  static const int wNoiseMismatch = -10;
  static const int wDirectnessStep = -9;
  static const int wDirectnessAligned = 10;
  static const int wTonePreference = 12;
  static const int wCategoryMatch = 10;
  static const int wFavorite = 6;
  static const int wHistoryCap = 15;
  static const int wRecentlyShown = -18;
  static const int wConversationStarted = 8;

  /// Length in characters at or below which a line counts as short.
  static const int shortLineThreshold = 14;

  /// Produces up to three recommendations plus alternates and exit lines.
  ///
  /// [recentlyShownIds] lets the caller rotate suggestions; ids in the set are
  /// penalised but not excluded, so a small library still returns something.
  RecommendationResult recommend({
    required ContextSnapshot context,
    required List<OpenerLine> library,
    RecommendationPreferences preferences = const RecommendationPreferences(),
    Set<String> recentlyShownIds = const <String>{},
  }) {
    final advisory = buildAdvisory(context);
    final excluded = <ExcludedLine>[];
    final scored = <ScoredLine>[];
    final exits = <ScoredLine>[];

    for (final line in library) {
      if (line.manualOnly) {
        excluded.add(ExcludedLine(line, ExclusionReason.manualOnly));
        continue;
      }
      if (!line.isValid) {
        excluded.add(ExcludedLine(line, ExclusionReason.invalidLine));
        continue;
      }
      if (line.isExitLine) {
        exits.add(_scoreExitLine(line, context));
        continue;
      }

      final exclusion = _exclusionFor(line, context);
      if (exclusion != null) {
        excluded.add(exclusion);
        continue;
      }

      scored.add(
        _score(
          line: line,
          context: context,
          preferences: preferences,
          recentlyShownIds: recentlyShownIds,
        ),
      );
    }

    _sortByScore(scored);
    _sortByScore(exits);

    // When the situation itself argues against approaching, the app does not
    // hand over openers anyway. The library stays browsable from the library
    // screen, and graceful exits stay available, but nothing here nudges the
    // user past the warning they just described.
    if (advisory.discouraged) {
      return RecommendationResult(
        advisory: advisory,
        primary: const <ScoredLine>[],
        alternates: const <ScoredLine>[],
        exitLines: exits.take(4).toList(),
        consideredCount: scored.length,
        excluded: excluded,
      );
    }

    final primary = _selectCategories(scored);
    final chosenIds = primary.map((s) => s.line.id).toSet();
    final alternates = scored
        .where((s) => !chosenIds.contains(s.line.id))
        .take(preferences.maxAlternates)
        .toList();

    return RecommendationResult(
      advisory: advisory,
      primary: primary,
      alternates: alternates,
      exitLines: exits.take(4).toList(),
      consideredCount: scored.length,
      excluded: excluded,
    );
  }

  /// Builds the advisory from the situation's hard signals.
  ApproachAdvisory buildAdvisory(ContextSnapshot context) {
    final reasons = context.activeAvoidConditions;
    if (reasons.isEmpty) return ApproachAdvisory.clear;
    return ApproachAdvisory(discouraged: true, reasons: reasons);
  }

  // -------------------------------------------------------------------
  // Exclusion
  // -------------------------------------------------------------------

  ExcludedLine? _exclusionFor(OpenerLine line, ContextSnapshot context) {
    // A line that names a situation to avoid is dropped when the situation
    // says that thing is true. This is a hard rule, not a penalty.
    final implied = context.impliedAvoidConditions;
    for (final avoid in line.avoidConditions) {
      if (implied.contains(avoid)) {
        return ExcludedLine(
          line,
          ExclusionReason.conflictingAvoidCondition,
          detail: avoid.name,
        );
      }
    }

    // Preconditions. A line that only works after eye contact is not offered
    // before eye contact has happened.
    for (final condition in line.conditions) {
      if (!_conditionMet(condition, context)) {
        return ExcludedLine(
          line,
          ExclusionReason.unmetCondition,
          detail: condition.name,
        );
      }
    }

    // A line about her drink makes no sense if no drink was observed. Only
    // applied when the user actually recorded some cues, so an empty cue
    // selection is treated as "unknown" rather than "nothing is present".
    if (context.observableCues.isNotEmpty &&
        line.observableCues.isNotEmpty &&
        line.observableCues.intersection(context.observableCues).isEmpty &&
        _cuesAreConcrete(line.observableCues)) {
      return ExcludedLine(
        line,
        ExclusionReason.requiredCueNotObserved,
        detail: line.observableCues.map((c) => c.name).join('/'),
      );
    }

    return null;
  }

  /// Cues that a line cannot be reworded around. A line about a dog needs a
  /// dog; a line tagged only with the softer cues can still be used.
  bool _cuesAreConcrete(Set<ObservableCue> cues) {
    const soft = <ObservableCue>{
      ObservableCue.eyeContact,
      ObservableCue.smile,
      ObservableCue.sharedActivity,
      ObservableCue.waiting,
      ObservableCue.groupHavingFun,
      ObservableCue.weather,
      ObservableCue.other,
    };
    return cues.any((c) => !soft.contains(c));
  }

  bool _conditionMet(UseCondition condition, ContextSnapshot context) {
    switch (condition) {
      case UseCondition.eyeContactEstablished:
        return context.eyeContact;
      case UseCondition.conversationStarted:
        return context.conversationAlreadyStarted;
      case UseCondition.priorRapport:
        // Rapport is only credible once the two are actually talking.
        return context.conversationAlreadyStarted;
      case UseCondition.personIsNotRushing:
        return !context.personIsMovingQuickly;
      case UseCondition.sharedActivityInProgress:
        return context.observableCues.contains(ObservableCue.sharedActivity) ||
            context.activity != null;
      case UseCondition.genuineKnowledgeOfSubject:
        // Only the user can know this, so it is never auto-excluded; it is
        // surfaced on the card as a condition to check.
        return true;
      case UseCondition.busyPublicSetting:
        return !context.isIsolatedOrUnsafeSetting;
    }
  }

  // -------------------------------------------------------------------
  // Scoring
  // -------------------------------------------------------------------

  ScoredLine _score({
    required OpenerLine line,
    required ContextSnapshot context,
    required RecommendationPreferences preferences,
    required Set<String> recentlyShownIds,
  }) {
    final factors = <ScoreFactor>[];

    // 1. Location.
    if (line.locations.isEmpty) {
      factors.add(
        const ScoreFactor(ScoreFactorCode.universalLine, wUniversalLine),
      );
    } else if (line.locations.contains(context.location)) {
      factors.add(ScoreFactor(
        ScoreFactorCode.locationMatch,
        wLocationMatch,
        detail: context.location.name,
      ));
    } else {
      factors.add(const ScoreFactor(
        ScoreFactorCode.locationMismatch,
        wLocationMismatch,
      ));
    }

    // 2. Observable cues.
    final matchedCues =
        line.observableCues.intersection(context.observableCues);
    if (matchedCues.isNotEmpty) {
      final raw = matchedCues.length * wCueMatch;
      factors.add(ScoreFactor(
        ScoreFactorCode.cueMatch,
        raw > wCueCap ? wCueCap : raw,
        detail: matchedCues.map((c) => c.name).join('/'),
      ));
    } else if (context.observableCues.isNotEmpty &&
        line.observableCues.isNotEmpty) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.cueNotObserved,
        wCueNotObserved,
      ));
    }

    // 3. Activity.
    if (context.activity != null &&
        line.activities.contains(context.activity)) {
      factors.add(ScoreFactor(
        ScoreFactorCode.activityMatch,
        wActivityMatch,
        detail: context.activity!.name,
      ));
    }

    // 4. Group size, and the rule about not addressing one person when they
    // are not by themselves.
    // Group size shapes *wording*, never permission. Nothing below this line
    // makes an approach more advisable; it only picks phrasing that does not
    // ignore somebody who is standing there. The advisory and the avoid
    // conditions are evaluated before any of this and are not affected by it.
    final groupNeutral = line.groupSizes.isEmpty ||
        line.groupSizes.length >= GroupSize.values.length - 1;

    if (context.groupSize == GroupSize.noneVisible &&
        line.addressesSinglePersonOnly) {
      // The place is visible and empty. A line aimed at one person has no one
      // to aim at; a remark about the venue still works.
      factors.add(const ScoreFactor(
        ScoreFactorCode.personSpecificLineWithNoPeople,
        wPersonSpecificLineNoPeople,
      ));
    } else if (context.hasCompanions && line.addressesSinglePersonOnly) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.singlePersonLineWithCompanions,
        wSinglePersonLineWithCompanions,
      ));
    } else if (context.groupSize == GroupSize.withOneFriend &&
        line.groupSizes.contains(GroupSize.withOneFriend) &&
        !line.addressesSinglePersonOnly) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.addressesBothPeople,
        wAddressesBothPeople,
      ));
    } else if (context.groupSize == GroupSize.unknown && groupNeutral) {
      // Uncertain group size prefers wording that does not commit either way,
      // rather than guessing and addressing the wrong number of people.
      factors.add(const ScoreFactor(
        ScoreFactorCode.groupNeutralWording,
        wGroupNeutralWording,
      ));
    } else if (line.groupSizes.isEmpty ||
        context.groupSize == GroupSize.unknown) {
      // No information either way; no adjustment.
    } else if (line.groupSizes.contains(context.groupSize)) {
      factors.add(ScoreFactor(
        ScoreFactorCode.groupSizeMatch,
        wGroupSizeMatch,
        detail: context.groupSize.name,
      ));
    } else {
      factors.add(const ScoreFactor(
        ScoreFactorCode.groupSizeMismatch,
        wGroupSizeMismatch,
      ));
    }

    // 5. Noise level.
    if (line.noiseLevels.isNotEmpty) {
      if (line.noiseLevels.contains(context.noiseLevel)) {
        factors.add(ScoreFactor(
          ScoreFactorCode.noiseMatch,
          wNoiseMatch,
          detail: context.noiseLevel.name,
        ));
      } else {
        final nearest = line.noiseLevels
            .map((n) => n.distanceTo(context.noiseLevel))
            .reduce((a, b) => a < b ? a : b);
        factors.add(nearest == 1
            ? const ScoreFactor(ScoreFactorCode.noiseNear, wNoiseNear)
            : const ScoreFactor(
                ScoreFactorCode.noiseMismatch,
                wNoiseMismatch,
              ));
      }
    }

    // 6. In a loud room a long line will not be heard. Reward brevity in
    // proportion to how loud it is.
    if (context.noiseLevel.isLoud) {
      final multiplier = context.noiseLevel == NoiseLevel.veryLoud ? 2 : 1;
      final length = line.displayLength;
      if (length <= shortLineThreshold) {
        factors.add(ScoreFactor(
          ScoreFactorCode.shortLineForLoudVenue,
          (shortLineThreshold - length + 4) * multiplier,
          detail: '$length',
        ));
      } else {
        final over = length - shortLineThreshold;
        final penalty = (over > 20 ? 20 : over) * multiplier;
        factors.add(ScoreFactor(
          ScoreFactorCode.longLineForLoudVenue,
          -penalty,
          detail: '$length',
        ));
      }
    }

    // 7. Directness relative to what the user asked for.
    final gap = (line.directness - preferences.desiredDirectness).abs();
    if (gap == 0) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.directnessAlignment,
        wDirectnessAligned,
      ));
    } else {
      factors.add(ScoreFactor(
        ScoreFactorCode.directnessMismatch,
        gap * wDirectnessStep,
        detail: '$gap',
      ));
    }

    // 8. Tone preference.
    if (preferences.preferredTones.isNotEmpty &&
        line.tones.intersection(preferences.preferredTones).isNotEmpty) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.tonePreference,
        wTonePreference,
      ));
    }

    // 9. Category alignment with the location, which helps hand-tagged
    // starter lines surface in the place they were written for.
    if (_categoryMatchesLocation(line.category, context.location)) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.categoryMatch,
        wCategoryMatch,
      ));
    }

    // 10. Once a conversation is under way, warmer lines fit better than
    // cold openers.
    if (context.conversationAlreadyStarted &&
        line.conditions.contains(UseCondition.conversationStarted)) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.conversationAlreadyStarted,
        wConversationStarted,
      ));
    }

    // 11. Favourites get a nudge, not a shortcut.
    if (line.isFavorite) {
      factors.add(const ScoreFactor(ScoreFactorCode.favorite, wFavorite));
    }

    // 12. Personal history, only once there are at least two recorded
    // outcomes. Below that the sample says nothing and is ignored.
    final signal = line.personalSignal;
    if (signal != null && signal != 0) {
      final delta = (signal * wHistoryCap).round();
      factors.add(ScoreFactor(
        delta > 0
            ? ScoreFactorCode.positiveHistory
            : ScoreFactorCode.cautiousHistory,
        delta,
        detail: '${line.positiveResults}+/${line.negativeResults}-',
      ));
    }

    // 13. Rotation, so the same three lines do not come back every time.
    if (recentlyShownIds.contains(line.id)) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.recentlyShown,
        wRecentlyShown,
      ));
    }

    var total = 0;
    for (final factor in factors) {
      total += factor.delta;
    }
    return ScoredLine(line: line, score: total, factors: factors);
  }

  /// Exit lines are ranked only on brevity and noise fit; they are never
  /// filtered by cue or condition, because the user may need one at any point.
  ScoredLine _scoreExitLine(OpenerLine line, ContextSnapshot context) {
    final factors = <ScoreFactor>[];
    if (line.noiseLevels.isEmpty ||
        line.noiseLevels.contains(context.noiseLevel)) {
      factors.add(const ScoreFactor(ScoreFactorCode.noiseMatch, wNoiseMatch));
    }
    if (context.noiseLevel.isLoud && line.displayLength <= shortLineThreshold) {
      factors.add(const ScoreFactor(
        ScoreFactorCode.shortLineForLoudVenue,
        wNoiseMatch,
      ));
    }
    var total = 0;
    for (final factor in factors) {
      total += factor.delta;
    }
    return ScoredLine(
      line: line,
      score: total,
      factors: factors,
      category: RecommendationCategory.gracefulExit,
    );
  }

  bool _categoryMatchesLocation(LineCategory category, LocationTag location) {
    switch (category) {
      case LineCategory.cafe:
        return location == LocationTag.cafe;
      case LineCategory.bar:
        return location == LocationTag.bar;
      case LineCategory.standingBar:
        return location == LocationTag.standingBar;
      case LineCategory.club:
        return location == LocationTag.club;
      case LineCategory.streetOrShopping:
        return location == LocationTag.street ||
            location == LocationTag.shoppingArea;
      case LineCategory.convenienceStore:
        return location == LocationTag.convenienceStore;
      case LineCategory.bookstore:
        return location == LocationTag.bookstore;
      case LineCategory.parkOrWaterfront:
        return location == LocationTag.park ||
            location == LocationTag.waterfront;
      case LineCategory.festival:
        return location == LocationTag.festival;
      case LineCategory.cosplayEvent:
        return location == LocationTag.cosplayEvent;
      case LineCategory.concert:
        return location == LocationTag.concert;
      case LineCategory.fitnessClass:
        return location == LocationTag.gym ||
            location == LocationTag.kickboxingClass;
      case LineCategory.meetupOrLanguageExchange:
        return location == LocationTag.meetup ||
            location == LocationTag.languageExchange;
      case LineCategory.party:
        return location == LocationTag.party;
      case LineCategory.waitingLine:
        return location == LocationTag.waitingLine;
      case LineCategory.transport:
        return location == LocationTag.trainStation ||
            location == LocationTag.publicTransport;
      case LineCategory.universal:
      case LineCategory.eyeContactEstablished:
      case LineCategory.weather:
      case LineCategory.withOneFriend:
      case LineCategory.contactExchange:
      case LineCategory.gracefulExit:
        return false;
    }
  }

  // -------------------------------------------------------------------
  // Category selection
  // -------------------------------------------------------------------

  /// Picks one distinct line for each of the three slots.
  ///
  /// Slots are filled safest-first, and a line already used is not reused, so
  /// a small or narrow library degrades to two or one card rather than
  /// repeating itself.
  List<ScoredLine> _selectCategories(List<ScoredLine> ranked) {
    final used = <String>{};
    final result = <ScoredLine>[];

    ScoredLine? pick(
      bool Function(OpenerLine line) predicate,
      RecommendationCategory category,
    ) {
      for (final scored in ranked) {
        if (used.contains(scored.line.id)) continue;
        if (!predicate(scored.line)) continue;
        used.add(scored.line.id);
        return scored.withCategory(category);
      }
      return null;
    }

    final safest = pick(_isSafeToned, RecommendationCategory.safest) ??
        pick((_) => true, RecommendationCategory.safest);
    if (safest != null) result.add(safest);

    final playful = pick(_isPlayfulToned, RecommendationCategory.playful);
    if (playful != null) result.add(playful);

    final direct = pick(_isDirectToned, RecommendationCategory.moreDirect);
    if (direct != null) result.add(direct);

    // If a tone slot was empty, backfill so the user still sees a useful
    // number of options rather than a single card.
    if (result.length < 3) {
      for (final scored in ranked) {
        if (result.length >= 3) break;
        if (used.contains(scored.line.id)) continue;
        used.add(scored.line.id);
        result.add(scored.withCategory(RecommendationCategory.alternative));
      }
    }
    return result;
  }

  static bool _isSafeToned(OpenerLine line) =>
      line.directness <= 3 &&
      line.tones.any((t) =>
          t == Tone.safe || t == Tone.friendly || t == Tone.situational);

  static bool _isPlayfulToned(OpenerLine line) =>
      line.tones.contains(Tone.playful);

  static bool _isDirectToned(OpenerLine line) =>
      line.tones.contains(Tone.direct) ||
      line.tones.contains(Tone.flirty) ||
      line.directness >= 4;

  /// Sorts by descending score, then ascending id so the order is stable.
  void _sortByScore(List<ScoredLine> lines) {
    lines.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.line.id.compareTo(b.line.id);
    });
  }
}
