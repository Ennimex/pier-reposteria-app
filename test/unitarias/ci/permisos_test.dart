// test/unitarias/ci/permisos_test.dart — #227: el manifiesto pide solo lo que
// la app usa (docs/PERMISOS.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifiesto = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  String permiso(String nombre) =>
      '<uses-permission android:name="android.permission.$nombre" />';

  test('#227: declara la ubicación aproximada y la precisa', () {
    expect(manifiesto, contains(permiso('ACCESS_COARSE_LOCATION')));
    expect(manifiesto, contains(permiso('ACCESS_FINE_LOCATION')));
  });

  test('#227: no pide cámara, notificaciones ni ubicación en segundo plano',
      () {
    for (final nombre in [
      'CAMERA',
      'POST_NOTIFICATIONS',
      'ACCESS_BACKGROUND_LOCATION',
    ]) {
      expect(manifiesto, isNot(contains('android.permission.$nombre')),
          reason: nombre);
    }
  });

  test('#227: cada permiso tiene su documento', () {
    final documento = File('docs/PERMISOS.md').readAsStringSync();

    expect(documento, contains('ACCESS_FINE_LOCATION'));
    expect(documento, contains('Lo que la app no pide'));
  });
}
