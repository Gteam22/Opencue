// Verifies that the version is the same everywhere it is written.
//
// version.txt is the single source of truth. The pubspec, app_info.dart and
// installer/opencue.iss all restate it because none of them can read a Dart
// constant, and a mismatch produces an installer whose reported version does
// not match the running app.
//
// Run:  dart tool/check_version.dart
//
// This duplicates test/version_consistency_test.dart on purpose: CI runs this
// before `flutter build`, so a mismatch fails in seconds rather than after the
// full Windows build. Exits non-zero on any disagreement.

import 'dart:io';

void main() {
  final canonical = File('version.txt').readAsStringSync().trim();
  final problems = <String>[];

  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(canonical)) {
    problems.add(
      'version.txt should hold a bare x.y.z version, found "$canonical"',
    );
  }

  problems.addAll(<String>[
    ..._check(
      'pubspec.yaml',
      RegExp(r'^version:\s*(\S+)\s*$', multiLine: true),
      canonical,
      // The pubspec appends a build number after a plus sign.
      transform: (value) => value.split('+').first,
    ),
    ..._check(
      'lib/core/app_info.dart',
      RegExp(r"static const String version = '([^']+)'"),
      canonical,
    ),
    ..._check(
      'installer/opencue.iss',
      RegExp(r'^#define\s+MyAppVersion\s+"([^"]+)"', multiLine: true),
      canonical,
    ),
  ]);

  if (problems.isEmpty) {
    stdout.writeln('Version OK: $canonical in every location.');
    return;
  }
  stderr.writeln('Version mismatch:');
  for (final problem in problems) {
    stderr.writeln('  $problem');
  }
  exit(1);
}

List<String> _check(
  String path,
  RegExp pattern,
  String canonical, {
  String Function(String value)? transform,
}) {
  final file = File(path);
  if (!file.existsSync()) {
    return <String>['$path is missing'];
  }
  final match = pattern.firstMatch(file.readAsStringSync());
  if (match == null) {
    return <String>['$path: no version found by ${pattern.pattern}'];
  }
  final found = (transform ?? (String v) => v)(match.group(1)!);
  if (found != canonical) {
    return <String>['$path declares "$found", expected "$canonical"'];
  }
  return const <String>[];
}
