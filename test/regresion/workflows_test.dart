// test/regresion/workflows_test.dart — regresiones de los pipelines de
// .github/workflows/, que no tienen código Dart que probar:
//   · #155: SonarCloud falló en main y la misma corrida avisó que las
//     acciones corrían con Node.js 20 y que el escáner de SonarCloud tenía
//     una vulnerabilidad. #156 las subió de versión; ninguna debe regresar.
//   · #185: la regresión de v2.1.0 falló porque corrió con flutter test, en
//     el emulador, las mediciones de integration_test/rendimiento/, que solo
//     funcionan con flutter drive en modo profile en un celular físico
//     (corregido en #186).
//   · #341: la fluidez en el celular se medía con la traza recortada.
//     flutter drive la guarda en un búfer circular y solo quedaba lo último
//     de cada escena: el primer cuadro del Inicio no entraba y el resultado
//     cambiaba de una sesión a otra con el mismo código. Se mide con
//     --endless-trace-buffer.
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
}
