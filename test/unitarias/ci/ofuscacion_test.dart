// test/unitarias/ci/ofuscacion_test.dart — #224: el release ofusca el código
// Dart (--obfuscate) y sube sus símbolos a Sentry antes de publicar, sin
// mostrar nunca el token; y la app no depende de nombres de clases como texto,
// que en la versión publicada salen renombrados.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  final release = _leer('.github/workflows/release.yml');
  final inicioDePublicar = release.indexOf('\n  publicar:');
  final pruebas = release.substring(0, inicioDePublicar);
  final publicar = release.substring(inicioDePublicar);
  const ofuscar = '--obfuscate --split-debug-info=';
  const mapa = '--extra-gen-snapshot-options=--save-obfuscation-map=';

  test('#224: el candidato y la versión publicada salen ofuscados', () {
    // El APK y el AAB de cada trabajo, cada uno con su mapa de nombres: el
    // smoke del candidato prueba la app ofuscada, como la que se publica.
    for (final trabajo in [pruebas, publicar]) {
      expect(ofuscar.allMatches(trabajo), hasLength(2));
      expect(mapa.allMatches(trabajo), hasLength(2));
    }
  });

  test('#224: los símbolos suben a Sentry antes de publicar y se guardan', () {
    final subida = publicar.indexOf(
        'bash tool/subir_simbolos.sh build/simbolos/apk build/simbolos/aab');
    expect(subida, isNonNegative);
    expect(subida, lessThan(publicar.indexOf('name: Publicar la Release')));
    expect(publicar,
        contains(r'name: simbolos-${{ steps.version.outputs.nombre }}'));
    expect(publicar, contains('retention-days: 90'));

    // En el ensayo se sube el candidato, para probar el token sin publicar.
    expect(
      pruebas,
      contains("- name: 'Ensayo: subir los símbolos del candidato a Sentry'\n"
          r'        if: ${{ !cancelled() && inputs.ensayo }}'),
    );
    expect(
      RegExp(r'SENTRY_AUTH_TOKEN: \$\{\{ secrets\.SENTRY_AUTH_TOKEN \}\}')
          .allMatches(release),
      hasLength(2),
    );
  });

  test('#224: el script nunca muestra el token y fija sentry-cli', () {
    final script = _leer('tool/subir_simbolos.sh');

    // El token solo se revisa (que no esté vacío): sentry-cli lo lee del
    // ambiente, no de la línea de comandos, y nada lo imprime.
    expect(
      RegExp(r'\$\{?SENTRY_AUTH_TOKEN')
          .allMatches(script)
          .map((m) => m[0])
          .toList(),
      [r'${SENTRY_AUTH_TOKEN'],
    );
    expect(script, contains(r'if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then'));
    expect(script, isNot(contains('--auth-token')));
    expect(script, isNot(contains('set -x')));

    // Una versión exacta de sentry-cli, no «latest».
    expect(
      RegExp(r'^VERSION_SENTRY_CLI=\d+\.\d+\.\d+$', multiLine: true)
          .hasMatch(script),
      isTrue,
    );
    expect(script, contains(r'"@sentry/cli@$VERSION_SENTRY_CLI"'));
  });

  test('#224: lib/ no usa runtimeType (la ofuscación lo renombra)', () {
    final usos = [
      for (final archivo in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((archivo) => archivo.path.endsWith('.dart')))
        if (archivo.readAsStringSync().contains('runtimeType')) archivo.path,
    ];

    expect(usos, isEmpty);
  });
}
