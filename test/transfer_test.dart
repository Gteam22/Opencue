import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/core/app_info.dart';
import 'package:opencue/data/transfer/transfer_service.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/interaction_record.dart';
import 'package:opencue/domain/models/opener_line.dart';

import 'helpers.dart';

void main() {
  final service = TransferService();

  Map<String, Object?> decode(String raw) =>
      jsonDecode(raw) as Map<String, Object?>;

  group('export', () {
    test('writes the documented envelope', () {
      final json = decode(
        service.buildExportJson(
          lines: <OpenerLine>[line('a')],
          settings: AppSettings.defaults,
          now: testTime,
        ),
      );
      expect(json['schemaVersion'], AppInfo.transferSchemaVersion);
      expect(json['app'], AppInfo.appName);
      expect(json['appVersion'], AppInfo.version);
      expect(json['exportedAt'], testTime.toIso8601String());
      expect(json['settings'], isA<Map<String, Object?>>());
      expect(json['lines'], isA<List<Object?>>());
      expect(json['interactions'], isEmpty);
    });

    test('exports user lines and favourites but not the untouched starter set',
        () {
      // Round-tripping the whole starter library would bloat every backup and
      // guarantee id collisions on import.
      final raw = service.buildExportJson(
        lines: <OpenerLine>[
          line('mine', isUserCreated: true),
          line('starred-starter', isUserCreated: false, isFavorite: true),
          line('plain-starter', isUserCreated: false),
        ],
        settings: AppSettings.defaults,
      );
      final ids = (decode(raw)['lines']! as List<Object?>)
          .map((e) => (e! as Map<String, Object?>)['id'])
          .toList();
      expect(ids, <String>['mine', 'starred-starter']);
    });

    test('includeAllLines overrides that', () {
      final raw = service.buildExportJson(
        lines: <OpenerLine>[
          line('mine'),
          line('plain-starter', isUserCreated: false),
        ],
        settings: AppSettings.defaults,
        includeAllLines: true,
      );
      expect(decode(raw)['lines'], hasLength(2));
    });

    test('omits history unless asked', () {
      final interactions = <InteractionRecord>[record('r', 'a')];
      final without = service.buildExportJson(
        lines: <OpenerLine>[line('a')],
        settings: AppSettings.defaults,
        interactions: interactions,
      );
      expect(decode(without)['interactions'], isEmpty);

      final withHistory = service.buildExportJson(
        lines: <OpenerLine>[line('a')],
        settings: AppSettings.defaults,
        interactions: interactions,
        includeInteractions: true,
      );
      expect(decode(withHistory)['interactions'], hasLength(1));
    });

    test('its own output imports cleanly', () {
      final raw = service.buildExportJson(
        lines: <OpenerLine>[
          line('a', locations: <LocationTag>{LocationTag.bar}),
          line('b', tones: <Tone>{Tone.playful, Tone.direct}),
        ],
        settings: const AppSettings(defaultDirectness: 4),
        interactions: <InteractionRecord>[
          record('r', 'a', context: situation(location: LocationTag.bar)),
        ],
        includeInteractions: true,
      );
      final result = service.parse(raw);
      expect(result.isSuccess, isTrue, reason: result.errors.join('; '));
      expect(result.payload!.lines, hasLength(2));
      expect(result.payload!.interactions, hasLength(1));
      expect(result.payload!.settings?.defaultDirectness, 4);
      expect(
        result.payload!.lines.first.locations,
        <LocationTag>{LocationTag.bar},
      );
    });
  });

  group('import validation', () {
    test('never throws, whatever it is handed', () {
      const nasty = <String>[
        '',
        '   ',
        'not json',
        '[]',
        '{}',
        '{"schemaVersion": "one"}',
        '{"schemaVersion": 1}',
        '{"schemaVersion": 1, "lines": "nope"}',
        '{"schemaVersion": 1, "lines": [], "interactions": {}}',
        '{"schemaVersion": 1, "lines": [null, 3, "x"]}',
        '{"schemaVersion": 99999, "lines": []}',
        '{"schemaVersion": 1, "lines": [{"id": "a"}]}',
      ];
      for (final input in nasty) {
        // The assertion is simply that this returns rather than blows up.
        final result = service.parse(input);
        expect(
          result.isSuccess || result.errors.isNotEmpty,
          isTrue,
          reason: 'no verdict for: $input',
        );
      }
    });

    test('reports an empty file', () {
      final result = service.parse('');
      expect(result.isSuccess, isFalse);
      expect(result.errors.first, startsWith('import.error.emptyFile'));
    });

    test('reports malformed JSON with a usable message', () {
      final result = service.parse('{"schemaVersion": 1,');
      expect(result.isSuccess, isFalse);
      expect(result.errors.first, startsWith('import.error.notJson'));
    });

    test('rejects a document that is not an object', () {
      final result = service.parse('[1, 2, 3]');
      expect(result.isSuccess, isFalse);
      expect(result.errors.first, startsWith('import.error.notAnObject'));
    });

    test('refuses a newer schema rather than silently dropping fields', () {
      final result = service.parse(
        '{"schemaVersion": ${AppInfo.transferSchemaVersion + 1}, '
        '"lines": []}',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errors.first, startsWith('import.error.versionTooNew'));
    });

    test('skips an unreadable line but keeps the good ones', () {
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'lines': <Object?>[
          line('good').toJson(),
          'not an object',
          <String, Object?>{'id': 'no-text'},
        ],
      });
      final result = service.parse(raw);
      expect(result.isSuccess, isTrue);
      expect(result.payload!.lines.map((l) => l.id), <String>['good']);
      expect(result.warnings, hasLength(2));
    });

    test('fails when nothing at all could be read', () {
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'lines': <Object?>['garbage', 42],
      });
      final result = service.parse(raw);
      expect(result.isSuccess, isFalse);
      expect(result.errors.first, startsWith('import.error.nothingUsable'));
    });

    test('drops an interaction pointing at a line not in the file', () {
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'lines': <Object?>[line('present').toJson()],
        'interactions': <Object?>[
          record('r1', 'present').toJson(),
          record('r2', 'absent').toJson(),
        ],
      });
      final result = service.parse(raw);
      expect(result.isSuccess, isTrue);
      expect(result.payload!.interactions.map((r) => r.id), <String>['r1']);
      expect(
        result.warnings.any(
          (w) => w.startsWith('import.warning.orphanInteraction'),
        ),
        isTrue,
      );
    });

    test('ignores an unreadable settings block instead of failing', () {
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'lines': <Object?>[line('a').toJson()],
        'settings': 'not a map',
      });
      final result = service.parse(raw);
      expect(result.isSuccess, isTrue);
      expect(result.payload!.settings, isNull);
      expect(
        result.warnings.any(
          (w) => w.startsWith('import.warning.settingsIgnored'),
        ),
        isTrue,
      );
    });

    test('every error and warning is a localization key', () {
      // The data layer must not produce English prose, or half the app stops
      // being translatable.
      final result = service.parse('{"schemaVersion": 1, "lines": "nope"}');
      for (final message in <String>[...result.errors, ...result.warnings]) {
        expect(message, startsWith('import.'));
      }
    });
  });

  group('duplicate ids', () {
    test('re-keys a duplicate inside the file itself', () {
      final duplicate = line('same').toJson();
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'lines': <Object?>[line('same').toJson(), duplicate],
      });
      final result = service.parse(raw);
      expect(result.payload!.lines, hasLength(2));
      expect(result.payload!.lines.map((l) => l.id).toSet(), hasLength(2));
      expect(
        result.warnings.any(
          (w) => w.startsWith('import.warning.duplicateIdInFile'),
        ),
        isTrue,
      );
    });

    test('merge re-keys anything that collides with the existing library', () {
      final resolved = service.resolveCollisions(
        imported: <OpenerLine>[line('existing'), line('fresh')],
        existingIds: <String>{'existing'},
        mode: ImportMode.merge,
      );
      expect(resolved.rekeyed, 1);
      expect(resolved.lines.map((l) => l.id), isNot(contains('existing')));
      expect(resolved.lines.map((l) => l.id), contains('fresh'));
    });

    test('replace keeps the incoming ids, since nothing survives to clash', () {
      final resolved = service.resolveCollisions(
        imported: <OpenerLine>[line('existing')],
        existingIds: <String>{'existing'},
        mode: ImportMode.replace,
      );
      expect(resolved.rekeyed, 0);
      expect(resolved.lines.single.id, 'existing');
    });

    test('a re-keyed line keeps everything except its id', () {
      final original = line(
        'existing',
        japanese: '内容は変わりません。',
        tones: <Tone>{Tone.playful},
        isFavorite: true,
      );
      final resolved = service.resolveCollisions(
        imported: <OpenerLine>[original],
        existingIds: <String>{'existing'},
        mode: ImportMode.merge,
      );
      final rekeyed = resolved.lines.single;
      expect(rekeyed.id, isNot('existing'));
      expect(rekeyed.japaneseText, original.japaneseText);
      expect(rekeyed.tones, original.tones);
      expect(rekeyed.isFavorite, isTrue);
    });
  });

  group('schema versions', () {
    test('reads the current version', () {
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': AppInfo.transferSchemaVersion,
        'lines': <Object?>[line('a').toJson()],
      });
      expect(service.parse(raw).isSuccess, isTrue);
    });

    test('migrates a version 0 document on read', () {
      // Version 0 used "openerLines", a single "tone" string, and no category.
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 0,
        'openerLines': <Object?>[
          <String, Object?>{
            'id': 'old-1',
            'japaneseText': '昔の形式のデータです。',
            'englishMeaning': 'A line in the old format.',
            'tone': 'playful',
            'directness': 3,
            'locations': <String>['bar'],
          },
        ],
      });
      final result = service.parse(raw);
      expect(result.isSuccess, isTrue, reason: result.errors.join('; '));
      final migrated = result.payload!.lines.single;
      expect(migrated.id, 'old-1');
      expect(migrated.tones, <Tone>{Tone.playful});
      expect(migrated.category, LineCategory.universal);
      expect(migrated.locations, <LocationTag>{LocationTag.bar});
      expect(
        result.warnings.any(
          (w) => w.startsWith('import.warning.migratedFromV0'),
        ),
        isTrue,
      );
    });

    test('records which version the file claimed', () {
      final raw = service.buildExportJson(
        lines: <OpenerLine>[line('a')],
        settings: AppSettings.defaults,
      );
      final result = service.parse(raw);
      expect(result.payload!.schemaVersion, AppInfo.transferSchemaVersion);
      expect(result.payload!.sourceAppVersion, AppInfo.version);
    });
  });

  group('the sample file in the repository', () {
    test('parses, so the documented example is never allowed to rot', () {
      final file = File('assets/sample/sample_import.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'assets/sample/sample_import.json is referenced by the README',
      );
      final result = service.parse(file.readAsStringSync());
      expect(result.isSuccess, isTrue, reason: result.errors.join('; '));
      expect(result.warnings, isEmpty, reason: result.warnings.join('; '));
      expect(result.payload!.lines, hasLength(3));
      expect(result.payload!.interactions, hasLength(1));
      // Every enum name in the file must be one this build knows, or the tags
      // would be silently dropped and the sample would teach the wrong schema.
      final withTags = result.payload!.lines.firstWhere(
        (l) => l.id == 'sample-cafe-pastry',
      );
      expect(withTags.locations, isNotEmpty);
      expect(withTags.activities, isNotEmpty);
      expect(withTags.observableCues, isNotEmpty);
      expect(withTags.avoidConditions, isNotEmpty);
    });
  });
}
