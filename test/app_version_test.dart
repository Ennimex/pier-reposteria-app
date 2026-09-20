import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/app_version.dart';

void main() {
  test('AppVersion coincide con version: de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml no tiene línea version:');
    expect(match!.group(1), AppVersion.full);
  });

  test('AppVersion sigue el formato SemVer MAJOR.MINOR.PATCH', () {
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(AppVersion.name), isTrue);
    expect(AppVersion.build, greaterThan(0));
  });
}
