// test/unitarias/ci/pruebas_test.dart — lectura del reporte JSON de
// `flutter test --file-reporter json:...` y su resumen en Markdown (#157).
// Los eventos imitan los que escribe flutter test (protocolo 0.1.1).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/pruebas.dart';

const _raiz = '/home/runner/work/app/app';
const _archivo = '$_raiz/test/aceptacion/auth/inicio_sesion_test.dart';
const _url = 'file://$_raiz/test/aceptacion/auth/inicio_sesion_test.dart';

String _lineas(List<Map<String, Object?>> eventos) =>
    eventos.map(jsonEncode).join('\n');

Map<String, Object?> _suite() => {
      'type': 'suite',
      'suite': {'id': 0, 'platform': 'vm', 'path': _archivo},
    };

Map<String, Object?> _grupo(int id, int? padre, String nombre) => {
      'type': 'group',
      'group': {'id': id, 'suiteID': 0, 'parentID': padre, 'name': nombre},
    };

Map<String, Object?> _inicio(
  int id,
  String nombre, {
  List<int> grupos = const [2, 3],
  int linea = 10,
  bool widget = false,
}) =>
    {
      'type': 'testStart',
      'test': {
        'id': id,
        'name': nombre,
        'suiteID': 0,
        'groupIDs': grupos,
        'line': widget ? 174 : linea,
        'url': widget ? 'package:flutter_test/src/widget_tester.dart' : _url,
        if (widget) 'root_line': linea,
        if (widget) 'root_url': _url,
      },
    };

Map<String, Object?> _fin(
  int id, {
  String resultado = 'success',
  bool omitida = false,
  bool oculta = false,
}) =>
    {
      'type': 'testDone',
      'testID': id,
      'result': resultado,
      'skipped': omitida,
      'hidden': oculta,
    };

Map<String, Object?> _error(int id, String mensaje) =>
    {'type': 'error', 'testID': id, 'error': mensaje, 'stackTrace': ''};

Map<String, Object?> _impreso(int id, String mensaje) => {
      'type': 'print',
      'testID': id,
      'messageType': 'print',
      'message': mensaje,
    };

Map<String, Object?> _termino({bool exito = true, int ms = 112000}) =>
    {'type': 'done', 'success': exito, 'time': ms};

/// Carga oculta del archivo + 2 escenarios del grupo «#34 Inicio de sesión».
List<Map<String, Object?>> _corridaVerde() => [
      {'type': 'start', 'protocolVersion': '0.1.1'},
      _suite(),
      _inicio(1, 'loading $_archivo', grupos: []),
      _fin(1, oculta: true),
      _grupo(2, null, ''),
      _grupo(3, 2, '#34 Inicio de sesión'),
      _inicio(4, '#34 Inicio de sesión Escenario: credenciales válidas'),
      _fin(4),
      _inicio(5, '#34 Inicio de sesión Escenario: credenciales inválidas'),
      _fin(5),
    ];

