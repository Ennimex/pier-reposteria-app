// test/unitarias/ci/regresion_test.dart — tabla de etapas de la regresión
// (#157): una fila por etapa con el resultado que dio GitHub Actions.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/pruebas.dart';
import '../../../tool/resumen/regresion.dart';

void main() {
  group('resumenRegresion', () {
    test('pone una fila por etapa con su línea de resultado', () {
      final texto = resumenRegresion([
        const Etapa(
          nombre: 'Integración en el emulador',
          resultado: 'success',
          linea: '✅ 3 pruebas pasaron',
        ),
        const Etapa(nombre: 'APK de depuración', resultado: 'success'),
      ]);

      expect(texto, startsWith('### 🔁 Regresión completa\n'));
      expect(
        texto,
        contains(
          '| Etapa | Resultado |\n'
          '|---|---|\n'
          '| Integración en el emulador | ✅ 3 pruebas pasaron |\n'
          '| APK de depuración | ✅ Correcta |\n',
        ),
      );
    });

    test('marca las etapas que no corrieron o se cancelaron', () {
      final texto = resumenRegresion([
        const Etapa(nombre: 'Suite completa', resultado: 'skipped'),
        const Etapa(nombre: 'APK de depuración', resultado: 'cancelled'),
      ]);

      expect(
        texto,
        contains('| Suite completa | ⏭️ No corrió: falló una etapa anterior |'),
      );
      expect(texto, contains('| APK de depuración | ⏹️ Se canceló |'));
    });

    test('si la etapa falló pero su línea dice ✅, manda el resultado', () {
      final texto = resumenRegresion([
        const Etapa(
          nombre: 'Análisis estático',
          resultado: 'failure',
          linea: '✅ 0 errores · 0 advertencias · 0 avisos (línea base 0/0/151)',
        ),
        const Etapa(
          nombre: 'Suite completa',
          resultado: 'failure',
          linea: '❌ 1 de 9 pruebas fallaron',
        ),
      ]);

      expect(
        texto,
        contains('| Análisis estático | ❌ Falló: revisa el log del paso |'),
      );
      expect(texto, contains('| Suite completa | ❌ 1 de 9 pruebas fallaron |'));
    });

    test('muestra la versión y las pruebas que fallaron', () {
      final corrida = leerReporte(
        [
          {
            'type': 'suite',
            'suite': {'id': 0, 'path': 'test/app_test.dart'},
          },
          {
            'type': 'testStart',
            'test': {'id': 1, 'name': 'arranca', 'suiteID': 0, 'groupIDs': []},
          },
          {'type': 'error', 'testID': 1, 'error': 'Bad state'},
          {
            'type': 'testDone',
            'testID': 1,
            'result': 'error',
            'hidden': false,
          },
        ].map(jsonEncode).join('\n'),
      );

      final texto = resumenRegresion(
        [const Etapa(nombre: 'Suite completa', resultado: 'failure')],
        version: 'Versión `v1.2.0` · commit `abc1234`',
        corridas: [corrida],
      );

      expect(texto, contains('Versión `v1.2.0` · commit `abc1234`\n'));
      expect(texto, contains('#### ❌ Pruebas que fallaron (1)'));
      expect(texto, contains('**arranca**'));
      expect(texto, contains('Bad state'));
    });
  });
}
