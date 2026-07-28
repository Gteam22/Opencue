import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/core/app_info.dart';

/// The version is written in four places that cannot import each other: a
/// plain text file, the pubspec, Dart source, and an Inno Setup script. Nothing
/// in the language can tie them together, so this test does it instead.
///
/// version.txt is the single source of truth. `dart tool/check_version.dart`
/// performs the same comparison outside the test harness, which is what CI runs
/// before it builds anything.
void main() {
  late String canonical;

  setUpAll(() {
    canonical = File('version.txt').readAsStringSync().trim();
  });

  test('version.txt holds a plain three-part version', () {
    expect(canonical, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });

  test('AppInfo.version matches version.txt', () {
    expect(AppInfo.version, canonical);
  });

  test('pubspec.yaml version matches version.txt', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'no version line in pubspec.yaml');
    // The pubspec carries a build number after a plus sign; only the semantic
    // part has to agree.
    final declared = match!.group(1)!.split('+').first;
    expect(declared, canonical);
  });

  test('the installer script version matches version.txt', () {
    final iss = File('installer/opencue.iss').readAsStringSync();
    final match = RegExp(
      r'^#define\s+MyAppVersion\s+"([^"]+)"',
      multiLine: true,
    ).firstMatch(iss);
    expect(
      match,
      isNotNull,
      reason: 'no MyAppVersion in installer/opencue.iss',
    );
    expect(match!.group(1), canonical);
  });

  test('the changelog has an entry for this version', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(changelog, contains(canonical));
  });

  test('the publisher placeholder is still obviously a placeholder', () {
    // A release must not ship with the literal placeholder silently treated as
    // a real company name. This fails loudly if the string is ever half-edited.
    expect(AppInfo.publisher, 'PUBLISHER_PLACEHOLDER');
  });

  test('the schema and database versions are positive integers', () {
    expect(AppInfo.databaseVersion, greaterThan(0));
    expect(AppInfo.transferSchemaVersion, greaterThan(0));
  });
}
