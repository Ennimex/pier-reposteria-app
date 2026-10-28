// test/unitarias/ci/r8_test.dart — #224: el release de Android se reduce y
// se renombra con R8, explícito en build.gradle.kts y con reglas propias.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('#224: el build release enciende R8 y quita los recursos sin uso', () {
    final gradle = _leer('android/app/build.gradle.kts');
    final release = gradle.substring(
      gradle.indexOf('    buildTypes {'),
      gradle.indexOf('flutter {'),
    );

    expect(release, contains('isMinifyEnabled = true'));
    expect(release, contains('isShrinkResources = true'));
    expect(release,
        contains('getDefaultProguardFile("proguard-android-optimize.txt")'));
    expect(release, contains('"proguard-rules.pro"'));
  });

  test('#224: las reglas propias conservan los números de línea', () {
    final reglas = _leer('android/app/proguard-rules.pro');

    expect(reglas, contains('-keepattributes SourceFile,LineNumberTable'));
    expect(reglas, contains('-renamesourcefileattribute SourceFile'));
    // Nada de «-dontobfuscate» ni «-keep class **»: anularían a R8.
    expect(reglas, isNot(contains('-dontobfuscate')));
    expect(reglas, isNot(contains('-keep class **')));
  });
}
