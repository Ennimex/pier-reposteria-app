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
    test('lee monkey.txt y logcat.txt; con un cierre termina con 1', () {
      _escribir(
        'monkey.txt',
        ':Monkey: seed=42 count=5\n// CRASH: app (pid 1)\n// Long Msg: boom\n'
            'Events injected: 2\n',
      );
      _escribir('logcat.txt', 'E/AndroidRuntime( 1): FATAL EXCEPTION: main\n');

      expect(_ejecutar(['monkey', 'monkey.txt', 'logcat.txt']), 1);
      expect(_salida.toString(), contains('// Long Msg: boom'));
      expect(_salida.toString(), contains('FATAL EXCEPTION: main'));
    });

    test('monkey limpio pero logcat con un ANR de la app: termina con 1', () {
      _escribir(
        'monkey.txt',
        ':Monkey: seed=42 count=5\nEvents injected: 5\n// Monkey finished\n',
      );
      _escribir(
        'logcat.txt',
        'E/ActivityManager( 506): ANR in mx.com.pierreposteria '
            '(mx.com.pierreposteria/.MainActivity)\n',
      );

      expect(_ejecutar(['monkey', 'monkey.txt', 'logcat.txt']), 1);
      expect(_salida.toString(), contains('| ❌ Falló | 5 | 5 | 0 | 1 |'));
    });

    test('con --recuperacion muestra la reapertura y /api/health', () {
      _escribir(
        'monkey.txt',
        ':Monkey: seed=42 count=5\nEvents injected: 5\n// Monkey finished\n',
      );
      _escribir('logcat.txt', 'I/ActivityManager( 506): Start proc\n');
      _escribir(
        'recuperacion.txt',
        'Starting: Intent { cmp=mx.com.pierreposteria/.MainActivity }\n'
            'Status: ok\nLaunchState: COLD\nTotalTime: 2345\nComplete\n'
            'GET /api/health: 200\n',
      );

      expect(
        _ejecutar([
          'monkey',
          'monkey.txt',
          'logcat.txt',
          '--recuperacion',
          'recuperacion.txt',
        ]),
        0,
      );
      expect(
        _salida.toString(),
        contains('volvió a abrir en frío en 2,345.00 ms · GET /api/health: '
            '200.'),
      );
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

  // El flujo principal en el emulador (aceptacion.yml).
  group('flujo', () {
    test('lee el reporte de test_driver/aceptacion_driver.dart', () {
      _escribir(
        'build/resultados/aceptacion_emulador.json',
        jsonEncode({
          'aprobado': true,
          'pasos': [
            {'paso': '01_inicio_de_sesion', 'segundos': 3.1},
          ],
          'capturas': ['build/resultados/capturas/01_inicio_de_sesion.png'],
        }),
      );

      expect(_ejecutar(['flujo']), 0);
      expect(_salida.toString(), contains('| ✅ Aprobado | 1 | 1 | 3.1 s |'));
      expect(
        _resumen.readAsStringSync(),
        contains('### 📱 Flujo principal en el emulador'),
      );
    });

    test('avisa si no se generó el reporte', () {
      expect(_ejecutar(['flujo']), 0);
      expect(_salida.toString(), contains('No se generó el reporte del flujo'));
    });
  });

  /// Lo que guarda tool/arranque_en_frio.sh: una salida de am start -W por
  /// apertura.
  String aperturas(List<int> tiempos) => tiempos
      .map(
        (tiempo) =>
            'Starting: Intent { cmp=mx.com.pierreposteria/.MainActivity }\n'
            'Status: ok\nLaunchState: COLD\nTotalTime: $tiempo\n'
            'WaitTime: ${tiempo + 2}\nComplete\n',
      )
      .join();

  /// La regla de tool/linea_base_rendimiento.json: +20 % y +25 ms en los
  /// tiempos, +10 % en el peso.
  void escribirLineasBase() => _escribir(
        'tool/linea_base_rendimiento.json',
        jsonEncode({
          'api_carga_normal': {
            'p95_ms': 80,
            'tolerancia_porcentaje': 20,
            'tolerancia_minima_ms': 25,
          },
          'app_arranque_emulador': {
            'mediana_ms': 3000,
            'tolerancia_porcentaje': 20,
            'tolerancia_minima_ms': 25,
          },
          'app_peso_apk': {'bytes': 1000, 'tolerancia_porcentaje': 10},
        }),
      );

  // Arranque en frío en el emulador (rendimiento.yml).
  group('arranque', () {
    test('resume las aperturas y las compara con su línea base', () {
      escribirLineasBase();
      _escribir(
        'build/resultados/arranque_en_frio.txt',
        aperturas([3100, 2900, 3050, 2950, 3000]),
      );

      expect(_ejecutar(['arranque', '--escenario', 'app_arranque_emulador']),
          0);
      final texto = _salida.toString();
      expect(texto, contains('**Mediana: 3,000.00 ms** (5 aperturas).'));
      expect(texto, contains('✅ mediana 3,000.00 ms contra la línea base'));
      expect(_resumen.readAsStringSync(), contains('Arranque en frío'));
    });

    test('sin la medición avisa sin fallar el paso', () {
      expect(_ejecutar(['arranque']), 0);
      expect(_salida.toString(), contains('No se generó la medición'));
    });

    test('con develop: las rondas, las dos medianas, las descartadas y de '
        'dónde salió el APK de develop', () {
      escribirLineasBase();
      _escribir(
        'build/resultados/arranque_en_frio.txt',
        aperturas([3100, 3300, 3200]),
      );
      _escribir(
        'build/resultados/arranque_develop.txt',
        aperturas([3000, 2900, 3100]),
      );
      _escribir(
        'build/resultados/arranque_descartadas.txt',
        'Descartada: develop, ronda 1\n'
            '${aperturas([5000, 5100, 5200, 5300, 5400, 5500])}',
      );
      _escribir(
        'build/resultados/arranque_develop_origen.txt',
        'APK de develop: corrida 41182773384, commit 623a76f.\n',
      );

      final codigo = _ejecutar([
        'arranque',
        'build/resultados/arranque_en_frio.txt',
        '--escenario',
        'app_arranque_emulador',
        '--develop',
        'build/resultados/arranque_develop.txt',
        '--descartadas',
        'build/resultados/arranque_descartadas.txt',
        '--origen',
        'build/resultados/arranque_develop_origen.txt',
      ]);

      expect(codigo, 0);
      final texto = _salida.toString();
      expect(texto, contains('| 1 | ✅ 3,100.00 ms | ✅ 3,000.00 ms |'));
      expect(texto, contains('· diferencia: +6.7 %.**'));
      expect(texto, contains('Aperturas de calentamiento sin contar: 6'));
      expect(
        texto,
        contains('✅ mediana 3,200.00 ms contra la mediana de develop, '
            '3,000.00 ms'),
      );
      expect(
        texto,
        contains('porque decide develop: ✅ mediana 3,200.00 ms contra la '
            'línea base de 3,000.00 ms'),
      );
      expect(
        texto,
        contains('APK de develop: corrida 41182773384, commit 623a76f.\n'),
      );
    });

    test('sin el archivo de develop resume solo este cambio', () {
      escribirLineasBase();
      _escribir('build/resultados/arranque_en_frio.txt', aperturas([3000]));

      _ejecutar([
        'arranque',
        'build/resultados/arranque_en_frio.txt',
        '--develop',
        'build/resultados/arranque_develop.txt',
        '--descartadas',
        'build/resultados/arranque_descartadas.txt',
      ]);

      final texto = _salida.toString();
      expect(texto, contains('| Apertura | Ventana | Arranque |'));
      expect(texto, isNot(contains('develop')));
      expect(texto, isNot(contains('calentamiento')));
    });
  });

  // Este cambio contra develop, medidos en el mismo emulador
  // (tool/arranque_alternado.sh en rendimiento.yml). La línea base de
  // escribirLineasBase: 3,000 ms, +20 % y +25 ms.
  group('comparar-arranque', () {
    const cambio = 'build/resultados/arranque_en_frio.txt';
    const develop = 'build/resultados/arranque_develop.txt';

    int comparar() => _ejecutar([
          'comparar-arranque',
          cambio,
          'app_arranque_emulador',
          '--develop',
          develop,
        ]);

    setUp(escribirLineasBase);

    test('con develop decide develop, aunque la línea base fija no pasaría',
        () {
      // develop 4,000 ms → máximo 4,800; la línea base solo permite 3,600.
      _escribir(cambio, aperturas([4700, 4800, 4600]));
      _escribir(develop, aperturas([4000, 3900, 4100]));

      expect(comparar(), 0);
      expect(
        _salida.toString(),
        '### ⏱️ Arranque en frío contra develop\n\n✅ La mediana del arranque '
        'de este cambio es 4,700.00 ms: dentro del máximo; la de develop, '
        'medida en el mismo emulador, es 4,000.00 ms y el máximo permitido '
        '4,800.00 ms (falla solo si sube más de 20 % y más de 25 ms).\n',
      );
      expect(_resumen.readAsStringSync(), contains('contra develop'));
    });

    test('falla si sube más de 20 % y más de 25 ms sobre develop, aunque '
        'pase la línea base', () {
      // develop 2,000 ms → máximo 2,400; 2,500 pasaría la línea base fija.
      _escribir(cambio, aperturas([2500, 2500, 2500]));
      _escribir(develop, aperturas([2000, 2000, 2000]));

      expect(comparar(), 1);
      expect(
        _salida.toString(),
        contains('> ❌ La mediana del arranque de este cambio subió a '
            '2,500.00 ms: la de develop, medida en el mismo emulador, es '
            '2,000.00 ms'),
      );
    });

    test('igual a develop o justo en el máximo pasa; un ms más falla', () {
      _escribir(develop, aperturas([4000]));

      _escribir(cambio, aperturas([4000]));
      expect(comparar(), 0);
      _escribir(cambio, aperturas([4800]));
      expect(comparar(), 0);
      _escribir(cambio, aperturas([4801]));
      expect(comparar(), 1);
    });

    test('con un develop de pocos ms manda el piso de 25 ms', () {
      _escribir(develop, aperturas([100]));

      // +25 %, pero solo 25 ms más.
      _escribir(cambio, aperturas([125]));
      expect(comparar(), 0);
      _escribir(cambio, aperturas([126]));
      expect(comparar(), 1);
    });

    test('sin el archivo de develop decide la línea base y lo dice', () {
      _escribir(cambio, aperturas([3590, 3500, 9000]));

      expect(comparar(), 0);
      final texto = _salida.toString();
      expect(texto, startsWith('### ⏱️ Rendimiento contra la línea base'));
      expect(
        texto,
        contains('La mediana del arranque de «app_arranque_emulador» es '
            '3,590.00 ms'),
      );
      expect(texto, contains('No hubo aperturas de develop'));

      _escribir(cambio, aperturas([3601]));
      expect(comparar(), 1);
    });

    test('develop sin tiempos o sin --develop: decide la línea base', () {
      _escribir(cambio, aperturas([3700]));
      _escribir(develop, 'error: no devices/emulators found\n');

      expect(comparar(), 1);
      expect(
        _salida.toString(),
        contains('subió a 3,700.00 ms: la línea base es 3,000.00 ms'),
      );
      expect(_ejecutar(['comparar-arranque', cambio, 'app_arranque_emulador']),
          1);
    });

    test('falla sin la medición o sin línea base; sin la clave explica el uso',
        () {
      _escribir(develop, aperturas([4000]));

      expect(comparar(), 1);
      expect(_salida.toString(), contains('No se generó la medición'));

      _escribir(cambio, aperturas([4000]));
      File('${_raiz.path}/tool/linea_base_rendimiento.json').deleteSync();
      expect(comparar(), 1);
      expect(_salida.toString(), contains('no trae la línea base'));

      expect(_ejecutar(['comparar-arranque', cambio]), 64);
    });
  });

  // k6 contra el entorno aislado (rendimiento.yml y esfuerzo.yml).
  group('k6', () {
    String resumenDeK6({double p95 = 90}) => jsonEncode({
          'metrics': {
            'http_reqs': {'count': 600, 'rate': 20},
            'http_req_failed': {'value': 0},
            'http_req_duration': {'p(95)': p95, 'avg': 30, 'max': 200},
          },
        });

    test('resume la corrida y la compara con su línea base', () {
      _escribir('build/resultados/k6_rendimiento.json', resumenDeK6());
      escribirLineasBase();

      final codigo = _ejecutar([
        'k6',
        'build/resultados/k6_rendimiento.json',
        '--titulo',
        'Carga normal de la API (k6)',
        '--escenario',
        'api_carga_normal',
      ]);

      expect(codigo, 0);
      expect(
        _salida.toString(),
        contains('| 600 | 20.0 | 0.0 % | 90.00 ms |'),
      );
      expect(
        _salida.toString(),
        contains('✅ p95 90.00 ms contra la línea base'),
      );
    });

    test('sin el resumen avisa sin fallar el paso', () {
      expect(_ejecutar(['k6', 'no-existe.json', '--titulo', 'Carga']), 0);
      expect(_salida.toString(), contains('No se generó el resumen de k6'));
    });

    // Línea base de 80 ms: el +20 % (96 ms) es menor que el piso (105 ms).
    test('comparar-rendimiento: más de 20 % pero no más de 25 ms pasa', () {
      _escribir('k6.json', resumenDeK6(p95: 104.99));
      escribirLineasBase();

      expect(
        _ejecutar(['comparar-rendimiento', 'k6.json', 'api_carga_normal']),
        0,
      );
      expect(
        _salida.toString(),
        contains('✅ El p95 de «api_carga_normal» es 104.99 ms: dentro del '
            'máximo; la línea base es 80.00 ms y el máximo permitido '
            '105.00 ms (falla solo si sube más de 20 % y más de 25 ms).'),
      );
    });

    test('comparar-rendimiento falla si sube más de 20 % y más de 25 ms', () {
      _escribir('k6.json', resumenDeK6(p95: 105.01));
      escribirLineasBase();

      expect(
        _ejecutar(['comparar-rendimiento', 'k6.json', 'api_carga_normal']),
        1,
      );
      expect(_salida.toString(), contains('subió a 105.01 ms'));
    });

    test('comparar-rendimiento falla si no hay línea base', () {
      _escribir('k6.json', resumenDeK6());

      expect(
        _ejecutar(['comparar-rendimiento', 'k6.json', 'api_carga_normal']),
        1,
      );
      expect(_salida.toString(), contains('no trae la línea base'));
    });

    test('comparar-rendimiento falla si no se generó la medición', () {
      escribirLineasBase();

      expect(
        _ejecutar(['comparar-rendimiento', 'no-existe.json', 'api_carga_normal']),
        1,
      );
      expect(_salida.toString(), contains('No se generó la medición'));
    });

    test('comparar-rendimiento del arranque usa la mediana', () {
      escribirLineasBase();
      // Mediana 3,590 ms: debajo del +20 % de 3,000 (3,600 ms).
      _escribir('arranque.txt', aperturas([3590, 3500, 9000]));

      expect(
        _ejecutar([
          'comparar-rendimiento',
          'arranque.txt',
          'app_arranque_emulador',
        ]),
        0,
      );
      expect(
        _salida.toString(),
        contains('La mediana del arranque de «app_arranque_emulador» es '
            '3,590.00 ms'),
      );

      _escribir('arranque.txt', aperturas([3601, 3700, 3650]));
      expect(
        _ejecutar([
          'comparar-rendimiento',
          'arranque.txt',
          'app_arranque_emulador',
        ]),
        1,
      );
    });

    test('comparar-rendimiento del APK usa su peso y el +10 %', () {
      escribirLineasBase();
      _escribir('app-prod-release.apk', 'x' * 1100);

      expect(
        _ejecutar([
          'comparar-rendimiento',
          'app-prod-release.apk',
          'app_peso_apk',
        ]),
        0,
      );
      expect(
        _salida.toString(),
        contains('(falla si sube más de 10 %)'),
      );

      _escribir('app-prod-release.apk', 'x' * 1101);
      expect(
        _ejecutar([
          'comparar-rendimiento',
          'app-prod-release.apk',
          'app_peso_apk',
        ]),
        1,
      );
    });
  });

  // El job «Evidencias y decisión» de pipeline.yml.
  group('evidencias', () {
    List<String> argumentos({String esfuerzo = 'success'}) => [
          'evidencias',
          'build/evidencias',
          '--unitarias',
          'success',
          '--analisis',
          'success',
          '--aceptacion',
          'success',
          '--integracion',
          'success',
          '--regresion',
          'success',
          '--rendimiento',
          'success',
          '--esfuerzo',
          esfuerzo,
        ];

    test('saca las métricas de los artefactos de cada etapa', () {
      _escribir('tool/check_analysis.sh', _script);
      // Cada artefacto descargado en su propia carpeta, con sus rutas.
      const unitarias = 'build/evidencias/resultados-unitarias';
      _escribir('$unitarias/build/resultados/unitarias.json', _reporteVerde());
      _escribir(
        '$unitarias/coverage/lcov.info',
        'SF:lib/main.dart\nLF:4\nLH:3\nend_of_record\n',
      );
      _escribir(
        'build/evidencias/resultados-analisis/analisis.txt',
        '   info • Sort child properties last • lib/a.dart:1:1 • sort\n'
            '1 issue found.\n',
      );
      const aceptacion = 'build/evidencias/resultados-aceptacion';
      _escribir('$aceptacion/aceptacion.json', _reporteVerde());
      _escribir(
        'build/evidencias/resultados-aceptacion-emulador/'
            'aceptacion_emulador.json',
        jsonEncode({
          'aprobado': true,
          'pasos': [
            {'paso': '05_checkout', 'segundos': 40.0},
          ],
          'capturas': ['a.png'],
        }),
      );
      _escribir(
        'build/evidencias/resultados-integracion/integracion.json',
        _reporteVerde(),
      );
      _escribir(
        'build/evidencias/resultados-regresion/regresion.json',
        _reporteVerde(),
      );
      _escribir(
        'build/evidencias/rendimiento-apk/app-prod-release.apk',
        'x' * 2048,
      );
      _escribir(
        'build/evidencias/resultados-esfuerzo/monkey.txt',
        ':Monkey: seed=42 count=1000\nEvents injected: 1000\n'
            '// Monkey finished\n',
      );
      _escribir(
        'build/evidencias/resultados-esfuerzo/logcat.txt',
        'I/ActivityManager( 506): Start proc\n',
      );
      _escribir(
        'build/evidencias/resultados-esfuerzo/recuperacion.txt',
        '${aperturas([2345])}GET /api/health: 200\n',
      );
      // El emulador contra el entorno aislado: los flujos de compra, reseña
      // y entrega, y el arranque en frío.
      _escribir(
        'build/evidencias/resultados-flujo-entorno-aislado/'
            'flujo_entorno_aislado.json',
        _reporteVerde(),
      );
      _escribir(
        'build/evidencias/resultados-arranque/arranque_en_frio.txt',
        aperturas([3100, 2900, 3000]),
      );
      _escribir(
        'build/evidencias/resultados-arranque/arranque_develop.txt',
        aperturas([2800, 2900, 3000]),
      );
      // El entorno aislado: pruebas de la API y las dos corridas de k6.
      _escribir(
        'build/evidencias/resultados-api/build/resultados/api.json',
        _reporteVerde(),
      );
      _escribir(
        'build/evidencias/resultados-k6-rendimiento/k6_rendimiento.json',
        jsonEncode({
          'metrics': {
            'http_reqs': {'count': 820},
            'http_req_failed': {'value': 0},
            'http_req_duration': {'p(95)': 64.4},
          },
        }),
      );
      _escribir(
        'build/evidencias/resultados-k6-esfuerzo/k6_esfuerzo.json',
        jsonEncode({
          'metrics': {
            'http_reqs': {'count': 860},
            'http_req_failed': {'value': 0},
            'http_req_duration': {'p(95)': 150.2},
            'http_req_duration{fase:recuperacion}': {'p(95)': 20.6},
          },
        }),
      );

      expect(_ejecutar(argumentos()), 0);
      final texto = _salida.toString();
      expect(texto, contains('Rama `main` · commit `abc1234`'));
      expect(
        texto,
        contains(
          '| Unitarias y de widget | ✅ Pasó | ✅ 1 prueba pasó · '
          'cobertura 75.0 % |',
        ),
      );
      expect(
        texto,
        contains(
          '| Análisis estático | ✅ Pasó | ✅ 0 errores · 0 advertencias · '
          '1 aviso (línea base 0/0/151) |',
        ),
      );
      expect(
        texto,
        contains(
          '| Aceptación | ✅ Pasó | Gherkin: ✅ 1 prueba pasó · Emulador: '
          '✅ 1 paso · 1 capturas en 40.0 s |',
        ),
      );
      expect(
        texto,
        contains(
          '| Integración | ✅ Pasó | Emulador: ✅ 1 prueba pasó · API: ✅ 1 '
          'prueba pasó · Flujos de compra, reseña y entrega: ✅ 1 prueba '
          'pasó |',
        ),
      );
      expect(texto, contains('| Regresión | ✅ Pasó | ✅ 1 prueba pasó |'));
      expect(
        texto,
        contains(
          '| Rendimiento | ✅ Pasó | APK de release: 2.0 KB · Arranque en '
          'frío: mediana 3,000.00 ms (3 aperturas) · develop 2,900.00 ms '
          '(+3.4 %) · k6: 820 peticiones · p95 64.40 ms · 0.0 % errores |',
        ),
      );
      expect(
        texto,
        contains(
          '| Esfuerzo | ✅ Pasó | ✅ 1,000 eventos de monkey · 0 cierres · '
          '0 congelamientos · reabrió en 2,345.00 ms · k6: 860 peticiones · '
          'p95 150.20 ms · 0.0 % errores · recuperación p95 20.60 ms |',
        ),
      );
      expect(texto, contains('**Decisión:** ✅ pasaron las 7 etapas'));
    });

    test('una etapa sin artefactos queda sin métricas', () {
      expect(_ejecutar(argumentos(esfuerzo: 'skipped')), 0);

      final texto = _salida.toString();
      expect(
        texto,
        contains(
          '| Esfuerzo | ⏭️ No corrió: falló una etapa anterior | — |',
        ),
      );
      expect(texto, contains('**Decisión:** ❌ no pasaron: Esfuerzo.'));
    });

    test('en un Pull Request hacia develop la decisión nombra develop', () {
      final codigo = _ejecutar(
        argumentos(),
        entorno: const {
          'GITHUB_BASE_REF': 'develop',
          'GITHUB_HEAD_REF': 'feature/flujo-develop',
        },
      );

      expect(codigo, 0);
      final texto = _salida.toString();
      expect(texto, contains('Rama `feature/flujo-develop`'));
      expect(texto, contains('el Pull Request puede unirse a develop.'));
    });

    test('en un push a main la decisión nombra main', () {
      expect(_ejecutar(argumentos()), 0);

      final texto = _salida.toString();
      expect(texto, contains('pasaron las 7 etapas en main.'));
      expect(texto, isNot(contains('SonarCloud')));
    });

    test('en un push a develop la fila de análisis dice que el quality gate '
        'se verificó en el Pull Request', () {
      final codigo = _ejecutar(
        argumentos(),
        entorno: const {'GITHUB_BASE_REF': '', 'GITHUB_REF_NAME': 'develop'},
      );

      expect(codigo, 0);
      final texto = _salida.toString();
      expect(
        texto,
        contains(
          '| Análisis estático | ✅ Pasó | SonarCloud: análisis de develop '
          'subido; el quality gate se verificó en el Pull Request |',
        ),
      );
      expect(texto, contains('pasaron las 7 etapas en develop.'));
    });

    test('sin el resultado de alguna etapa explica el uso', () {
      final incompletos = argumentos().sublist(0, argumentos().length - 2);

      expect(_ejecutar(incompletos), 64);
    });
  });

  // #22: release.yml para la publicación si el tag no es la versión del
  // pubspec y toma de aquí las notas de la Release.
  group('version', () {
    test('el tag coincide con el pubspec', () {
      _escribir('pubspec.yaml', 'name: x\nversion: 1.2.0+3\n');

      expect(_ejecutar(['version', 'v1.2.0']), 0);
      expect(_salida.toString(), contains('✅'));
      expect(_resumen.readAsStringSync(), contains('v1.2.0'));
    });

    test('un tag distinto detiene la publicación', () {
      _escribir('pubspec.yaml', 'name: x\nversion: 1.2.0+3\n');

      expect(_ejecutar(['version', 'v1.3.0']), 1);
      expect(_salida.toString(), contains('❌'));
    });

    test('sin tag explica el uso', () {
      expect(_ejecutar(['version']), 64);
    });
  });

  group('notas', () {
    test('escribe las notas de los commits del archivo', () {
      _escribir(
        'build/resultados/commits.txt',
        'Merge pull request #165 from Ennimex/feat/sentry\n'
            'feat(monitoreo): errores y rendimiento en Sentry\n',
      );

      expect(
        _ejecutar(['notas', 'v1.2.0', 'build/resultados/commits.txt']),
        0,
      );
      expect(
        _salida.toString(),
        '## Pier Repostería v1.2.0\n\n### ✨ Nuevo\n\n'
        '- **monitoreo:** errores y rendimiento en Sentry\n',
      );
    });

    test('sin la lista de commits no publica notas vacías', () {
      expect(_ejecutar(['notas', 'v1.2.0', 'no-existe.txt']), 1);
      expect(_salida.toString(), contains('no-existe.txt'));
    });
  });

  test('un comando desconocido explica el uso', () {
    expect(_ejecutar(['otro']), 64);
    expect(_salida.toString(), contains('Comandos:'));
  });
}
