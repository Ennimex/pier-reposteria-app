// test/regresion/workflows_test.dart — regresiones de los pipelines de
// .github/workflows/, que no tienen código Dart que probar:
//   · #155: SonarCloud falló en main y la misma corrida avisó que las
//     acciones corrían con Node.js 20 y que el escáner de SonarCloud tenía
//     una vulnerabilidad. #156 las subió de versión; ninguna debe regresar.
//   · #374: el trabajo de los flujos en Android 10 fallaba en el primer
//     comando de adb cuando el emulador restauraba la instantánea del AVD
//     (No service published for: input). Ese celular arranca en frío.
//   · #375: a veces la app se cuelga al abrirse en el emulador y flutter test
//     la esperaba 40 min. Los flujos corren con tool/flujos_entorno_aislado.sh,
//     que corta y vuelve a correr una vez lo que no terminó.
//   · #185: la regresión de v2.1.0 falló porque corrió con flutter test, en
//     el emulador, las mediciones de integration_test/rendimiento/, que solo
//     funcionan con flutter drive en modo profile en un celular físico
//     (corregido en #186).
//   · #341: la fluidez en el celular se medía con la traza recortada.
//     flutter drive la guarda en un búfer circular y solo quedaba lo último
//     de cada escena: el primer cuadro del Inicio no entraba y el resultado
//     cambiaba de una sesión a otra con el mismo código. Se mide con
//     --endless-trace-buffer.
//   · #384: fluidez.sh dejaba compilar a flutter drive y flutter run. Sin un
//     APK previo toman el paquete del manifiesto, el de la «Pier» de la
//     tienda, y un reintento podía desinstalarla. Además pasaba la cuenta de
//     prueba en la línea de comandos, que flutter_tools escribe en
//     flutter_NN.log si se cae. Ahora compila antes los APK del sabor dev y
//     la cuenta entra por un archivo.
@Tags(['regresion'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cada workflow del repositorio: nombre del archivo → su contenido.
Map<String, String> _workflows() {
  final archivos = Directory('.github/workflows')
      .listSync()
      .whereType<File>()
      .where((archivo) => archivo.path.endsWith('.yml'));
  return {
    for (final archivo in archivos)
      archivo.uri.pathSegments.last: archivo.readAsStringSync(),
  };
}

/// La versión mayor de cada acción que dejó #156.
const _versionMinima = {
  'actions/checkout': 7,
  'actions/setup-java': 6,
  'actions/cache': 6,
  'actions/upload-artifact': 7,
  'SonarSource/sonarqube-scan-action': 8,
};

void main() {
  test('#155: ningún workflow vuelve a una versión vieja de las acciones', () {
    final usoDeAccion = RegExp(r'uses:\s*([\w.-]+/[\w.-]+)@v(\d+)');
    final versionesViejas = <String>[];

    for (final MapEntry(key: workflow, value: contenido)
        in _workflows().entries) {
      for (final uso in usoDeAccion.allMatches(contenido)) {
        final accion = uso.group(1)!;
        final version = int.parse(uso.group(2)!);
        final minima = _versionMinima[accion];
        if (minima != null && version < minima) {
          versionesViejas.add('$workflow: $accion@v$version (mínima v$minima)');
        }
      }
    }

    expect(versionesViejas, isEmpty);
  });

  test('#374: los flujos del entorno aislado arrancan en frío el emulador '
      'de Android 10', () {
    final workflow =
        _workflows()['integracion.yml']!.replaceAll('\r\n', '\n');
    expect(workflow, contains('\n  flujo-compra-aislado:\n'));
    final trabajo =
        workflow.substring(workflow.indexOf('\n  flujo-compra-aislado:\n'));

    // La vuelta de Android 10 de la matriz, con todas sus llaves.
    final android10 =
        RegExp(r'- android: 10\n(?: {12}[^\n]*\n)+').stringMatch(trabajo);
    expect(android10, contains('instantanea: -no-snapshot\n'));

    // El paso que corre los flujos enciende el emulador con lo que dice la
    // matriz, no con una opción fija para los dos celulares.
    expect(trabajo, contains('name: Correr los flujos en el emulador'));
    final flujos = trabajo
        .substring(trabajo.indexOf('name: Correr los flujos en el emulador'));
    expect(
      flujos,
      contains(r'emulator-options: ${{ matrix.instantanea }} '),
    );
  });

  test('#375: los flujos del entorno aislado corren con el vigilante que '
      'corta y reintenta', () {
    final workflow =
        _workflows()['integracion.yml']!.replaceAll('\r\n', '\n');
    final paso = workflow.substring(
        workflow.indexOf('name: Correr los flujos en el emulador'));
    final script = paso.substring(paso.indexOf('script: >'));
    final comando = script.substring(0, script.indexOf('then '));

    // Un solo flutter test y lo corre el script: suelto, un cuelgue vuelve
    // a esperar 40 min.
    expect('flutter test'.allMatches(comando), hasLength(1));
    expect(
      comando,
      matches(RegExp(
        r'bash tool/flujos_entorno_aislado\.sh\s+'
        r'build/resultados/flujo_entorno_aislado_android_\$\{\{ matrix\.android \}\}\.json\s+'
        'flutter test ',
      )),
    );
  });

  test('#185: ningún flutter test corre integration_test/rendimiento/', () {
    final comandoFlutterTest = RegExp(r'flutter test ([^\n]*)');
    final rutasRevisadas = <String>[];

    for (final MapEntry(key: workflow, value: contenido)
        in _workflows().entries) {
      for (final comando in comandoFlutterTest.allMatches(contenido)) {
        final rutasDeIntegracion = comando
            .group(1)!
            .split(RegExp(r'\s+'))
            .where((argumento) => argumento.startsWith('integration_test'));
        for (final ruta in rutasDeIntegracion) {
          rutasRevisadas.add('$workflow: $ruta');
          // Ni la carpeta de mediciones ni integration_test/ completa (la
          // incluye): cada workflow nombra sus archivos uno por uno.
          expect(ruta, isNot(startsWith('integration_test/rendimiento')),
              reason: workflow);
          expect(ruta, isNot(anyOf('integration_test', 'integration_test/')),
              reason: workflow);
        }
      }
    }

    // Si nadie corriera integration_test/ con flutter test, esta prueba no
    // estaría revisando nada.
    expect(rutasRevisadas, isNotEmpty);
  });

  test('#341: la fluidez en el celular se mide con la traza completa', () {
    const script = 'tool/rendimiento_celular/fluidez.sh';
    final archivos = <String, String>{
      script: File(script).readAsStringSync(),
      for (final MapEntry(key: workflow, value: contenido)
          in _workflows().entries)
        '.github/workflows/$workflow': contenido,
    };
    final revisados = <String>[];

    for (final MapEntry(key: archivo, value: contenido) in archivos.entries) {
      final comandos = RegExp(r'^\s*flutter drive', multiLine: true);
      for (final inicio in comandos.allMatches(contenido)) {
        // El comando con sus renglones de continuación.
        final fin = (inicio.start + 700).clamp(0, contenido.length);
        final comando = contenido.substring(inicio.start, fin);
        if (!comando.contains('rendimiento_test.dart')) continue;
        revisados.add(archivo);
        expect(comando, contains('--endless-trace-buffer'),
            reason: '$archivo mide con la traza recortada');
      }
    }

    // El script de la laptop y el workflow del celular.
    expect(
      revisados,
      containsAll([script, '.github/workflows/rendimiento-celular.yml']),
    );
  });

  test('#384: fluidez.sh corre APK ya compilados del sabor dev y la cuenta '
      'de prueba no va en ninguna línea de comandos', () {
    const script = 'tool/rendimiento_celular/fluidez.sh';
    final contenido = File(script).readAsStringSync().replaceAll('\r\n', '\n');
    // Cada comando de flutter con sus renglones de continuación unidos.
    final comandos = contenido
        .replaceAll('\\\n', ' ')
        .split('\n')
        .map((renglon) => renglon.trim())
        .where((renglon) => renglon.startsWith('flutter '))
        .toList();
    final compilaciones = comandos
        .where((c) => c.startsWith('flutter build apk'))
        .toList();
    final corridas = comandos
        .where(
          (c) => c.startsWith('flutter drive') || c.startsWith('flutter run'),
        )
        .toList();

    // flutter drive y flutter run no compilan: usan el APK ya compilado, del
    // que sale el paquete (Pier DEV), nunca el del manifiesto.
    expect(corridas.where((c) => c.startsWith('flutter drive')), isNotEmpty);
    expect(corridas.where((c) => c.startsWith('flutter run')), isNotEmpty);
    for (final corrida in corridas) {
      expect(corrida, contains('--use-application-binary'), reason: corrida);
    }

    // Los APK son del sabor dev en modo profile, la prueba y la app, y se
    // compilan antes de la primera corrida.
    expect(compilaciones, hasLength(2));
    for (final compilacion in compilaciones) {
      expect(compilacion, contains('--profile'), reason: compilacion);
      expect(compilacion, contains('--flavor dev'), reason: compilacion);
    }
    expect(
      contenido.indexOf('flutter build apk'),
      lessThan(
        contenido.indexOf(RegExp(r'^\s*flutter (drive|run)', multiLine: true)),
      ),
    );

    // La cuenta entra por un archivo (--dart-define-from-file), nunca en la
    // línea de comandos.
    expect(
      compilaciones.where((c) => c.contains('rendimiento_test.dart')).single,
      contains('--dart-define-from-file='),
    );
    expect(contenido, isNot(contains(RegExp(r'--dart-define=\S*_PRUEBA'))));
    expect(contenido, isNot(contains(RegExp(r'\$\{?(USUARIO|CLAVE)_PRUEBA'))));
  });
}
