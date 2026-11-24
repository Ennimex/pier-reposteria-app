// test/regresion/dependencias_android_test.dart — versiones dinámicas («+»)
// que piden los plugins de Android. Con un «+», Gradle lee la lista de
// versiones en todos los repositorios, también en Maven Central, que en el
// pipeline contestaba «429 Too Many Requests». android/build.gradle.kts las
// cambia por versiones fijas; estas pruebas avisan si alguno de estos dos
// plugins pide una que no esté fijada (a los demás no los revisan):
//   · #383: el plugin integration_test del SDK de Flutter pide androidx.test
//     (runner:1.2+, rules:1.2+, espresso-core:3.3+); el pipeline fallaba al
//     compilar con él. Avisa al subir de versión de Flutter.
//   · #387: el plugin stripe_android (de flutter_stripe) pide el SDK de
//     Stripe (stripe-android y financial-connections, 23.10.+). Se
//     actualizan a propósito junto con flutter_stripe: si al subirlo pide
//     otro rango, la prueba falla hasta fijar la versión nueva.
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

/// El build.gradle(.kts) de Android del plugin [nombre].
File _gradleDelPlugin(String nombre) {
  final plugin = _carpetaDelPaquete(nombre);
  return [
    File('${plugin.path}/android/build.gradle.kts'),
    File('${plugin.path}/android/build.gradle'),
  ].firstWhere((archivo) => archivo.existsSync());
}

/// El texto de [archivo] sin las líneas comentadas con //: un pin o una
/// versión comentados no fijan ni piden nada.
String _codigo(File archivo) => archivo.readAsStringSync().replaceAll(
  RegExp(r'^[ \t]*//.*$', multiLine: true),
  '',
);

/// Las dependencias de androidx.test con versión dinámica («+») que declara
/// un build.gradle(.kts), como `grupo:nombre:versión`.
Set<String> _androidxTestDinamicas(String gradle) => {
  for (final m in RegExp(
    r'''["'](androidx\.test[\w.]*:[\w-]+:[^"']*\+)["']''',
  ).allMatches(gradle))
    m.group(1)!,
};

/// Las dependencias de Stripe que declara un build.gradle(.kts), como
/// `grupo:nombre:versión`. stripe_android pone la versión en una variable
/// (`ext.stripe_version = '23.10.+'` y
/// `"com.stripe:stripe-android:$stripe_version"`): se cambia por su valor.
Set<String> _dependenciasDeStripe(String gradle) {
  final variables = {
    for (final m in RegExp(
      r'''(?:ext\.|val\s+|def\s+)(\w+)\s*=\s*["']([^"']+)["']''',
    ).allMatches(gradle))
      m.group(1)!: m.group(2)!,
  };
  return {
    for (final m in RegExp(
      r'''["'](com\.stripe:[\w-]+:[^"']+)["']''',
    ).allMatches(gradle))
      m
          .group(1)!
          .replaceAllMapped(
            RegExp(r'\$\{?(\w+)\}?'),
            (variable) => variables[variable.group(1)!] ?? variable.group(0)!,
          ),
  };
}

/// Revisa que android/build.gradle.kts fije cada pedido de [dinamicas] (del
/// plugin [origen]) en una versión del mismo rango, y devuelve esas fijas.
Map<String, String> _esperarFijadas(
  Set<String> dinamicas,
  String origen, {
  String aviso = '',
}) {
  final gradleApp = _codigo(File('android/build.gradle.kts'));
  final fijas = {
    for (final m in RegExp(
      r'"([\w.-]+:[\w.-]+:[^"]*\+)"\s+to\s+"([^"]+)"',
    ).allMatches(gradleApp))
      m.group(1)!: m.group(2)!,
  };

  // Si el plugin ya no pidiera ninguna, la prueba no revisaría nada (y las
  // versiones fijas sobrarían).
  expect(dinamicas, isNotEmpty, reason: origen);
  for (final pedido in dinamicas) {
    expect(
      fijas,
      contains(pedido),
      reason: '$pedido (de $origen) no está fijada$aviso',
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
  return {for (final pedido in dinamicas) pedido: fijas[pedido]!};
}

void main() {
  test('#383: las versiones dinámicas de androidx.test del plugin '
      'integration_test están fijadas en android/build.gradle.kts', () {
    final gradlePlugin = _gradleDelPlugin('integration_test');
    _esperarFijadas(
      _androidxTestDinamicas(_codigo(gradlePlugin)),
      gradlePlugin.path,
    );
  });

  test('#387: las versiones dinámicas del SDK de Stripe del plugin '
      'stripe_android están fijadas en android/build.gradle.kts', () {
    final gradlePlugin = _gradleDelPlugin('stripe_android');
    final stripe = _dependenciasDeStripe(_codigo(gradlePlugin));

    // Una variable que no se pudo leer dejaría su versión sin revisar.
    expect(
      stripe.where((dependencia) => dependencia.contains(r'$')),
      isEmpty,
      reason: gradlePlugin.path,
    );
    final fijas = _esperarFijadas(
      stripe.where((dependencia) => dependencia.contains('+')).toSet(),
      gradlePlugin.path,
      aviso: '; se actualiza a propósito junto con flutter_stripe',
    );
    // Las dos en la misma versión, como las pide el plugin (una sola
    // variable).
    expect(fijas.values.toSet(), hasLength(1), reason: '$fijas');
  });
}
