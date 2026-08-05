import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/context_snapshot.dart';
import 'package:opencue/domain/models/interaction_record.dart';
import 'package:opencue/domain/models/opener_line.dart';

import 'helpers.dart';

void main() {
  group('OpenerLine serialization', () {
    test('survives a JSON round trip with every field populated', () {
      final original = line(
        'round-trip',
        japanese: 'その本、面白そうですね。',
        english: 'That book looks interesting.',
        category: LineCategory.bookstore,
        locations: <LocationTag>{LocationTag.bookstore, LocationTag.cafe},
        activities: <ActivityTag>{ActivityTag.browsing, ActivityTag.reading},
        cues: <ObservableCue>{ObservableCue.book, ObservableCue.eyeContact},
        groupSizes: <GroupSize>{GroupSize.alone},
        noiseLevels: <NoiseLevel>{NoiseLevel.quiet},
        tones: <Tone>{Tone.safe, Tone.situational},
        directness: 3,
        conditions: <UseCondition>{UseCondition.genuineKnowledgeOfSubject},
        avoidConditions: <AvoidCondition>{
          AvoidCondition.headphonesOn,
          AvoidCondition.personWorking,
        },
        followUp: 'Ask what else they have read by the author.',
        notes: 'Only if you have actually read it.',
        isFavorite: true,
        isUserCreated: true,
        timesShown: 7,
        timesUsed: 3,
        positive: 2,
        neutral: 1,
        negative: 0,
      );

      final restored = OpenerLine.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.japaneseText, original.japaneseText);
      expect(restored.englishMeaning, original.englishMeaning);
      expect(restored.category, original.category);
      expect(restored.locations, original.locations);
      expect(restored.activities, original.activities);
      expect(restored.observableCues, original.observableCues);
      expect(restored.groupSizes, original.groupSizes);
      expect(restored.noiseLevels, original.noiseLevels);
      expect(restored.tones, original.tones);
      expect(restored.directness, original.directness);
      expect(restored.conditions, original.conditions);
      expect(restored.avoidConditions, original.avoidConditions);
      expect(restored.followUpSuggestion, original.followUpSuggestion);
      expect(restored.notes, original.notes);
      expect(restored.isFavorite, isTrue);
      expect(restored.timesShown, 7);
      expect(restored.timesUsed, 3);
      expect(restored.positiveResults, 2);
      expect(restored.neutralResults, 1);
      expect(restored.createdAt.toUtc(), original.createdAt.toUtc());
    });

    test('survives a database row round trip', () {
      final original = line(
        'db-round-trip',
        locations: <LocationTag>{LocationTag.bar, LocationTag.standingBar},
        tones: <Tone>{Tone.playful},
      );
      final restored = OpenerLine.fromDbRow(original.toDbMap());
      expect(restored.locations, original.locations);
      expect(restored.tones, original.tones);
      expect(restored.japaneseText, original.japaneseText);
    });

    test('drops enum names it does not recognise instead of throwing', () {
      // Forward compatibility: a file written by a later version may carry tags
      // this build has never heard of, and losing one tag is a far better
      // outcome than refusing the whole line.
      final json = line('forward').toJson();
      json['locations'] = <String>['bar', 'spaceStation'];
      json['tones'] = <String>['playful', 'telepathic'];

      final restored = OpenerLine.fromJson(json);

      expect(restored.locations, <LocationTag>{LocationTag.bar});
      expect(restored.tones, <Tone>{Tone.playful});
    });

    test('reports validation problems as localization keys', () {
      final broken = line('broken', japanese: '   ');
      final problems = broken.validationErrors();
      expect(problems, isNotEmpty);
      expect(problems.first, startsWith('validation.'));
    });

    test('clamps directness into range on the way in', () {
      final json = line('clamp').toJson();
      json['directness'] = 99;
      expect(OpenerLine.fromJson(json).directness, kMaxDirectness);
      json['directness'] = -4;
      expect(OpenerLine.fromJson(json).directness, kMinDirectness);
    });

    test('withRecordedOutcome increments only the matching counter', () {
      final start = line('counters');
      final positive = start.withRecordedOutcome(InteractionOutcome.positive);
      expect(positive.timesUsed, 1);
      expect(positive.positiveResults, 1);
      expect(positive.neutralResults, 0);
      expect(positive.negativeResults, 0);

      final then = positive.withRecordedOutcome(
        InteractionOutcome.unreceptive,
      );
      expect(then.timesUsed, 2);
      expect(then.positiveResults, 1);
      expect(then.negativeResults, 1);
    });

    test('personalSignal stays null until there are enough outcomes', () {
      expect(line('none').personalSignal, isNull);
      expect(line('one', positive: 1).personalSignal, isNull);
      expect(line('two', positive: 2).personalSignal, isNotNull);
    });

    test('addressesSinglePersonOnly reflects the group tags', () {
      final solo = line('solo', groupSizes: <GroupSize>{GroupSize.alone});
      final pair = line(
        'pair',
        groupSizes: <GroupSize>{GroupSize.alone, GroupSize.withOneFriend},
      );
      expect(solo.addressesSinglePersonOnly, isTrue);
      expect(pair.addressesSinglePersonOnly, isFalse);
    });
  });

  group('ContextSnapshot serialization', () {
    test('survives a JSON round trip', () {
      final original = situation(
        location: LocationTag.club,
        activity: ActivityTag.dancing,
        groupSize: GroupSize.smallGroup,
        noiseLevel: NoiseLevel.veryLoud,
        cues: <ObservableCue>{
          ObservableCue.groupHavingFun,
          ObservableCue.music,
        },
        eyeContact: true,
        userNotes: 'Near the bar, not the floor.',
      );

      final restored = ContextSnapshot.fromJson(original.toJson());

      expect(restored.location, LocationTag.club);
      expect(restored.activity, ActivityTag.dancing);
      expect(restored.groupSize, GroupSize.smallGroup);
      expect(restored.noiseLevel, NoiseLevel.veryLoud);
      expect(restored.observableCues, original.observableCues);
      expect(restored.eyeContact, isTrue);
      expect(restored.userNotes, 'Near the bar, not the floor.');
      expect(restored.source, ContextSource.manual);
    });

    test('defaults source to manual when the field is absent', () {
      final json = situation().toJson();
      json.remove('source');
      expect(ContextSnapshot.fromJson(json).source, ContextSource.manual);
    });

    test('accepts a source this build cannot produce yet', () {
      // The future scan sources must deserialize now, so a record written by a
      // later version stays readable in history rather than being dropped.
      final json = situation().toJson();
      json['source'] = 'smartGlasses';
      expect(
        ContextSnapshot.fromJson(json).source,
        ContextSource.smartGlasses,
      );
    });

    test('activeAvoidConditions lists exactly the five hard flags', () {
      expect(situation().activeAvoidConditions, isEmpty);
      expect(
        situation(working: true).activeAvoidConditions,
        contains(AvoidCondition.personWorking),
      );
      final all = situation(
        occupied: true,
        working: true,
        headphones: true,
        movingQuickly: true,
        isolated: true,
      );
      expect(all.activeAvoidConditions.length, 5);
      expect(all.discouragesApproach, isTrue);
    });

    test('carries no field describing the other person beyond behaviour', () {
      // A guard against the model growing an attractiveness, availability or
      // receptiveness field later. Every key here is either about the setting
      // or about observable behaviour.
      const permitted = <String>{
        'location',
        'activity',
        'groupSize',
        'noiseLevel',
        'observableCues',
        'eyeContact',
        'conversationAlreadyStarted',
        'personAppearsOccupied',
        'personIsMovingQuickly',
        'isWorking',
        'isUsingHeadphones',
        'isIsolatedOrUnsafeSetting',
        'userNotes',
        'createdAt',
        'source',
      };
      expect(situation().toJson().keys.toSet(), permitted);
    });
  });

  group('InteractionRecord serialization', () {
    test('survives a JSON round trip including the nested context', () {
      final original = record(
        'rec-1',
        'line-1',
        outcome: InteractionOutcome.neutral,
        context: situation(location: LocationTag.cafe),
        notes: 'Short exchange, both left it there.',
      );

      final restored = InteractionRecord.fromJson(original.toJson());

      expect(restored.id, 'rec-1');
      expect(restored.openerLineId, 'line-1');
      expect(restored.outcome, InteractionOutcome.neutral);
      expect(restored.contextSnapshot?.location, LocationTag.cafe);
      expect(restored.optionalNotes, original.optionalNotes);
      expect(restored.dateUsed.toUtc(), original.dateUsed.toUtc());
    });

    test('survives a database row round trip', () {
      final original = record(
        'rec-2',
        'line-2',
        context: situation(location: LocationTag.park),
      );
      final restored = InteractionRecord.fromDbRow(original.toDbMap());
      expect(restored.contextSnapshot?.location, LocationTag.park);
      expect(restored.outcome, original.outcome);
    });

    test('degrades to a null context rather than failing on a bad blob', () {
      // The snapshot is stored as one JSON column. A corrupt value should cost
      // the context of one record, not the ability to read history at all.
      final row = record('rec-3', 'line-3').toDbMap();
      row['context_snapshot'] = 'not json at all {{{';
      final restored = InteractionRecord.fromDbRow(row);
      expect(restored.contextSnapshot, isNull);
      expect(restored.id, 'rec-3');
    });

    test('rejects a record with no line id', () {
      expect(
        () => InteractionRecord.fromJson(<String, Object?>{'id': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AppSettings serialization', () {
    test('survives a JSON round trip', () {
      const original = AppSettings(
        languageMode: LanguageMode.japanese,
        themePreference: AppThemePreference.dark,
        defaultDirectness: 4,
        includeHistoryInExport: true,
      );
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.languageMode, LanguageMode.japanese);
      expect(restored.themePreference, AppThemePreference.dark);
      expect(restored.defaultDirectness, 4);
      expect(restored.includeHistoryInExport, isTrue);
    });

    test('defaults to not exporting history', () {
      // The notes attached to history are the most sensitive thing the app
      // holds, so including them has to be a deliberate choice.
      expect(AppSettings.defaults.includeHistoryInExport, isFalse);
    });

    test('falls back to defaults on unreadable values', () {
      final restored = AppSettings.fromJson(<String, Object?>{
        'languageMode': 'klingon',
        'themePreference': 42,
        'defaultDirectness': 'lots',
      });
      expect(restored.languageMode, AppSettings.defaults.languageMode);
      expect(restored.themePreference, AppSettings.defaults.themePreference);
      expect(
        restored.defaultDirectness,
        AppSettings.defaults.defaultDirectness,
      );
    });
  });
}
