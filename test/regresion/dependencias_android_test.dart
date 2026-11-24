// test/regresion/dependencias_android_test.dart — #383: el pipeline fallaba
// con «429 Too Many Requests» de Maven Central al compilar con
// integration_test. El plugin integration_test del SDK de Flutter pide
// androidx.test con versiones dinámicas (runner:1.2+, rules:1.2+,
// espresso-core:3.3+) y, con un «+», Gradle lee la lista de versiones en
// todos los repositorios, también en Maven Central. android/build.gradle.kts
// las cambia por versiones fijas; esta prueba avisa si el SDK (al subir de
// versión de Flutter) pide una que no esté fijada.
@Tags(['regresion'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La carpeta del paquete [nombre] según .dart_tool/package_config.json
/// (la de `flutter pub get`, con el SDK de quien corre la prueba).
Directory _carpetaDelPaquete(String nombre) {
  final config = File('.dart_tool/package_config.json');
  final paquetes =
      (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
  final paquete = paquetes.cast<Map>().firstWhere((p) => p['name'] == nombre);
  final raiz = config.absolute.uri.resolve(paquete['rootUri'] as String);
  return Directory.fromUri(raiz);
}

/// Las dependencias de androidx.test con versión dinámica («+») que declara
/// un build.gradle(.kts), como `grupo:nombre:versión`.
Set<String> _androidxTestDinamicas(String gradle) => {
  for (final m in RegExp(
    r'''["'](androidx\.test[\w.]*:[\w-]+:[^"']*\+)["']''',
  ).allMatches(gradle))
    m.group(1)!,
};

void main() {
  test('#383: las versiones dinámicas de androidx.test del plugin '
      'integration_test están fijadas en android/build.gradle.kts', () {
    final plugin = _carpetaDelPaquete('integration_test');
    final gradlePlugin = [
      File('${plugin.path}/android/build.gradle.kts'),
      File('${plugin.path}/android/build.gradle'),
    ].firstWhere((archivo) => archivo.existsSync());
    final dinamicas = _androidxTestDinamicas(gradlePlugin.readAsStringSync());

    final gradleApp = File('android/build.gradle.kts').readAsStringSync();
    final fijas = {
      for (final m in RegExp(
        r'"(androidx\.test[^"]+\+)"\s+to\s+"([^"]+)"',
      ).allMatches(gradleApp))
        m.group(1)!: m.group(2)!,
    };

    // Si el plugin ya no pidiera ninguna, esta prueba no revisaría nada (y
    // las versiones fijas sobrarían).
    expect(dinamicas, isNotEmpty, reason: gradlePlugin.path);
    for (final pedido in dinamicas) {
      expect(
        fijas,
        contains(pedido),
        reason: '$pedido (de ${gradlePlugin.path}) no está fijada',
      );
      final fija = fijas[pedido]!;
      // La fija cae en el mismo rango que la dinámica: 1.2+ → 1.2.x.
      final prefijo = pedido.split(':').last.replaceAll('+', '');
      expect(fija, startsWith(prefijo), reason: pedido);
      expect(fija, isNot(contains('+')), reason: pedido);
    }
    // Y el mapa se aplica a la resolución de todos los subproyectos.
    expect(gradleApp, contains('resolutionStrategy.eachDependency'));
    expect(gradleApp, contains('useVersion('));
  });
}
