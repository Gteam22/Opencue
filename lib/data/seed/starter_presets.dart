import '../../domain/context/context_draft.dart';
import '../../domain/context/radial_menu_tree.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/context_preset.dart';
import '../../domain/scan/venue_category.dart';

/// The presets installed on first run.
///
/// These are **starter rows, not fixtures**: they are written to
/// `context_presets` like any other preset and can be renamed, reordered,
/// favourited or deleted. Nothing reads this list at runtime once the seed has
/// run, and no code path treats these eight ids as special.
///
/// Their [ContextPreset.name] is a localization key rather than literal text,
/// because a preset the app wrote should follow the interface language while a
/// preset the user typed should not.
class StarterPresets {
  const StarterPresets();

  static const String idPrefix = 'starter-preset-';

  List<ContextPreset> load() {
    final entries = <_Entry>[
      // Café, one person, quiet.
      _Entry(
        'cafeQuiet',
        (d) => d
            .apply(const SetLocation(LocationTag.cafe))
            .apply(const SetGroupSize(GroupSize.alone))
            .apply(const SetNoiseLevel(NoiseLevel.quiet))
            .apply(const ToggleCue(ObservableCue.drink)),
      ),
      // Bar, two people, normal noise.
      _Entry(
        'barPair',
        (d) => d
            .apply(const SetLocation(LocationTag.bar))
            .apply(const SetGroupSize(GroupSize.withOneFriend))
            .apply(const SetNoiseLevel(NoiseLevel.normal)),
      ),
      // Standing bar, small group.
      _Entry(
        'standingBarGroup',
        (d) => d
            .apply(const SetLocation(LocationTag.standingBar))
            .apply(const SetGroupSize(GroupSize.smallGroup))
            .apply(const SetNoiseLevel(NoiseLevel.loud))
            .apply(const ToggleCue(ObservableCue.groupHavingFun)),
      ),
      // Subway platform, waiting.
      _Entry(
        'subwayWaiting',
        (d) => d
            .apply(const SetLocation(
              LocationTag.trainStation,
              venue: VenueCategory.trainPlatform,
            ))
            .apply(const SetActivity(ActivityTag.waiting))
            .apply(const ToggleCue(ObservableCue.waiting)),
      ),
      // Cosplay event, taking photographs.
      _Entry(
        'cosplayPhotos',
        (d) => d
            .apply(const SetLocation(LocationTag.cosplayEvent))
            .apply(const SetActivity(ActivityTag.photographing))
            .apply(const ToggleCue(ObservableCue.cosplay))
            .apply(const ToggleCue(ObservableCue.takingPhotographs)),
      ),
      // Gym, shared activity.
      _Entry(
        'gymShared',
        (d) => d
            .apply(const SetLocation(LocationTag.gym))
            .apply(const SetActivity(ActivityTag.exercising))
            .apply(const ToggleCue(ObservableCue.sharedActivity)),
      ),
      // Festival, two people.
      _Entry(
        'festivalPair',
        (d) => d
            .apply(const SetLocation(LocationTag.festival))
            .apply(const SetGroupSize(GroupSize.withOneFriend))
            .apply(const SetNoiseLevel(NoiseLevel.loud))
            .apply(const ToggleCue(ObservableCue.festivalItem)),
      ),
      // Park, dog visible.
      _Entry(
        'parkDog',
        (d) => d
            .apply(const SetLocation(LocationTag.park))
            .apply(const SetActivity(ActivityTag.walking))
            .apply(const ToggleCue(ObservableCue.dog)),
      ),
    ];

    // A fixed created-at keeps the seed deterministic, which the seed test
    // relies on; the ordering the user sees comes from sort_order anyway.
    final created = DateTime.utc(2026, 1, 1);
    return <ContextPreset>[
      for (var index = 0; index < entries.length; index++)
        ContextPreset(
          id: '$idPrefix${entries[index].key}',
          name: 'preset.starter.${entries[index].key}',
          draft: entries[index].build(ContextDraft.empty()),
          isStarter: true,
          sortOrder: index,
          createdAt: created,
        ),
    ];
  }
}

class _Entry {
  const _Entry(this.key, this.build);
  final String key;
  final ContextDraft Function(ContextDraft) build;
}
