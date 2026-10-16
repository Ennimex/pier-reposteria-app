// test/unitarias/ci/cli_test.dart — comandos de tool/resumen_pruebas.dart
// (#157): leen los archivos que dejan los pasos del workflow y escriben el
// resumen en la salida y en el archivo de GITHUB_STEP_SUMMARY.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/cli.dart';

late Directory _raiz;
late File _resumen;
late StringBuffer _salida;

void _escribir(String ruta, String contenido) =>
    File('${_raiz.path}/$ruta')
      ..createSync(recursive: true)
      ..writeAsStringSync(contenido);

int _ejecutar(
  List<String> argumentos, {
  Map<String, String> entorno = const {},
}) =>
    ejecutar(
      argumentos,
      raiz: _raiz.path,
      entorno: {
        'GITHUB_STEP_SUMMARY': _resumen.path,
        'GITHUB_REF_NAME': 'main',
        'GITHUB_SHA': 'abc1234def5678',
        ...entorno,
      },
      salida: _salida,
    );

String _reporteVerde() => [
      {
        'type': 'suite',
        'suite': {'id': 0, 'path': '${_raiz.path}/test/app_test.dart'},
      },
      {
        'type': 'testStart',
        'test': {'id': 1, 'name': 'arranca', 'suiteID': 0, 'groupIDs': []},
      },
      {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': false},
      {'type': 'done', 'success': true, 'time': 1500},
    ].map(jsonEncode).join('\n');

const _script = 'baseline_errors=0\nbaseline_warnings=0\nbaseline_infos=151\n';

void main() {
  setUp(() {
    _raiz = Directory.systemTemp.createTempSync('resumen_');
    _resumen = File('${_raiz.path}/summary.md')..createSync();
    _salida = StringBuffer();
  });

  tearDown(() => _raiz.deleteSync(recursive: true));

  group('pruebas', () {
    test('escribe el resumen en la salida y lo agrega a GITHUB_STEP_SUMMARY',
        () {
      _escribir('build/resultados/unitarias.json', _reporteVerde());
      _resumen.writeAsStringSync('## Antes\n');

      final codigo = _ejecutar([
        'pruebas',
        'build/resultados/unitarias.json',
        '--titulo',
        'Pruebas unitarias',
      ]);

      expect(codigo, 0);
      expect(_salida.toString(), contains('### 🧪 Pruebas unitarias'));
      expect(_salida.toString(), contains('| ✅ Aprobado | 1 | 1 |'));
      expect(_resumen.readAsStringSync(), startsWith('## Antes\n'));
      expect(_resumen.readAsStringSync(), contains('### 🧪 Pruebas unitarias'));
    });

    test('con --cobertura agrega la tabla de lcov.info', () {
      _escribir('build/resultados/unitarias.json', _reporteVerde());
      _escribir('coverage/lcov.info', 'SF:lib/main.dart\nLF:4\nLH:3\nend_of_record\n');

      _ejecutar([
        'pruebas',
        'build/resultados/unitarias.json',
        '--titulo',
        'Pruebas unitarias',
        '--cobertura',
        'coverage/lcov.info',
      ]);

      expect(_salida.toString(), contains('**Cobertura de líneas: 75.0 %**'));
    });

    test('con --detalle lista cada prueba', () {
      _escribir('build/resultados/aceptacion.json', _reporteVerde());

      _ejecutar([
        'pruebas',
        'build/resultados/aceptacion.json',
        '--titulo',
        'Escenarios',
        '--detalle',
      ]);

      expect(_salida.toString(), contains('- ✅ arranca'));
    });

    test('si no existe el reporte avisa sin fallar el paso', () {
      final codigo = _ejecutar([
        'pruebas',
        'build/resultados/no_existe.json',
        '--titulo',
        'Pruebas unitarias',
      ]);

      expect(codigo, 0);
      expect(_salida.toString(), contains('No se generó el reporte de pruebas'));
    });

    test('sin --titulo explica el uso', () {
      expect(_ejecutar(['pruebas', 'x.json']), 64);
      expect(_salida.toString(), contains('Uso: dart run tool/resumen_pruebas.dart'));
    });
  });

  group('analisis', () {
    test('lee la salida guardada por check_analysis.sh y su línea base', () {
      _escribir('tool/check_analysis.sh', _script);
      _escribir(
        'build/resultados/analisis.txt',
        '   info • Mensaje. Detalle • lib/main.dart:3:1 • una_regla\n',
      );

      expect(_ejecutar(['analisis']), 0);
      expect(_salida.toString(), contains('| Avisos | 1 | 151 | ✅ |'));
    });

    test('avisa si la salida no trae el conteo final de flutter analyze', () {
      _escribir('tool/check_analysis.sh', _script);
      _escribir('build/resultados/analisis.txt', 'Analyzing app...\nCrash\n');

      _ejecutar(['analisis']);

      expect(_salida.toString(), contains('está incompleta'));
    });

    test('no avisa si la salida termina con el conteo', () {
      _escribir('tool/check_analysis.sh', _script);
      _escribir('build/resultados/analisis.txt', 'No issues found! (ran in 2s)\n');

      _ejecutar(['analisis']);

      expect(_salida.toString(), isNot(contains('está incompleta')));
    });

    test('si falta la línea base falla el paso', () {
      _escribir('build/resultados/analisis.txt', '');

      expect(_ejecutar(['analisis']), 1);
      expect(_salida.toString(), contains('No se encontró la línea base'));
    });

    test('si falta la salida de flutter analyze avisa', () {
      _escribir('tool/check_analysis.sh', _script);

      expect(_ejecutar(['analisis']), 0);
      expect(
        _salida.toString(),
        contains('No se generó la salida de flutter analyze'),
      );
    });
  });

  group('peso', () {
    test('encuentra el APK de release y su desglose en build/', () {
      _escribir('build/app/outputs/flutter-apk/app-prod-release.apk', 'x' * 2048);
      _escribir(
        'build/apk-code-size-analysis_01.json',
        jsonEncode({
          'n': 'Root',
          'children': [
            {'n': 'classes.dex', 'value': 1024},
          ],
        }),
      );

      expect(_ejecutar(['peso']), 0);
      expect(
        _salida.toString(),
        contains('| `app-prod-release.apk` | **2.0 KB** |'),
      );
      expect(_salida.toString(), contains('| `classes.dex` | 1.0 KB |'));
    });

    test(
        'toma el desglose más reciente de ~/.flutter-devtools, donde lo deja '
        'flutter build', () {
      _escribir('build/app/outputs/flutter-apk/app-prod-release.apk', 'x');
      for (final (numero, parte) in [(1, 'vieja.dex'), (2, 'nueva.dex')]) {
        _escribir(
          'casa/.flutter-devtools/apk-code-size-analysis_0$numero.json',
          jsonEncode({
            'n': 'Root',
            'children': [
              {'n': parte, 'value': 1024},
            ],
          }),
        );
      }

      _ejecutar(['peso'], entorno: {'HOME': '${_raiz.path}/casa'});

      expect(_salida.toString(), contains('| `nueva.dex` | 1.0 KB |'));
      expect(_salida.toString(), isNot(contains('vieja.dex')));
    });

    test('avisa si no hay APK', () {
      expect(_ejecutar(['peso']), 0);
      expect(_salida.toString(), contains('No se encontró el APK de release'));
    });
  });

  group('tiempos', () {
    test('toma cada timeline_summary.json de build/ en orden', () {
      _escribir(
        'build/checkout.timeline_summary.json',
        jsonEncode({'frame_count': 10}),
      );
      _escribir(
        'build/catalogo.timeline_summary.json',
        jsonEncode({'frame_count': 20}),
      );

      expect(_ejecutar(['tiempos']), 0);
      expect(_salida.toString(), contains('| | catalogo | checkout |'));
      expect(_salida.toString(), contains('| Cuadros dibujados | 20 | 10 |'));
    });
  });

  group('monkey', () {
    test('lee monkey.txt y logcat.txt', () {
      _escribir(
        'monkey.txt',
        ':Monkey: seed=42 count=5\n// CRASH: app (pid 1)\n// Long Msg: boom\n'
            'Events injected: 2\n',
      );
      _escribir('logcat.txt', 'E/AndroidRuntime( 1): FATAL EXCEPTION: main\n');

      expect(_ejecutar(['monkey', 'monkey.txt', 'logcat.txt']), 0);
      expect(_salida.toString(), contains('// Long Msg: boom'));
      expect(_salida.toString(), contains('FATAL EXCEPTION: main'));
    });

    test('avisa si no existe la bitácora', () {
      expect(_ejecutar(['monkey', 'monkey.txt']), 0);
      expect(_salida.toString(), contains('No se generó la bitácora de monkey'));
    });
  });

  group('regresion', () {
    test('arma la tabla con los archivos de cada etapa', () {
      _escribir('tool/check_analysis.sh', _script);
      _escribir('build/resultados/integracion.json', _reporteVerde());
      _escribir('build/resultados/analisis.txt', '');
      _escribir('build/resultados/suite.json', _reporteVerde());
      _escribir('coverage/lcov.info', 'SF:lib/main.dart\nLF:2\nLH:2\nend_of_record\n');
      _escribir('build/app/outputs/flutter-apk/app-prod-debug.apk', 'x' * 4096);

      final codigo = _ejecutar([
        'regresion',
        '--integracion',
        'success',
        '--analisis',
        'success',
        '--suite',
        'success',
        '--apk',
        'success',
      ]);

      expect(codigo, 0);
      final texto = _salida.toString();
      expect(texto, contains('Versión `main` · commit `abc1234`'));
      expect(
        texto,
        contains('| Integración en el emulador | ✅ 1 prueba pasó |'),
      );
      expect(
        texto,
        contains(
          '| Análisis estático | ✅ 0 errores · 0 advertencias · 0 avisos '
          '(línea base 0/0/151) |',
        ),
      );
      expect(
        texto,
        contains(
          '| Unitarias, de widget y de aceptación | ✅ 1 prueba pasó · '
          'cobertura 100.0 % |',
        ),
      );
      expect(
        texto,
        contains('| APK de depuración | ✅ 4.0 KB, guardado en Artifacts |'),
      );
    });

    test('las etapas que no corrieron no buscan sus archivos', () {
      _ejecutar([
        'regresion',
        '--integracion',
        'failure',
        '--analisis',
        'skipped',
        '--suite',
        'skipped',
        '--apk',
        'skipped',
      ]);

      expect(
        _salida.toString(),
        contains(
          '| Integración en el emulador | ❌ Falló: revisa el log del paso |',
        ),
      );
      expect(
        _salida.toString(),
        contains('| APK de depuración | ⏭️ No corrió: falló una etapa anterior |'),
      );
    });
  });

  test('un comando desconocido explica el uso', () {
    expect(_ejecutar(['otro']), 64);
    expect(_salida.toString(), contains('Comandos:'));
  });
}