void main() {
  group('leerReporte', () {
    test('cuenta solo las pruebas visibles, no la carga del archivo', () {
      final corrida = leerReporte(
        _lineas([..._corridaVerde(), _termino()]),
        raiz: _raiz,
      );

      expect(corrida.pruebas, hasLength(2));
      expect(corrida.pasaron, 2);
      expect(corrida.fallaron, 0);
      expect(corrida.duracion, const Duration(seconds: 112));
      expect(corrida.termino, isTrue);
      expect(corrida.exito, isTrue);
    });

    test('quita el grupo del nombre y deja la ruta relativa al repositorio',
        () {
      final prueba = leerReporte(
        _lineas(_corridaVerde()),
        raiz: _raiz,
      ).pruebas.first;

      expect(prueba.grupo, '#34 Inicio de sesión');
      expect(prueba.nombre, 'Escenario: credenciales válidas');
      expect(prueba.archivo, 'test/aceptacion/auth/inicio_sesion_test.dart');
      expect(prueba.linea, 10);
    });

    test('sin la raíz, recorta la ruta desde la carpeta test/', () {
      final prueba = leerReporte(_lineas(_corridaVerde())).pruebas.first;

      expect(prueba.archivo, 'test/aceptacion/auth/inicio_sesion_test.dart');
    });

    test('una prueba sin grupo se agrupa por su archivo', () {
      final prueba = leerReporte(
        _lineas([
          _suite(),
          _grupo(2, null, ''),
          _inicio(4, 'arranca la app', grupos: [2], linea: 22),
          _fin(4),
        ]),
        raiz: _raiz,
      ).pruebas.single;

      expect(prueba.grupo, 'test/aceptacion/auth/inicio_sesion_test.dart');
      expect(prueba.nombre, 'arranca la app');
    });

    test('guarda el error de expect de una prueba que falla', () {
      final prueba = leerReporte(
        _lineas([
          ..._corridaVerde(),
          _inicio(6, '#34 Inicio de sesión Escenario: total', linea: 40),
          _error(6, 'Expected: <0.0>\n  Actual: <35.0>\n'),
          _fin(6, resultado: 'failure'),
          _termino(exito: false),
        ]),
        raiz: _raiz,
      ).pruebas.last;

      expect(prueba.estado, EstadoPrueba.fallo);
      expect(prueba.detalle, 'Expected: <0.0>\n  Actual: <35.0>');
    });

    test(
        'en una prueba de widget toma el error del registro de la excepción '
        'y su línea de testWidgets', () {
      final prueba = leerReporte(
        _lineas([
          ..._corridaVerde(),
          _inicio(
            6,
            '#34 Inicio de sesión Escenario: saludo',
            widget: true,
            linea: 14,
          ),
          _impreso(
            6,
            '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞══════════\n'
            'The following TestFailure was thrown running a test:\n'
            'Expected: exactly one matching candidate\n'
            '  Actual: _TextWidgetFinder:<Found 0 widgets>\n'
            '\n'
            'When the exception was thrown, this was the stack:\n'
            '#4      main.<anonymous closure> (file:///x_test.dart:16:7)\n'
            '═══════════════════════════════════════════════════════════',
          ),
          _error(
            6,
            'Test failed. See exception logs above.\n'
            'The test description was: Escenario: saludo',
          ),
          _fin(6, resultado: 'error'),
        ]),
        raiz: _raiz,
      ).pruebas.last;

      expect(prueba.estado, EstadoPrueba.fallo);
      expect(prueba.linea, 14);
      expect(
        prueba.detalle,
        'The following TestFailure was thrown running a test:\n'
        'Expected: exactly one matching candidate\n'
        '  Actual: _TextWidgetFinder:<Found 0 widgets>',
      );
    });

    test('recorta un error muy largo a 30 renglones', () {
      final largo = List.generate(50, (i) => 'renglón $i').join('\n');
      final prueba = leerReporte(
        _lineas([
          ..._corridaVerde(),
          _inicio(6, '#34 Inicio de sesión Escenario: largo'),
          _error(6, largo),
          _fin(6, resultado: 'failure'),
        ]),
        raiz: _raiz,
      ).pruebas.last;

      final renglones = prueba.detalle.split('\n');
      expect(renglones, hasLength(31));
      expect(renglones.last, '… (20 renglones más en el log del paso)');
    });

    test('marca las omitidas con su motivo', () {
      final corrida = leerReporte(
        _lineas([
          ..._corridaVerde(),
          _inicio(6, '#34 Inicio de sesión Escenario: con Google'),
          {
            'type': 'print',
            'testID': 6,
            'messageType': 'skip',
            'message': 'Skip: Falta el backend',
          },
          _fin(6, omitida: true),
        ]),
        raiz: _raiz,
      );

      expect(corrida.omitidas, 1);
      expect(corrida.pruebas.last.estado, EstadoPrueba.omitida);
      expect(corrida.pruebas.last.detalle, 'Falta el backend');
    });

    test('sin el evento final la corrida queda como no terminada', () {
      final corrida = leerReporte(_lineas(_corridaVerde()), raiz: _raiz);

      expect(corrida.termino, isFalse);
      expect(corrida.duracion, isNull);
    });

    test('ignora renglones vacíos o que no son JSON', () {
      final corrida = leerReporte(
        '\n${_lineas(_corridaVerde())}\nesto no es JSON\n',
        raiz: _raiz,
      );

      expect(corrida.pruebas, hasLength(2));
    });
  });

  group('resumenPruebas', () {
    test('muestra la tabla de totales con el resultado aprobado', () {
      final texto = resumenPruebas(
        leerReporte(_lineas([..._corridaVerde(), _termino()]), raiz: _raiz),
        titulo: 'Escenarios de aceptación',
      );

      expect(texto, startsWith('### 🧪 Escenarios de aceptación\n'));
      expect(
        texto,
        contains('| ✅ Aprobado | 2 | 2 | 0 | 0 | 1 min 52 s |'),
      );
      expect(texto, isNot(contains('fallaron')));
    });

    test('lista cada prueba que falló con su archivo, línea y error', () {
      final texto = resumenPruebas(
        leerReporte(
          _lineas([
            ..._corridaVerde(),
            _inicio(6, '#34 Inicio de sesión Escenario: total', linea: 40),
            _error(6, 'Expected: <0.0>\n  Actual: <35.0>'),
            _fin(6, resultado: 'failure'),
            _termino(exito: false),
          ]),
          raiz: _raiz,
        ),
        titulo: 'Pruebas unitarias',
      );

      expect(texto, contains('| ❌ Falló | 3 | 2 | 1 | 0 |'));
      expect(texto, contains('#### ❌ Pruebas que fallaron (1)'));
      expect(
        texto,
        contains(
          '**#34 Inicio de sesión › Escenario: total**  \n'
          '`test/aceptacion/auth/inicio_sesion_test.dart:40`\n'
          '```text\nExpected: <0.0>\n  Actual: <35.0>\n```\n',
        ),
      );
    });

    test(
        'si el reporte no trae el error (pruebas en el emulador), dice dónde '
        'verlo', () {
      final texto = resumenPruebas(
        leerReporte(
          _lineas([
            ..._corridaVerde(),
            _inicio(6, '#34 Inicio de sesión Escenario: en el emulador'),
            _fin(6, resultado: 'error'),
          ]),
          raiz: _raiz,
        ),
        titulo: 'Flujo de compra',
      );

      expect(
        texto,
        contains(
          '**#34 Inicio de sesión › Escenario: en el emulador**  \n'
          '`test/aceptacion/auth/inicio_sesion_test.dart:10`\n'
          '> El reporte no trae el detalle del error: búscalo en el log del '
          'paso que corrió las pruebas.\n',
        ),
      );
    });

    test('muestra hasta 20 fallas y avisa cuántas más hay', () {
      final texto = resumenPruebas(
        leerReporte(
          _lineas([
            ..._corridaVerde(),
            for (var i = 10; i < 35; i++) ...[
              _inicio(i, '#34 Inicio de sesión falla $i'),
              _error(i, 'error $i'),
              _fin(i, resultado: 'failure'),
            ],
          ]),
          raiz: _raiz,
        ),
        titulo: 'Pruebas unitarias',
      );

      expect('**#34 Inicio de sesión ›'.allMatches(texto), hasLength(20));
      expect(texto, contains('…y 5 más en el log del paso.'));
    });

    test('con detalle, lista cada prueba agrupada por historia', () {
      final texto = resumenPruebas(
        leerReporte(
          _lineas([
            ..._corridaVerde(),
            _inicio(6, '#34 Inicio de sesión Escenario: con Google'),
            {
              'type': 'print',
              'testID': 6,
              'messageType': 'skip',
              'message': 'Skip: Falta el backend',
            },
            _fin(6, omitida: true),
            _termino(),
          ]),
          raiz: _raiz,
        ),
        titulo: 'Escenarios de aceptación',
        detalle: true,
      );

      expect(
        texto,
        contains(
          '**#34 Inicio de sesión** (2 de 3 pasaron)\n\n'
          '- ✅ Escenario: credenciales válidas\n'
          '- ✅ Escenario: credenciales inválidas\n'
          '- ⏭️ Escenario: con Google (omitida: Falta el backend)\n',
        ),
      );
    });

    test('ordena las historias por número aunque terminen en otro orden', () {
      final texto = resumenPruebas(
        leerReporte(
          _lineas([
            _suite(),
            _grupo(2, null, ''),
            _grupo(3, 2, '#36 Checkout'),
            _grupo(4, 2, '#100 Reseñas'),
            _grupo(5, 2, '#33 Registro'),
            _inicio(6, '#36 Checkout pago', grupos: [2, 3]),
            _fin(6),
            _inicio(7, '#100 Reseñas calificar', grupos: [2, 4]),
            _fin(7),
            _inicio(8, '#33 Registro verificar', grupos: [2, 5]),
            _fin(8),
          ]),
          raiz: _raiz,
        ),
        titulo: 'Escenarios de aceptación',
        detalle: true,
      );

      final orden = ['**#33 Registro**', '**#36 Checkout**', '**#100 Reseñas**']
          .map(texto.indexOf)
          .toList();
      expect(orden, everyElement(greaterThan(-1)));
      expect(orden, orderedEquals([...orden]..sort()));
    });

    test('avisa cuando la corrida no terminó', () {
      final texto = resumenPruebas(
        leerReporte(_lineas(_corridaVerde()), raiz: _raiz),
        titulo: 'Pruebas unitarias',
      );

      expect(texto, contains('| ⚠️ Incompleta | 2 | 2 | 0 | 0 | — |'));
      expect(texto, contains('se detuvo antes de terminar'));
    });

    test('avisa cuando no corrió ninguna prueba', () {
      final texto = resumenPruebas(
        leerReporte(_lineas([_termino()])),
        titulo: 'Volumen de datos',
      );

      expect(texto, contains('| ⚠️ Sin pruebas | 0 | 0 | 0 | 0 |'));
    });
  });

  group('lineaPruebas', () {
    test('resume una corrida verde en una línea', () {
      expect(
        lineaPruebas(
          leerReporte(_lineas([..._corridaVerde(), _termino()]), raiz: _raiz),
        ),
        '✅ 2 pruebas pasaron',
      );
    });

    test('dice cuántas fallaron y cuántas se omitieron', () {
      final corrida = leerReporte(
        _lineas([
          ..._corridaVerde(),
          _inicio(6, '#34 Inicio de sesión falla'),
          _fin(6, resultado: 'failure'),
          _inicio(7, '#34 Inicio de sesión omitida'),
          _fin(7, omitida: true),
          _termino(exito: false),
        ]),
        raiz: _raiz,
      );

      expect(lineaPruebas(corrida), '❌ 1 de 4 pruebas fallaron · 1 omitida');
    });
  });
}
