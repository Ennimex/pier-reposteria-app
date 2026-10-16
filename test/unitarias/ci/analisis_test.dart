// test/unitarias/ci/analisis_test.dart — lectura de la salida de
// flutter analyze y su comparación con la línea base de
// tool/check_analysis.sh en el resumen de la corrida (#157).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/analisis.dart';

// Renglones reales de la corrida de main del 15-oct (formato de Linux).
const _salidaCi = '''
Analyzing pier-reposteria-app...

   info • Catch clause should use 'on' to specify the type of exception being caught. Try adding an 'on' clause before the 'catch' • lib/data/repositories/demanda_repository_remote.dart:45:7 • avoid_catches_without_on_clauses
   info • Constructor declarations should be before non-constructor declarations. Try moving the constructor declaration before all other members • lib/domain/models/order_model.dart:99:11 • sort_constructors_first
   info • Constructor declarations should be before non-constructor declarations. Try moving the constructor declaration before all other members • lib/domain/models/product_model.dart:26:3 • sort_constructors_first

3 issues found. (ran in 19.8s)
''';

const _base = LineaBase(errores: 0, advertencias: 0, avisos: 151);

void main() {
  group('leerAnalisis', () {
    test('lee gravedad, mensaje, archivo, línea y regla', () {
      final hallazgos = leerAnalisis(_salidaCi);

      expect(hallazgos, hasLength(3));
      final primero = hallazgos.first;
      expect(primero.gravedad, Gravedad.aviso);
      expect(
        primero.ubicacion,
        'lib/data/repositories/demanda_repository_remote.dart:45',
      );
      expect(primero.regla, 'avoid_catches_without_on_clauses');
      expect(
        primero.mensaje,
        startsWith("Catch clause should use 'on' to specify"),
      );
    });

    test('entiende el formato de Windows, que separa con guiones', () {
      final hallazgo = leerAnalisis(
        '  warning - Unused import: x - lib/main.dart:3:8 - unused_import\r\n'
        '  error - Undefined name - lib/ui/a-b.dart:9:1 - undefined_identifier',
      );

      expect(hallazgo.map((h) => h.gravedad), [
        Gravedad.advertencia,
        Gravedad.error,
      ]);
      expect(hallazgo.first.mensaje, 'Unused import: x');
      expect(hallazgo.last.ubicacion, 'lib/ui/a-b.dart:9');
    });
  });

  group('leerLineaBase', () {
    test('toma los valores de tool/check_analysis.sh', () {
      final base = leerLineaBase(
        '#!/usr/bin/env bash\nbaseline_errors=0\nbaseline_warnings=2\n'
        'baseline_infos=151\n',
      );

      expect(base?.errores, 0);
      expect(base?.advertencias, 2);
      expect(base?.avisos, 151);
    });

    test('devuelve null si falta alguno', () {
      expect(leerLineaBase('baseline_errors=0\n'), isNull);
    });
  });

  group('resumenAnalisis', () {
    test('compara cada gravedad con la línea base', () {
      expect(
        resumenAnalisis(leerAnalisis(_salidaCi), _base),
        contains(
          '| | Encontrados | Línea base | |\n'
          '|---|--:|--:|:-:|\n'
          '| Errores | 0 | 0 | ✅ |\n'
          '| Advertencias | 0 | 0 | ✅ |\n'
          '| Avisos | 3 | 151 | ✅ |\n',
        ),
      );
    });

    test('sugiere bajar la línea base cuando el análisis mejoró', () {
      expect(
        resumenAnalisis(leerAnalisis(_salidaCi), _base),
        contains('bájala a 0/0/3 en `tool/check_analysis.sh`'),
      );
    });

    test('agrupa los avisos por regla en una sección plegable', () {
      final texto = resumenAnalisis(leerAnalisis(_salidaCi), _base);

      expect(texto, contains('<summary>Avisos por regla (3)</summary>'));
      expect(
        texto,
        contains(
          '| `sort_constructors_first` | 2 | Constructor declarations should '
          'be before non-constructor declarations. |\n'
          '| `avoid_catches_without_on_clauses` | 1 |',
        ),
      );
      expect(
        texto,
        contains(
          '| `lib/domain/models/order_model.dart:99` '
          '| `sort_constructors_first` |',
        ),
      );
    });

    test('muestra a la vista los errores y advertencias, y marca la línea '
        'base rebasada', () {
      final texto = resumenAnalisis(
        leerAnalisis(
          '  warning • Unused import • lib/main.dart:3:8 • unused_import',
        ),
        _base,
      );

      expect(texto, contains('| Advertencias | 1 | 0 | ❌ |'));
      expect(texto, contains('#### Errores y advertencias (1)'));
      expect(
        texto,
        contains('| ⚠️ | `lib/main.dart:3` | `unused_import` | Unused import |'),
      );
      expect(texto, contains('rebasa la línea base'));
      expect(texto, isNot(contains('<summary>Avisos por regla')));
    });
  });

  group('lineaAnalisis', () {
    test('resume los conteos contra la línea base en una línea', () {
      expect(
        lineaAnalisis(leerAnalisis(_salidaCi), _base),
        '✅ 0 errores · 0 advertencias · 3 avisos (línea base 0/0/151)',
      );
    });

    test('marca con ❌ si rebasa la línea base', () {
      expect(
        lineaAnalisis(
          leerAnalisis('  error • x • lib/main.dart:1:1 • some_rule'),
          _base,
        ),
        startsWith('❌ 1 error ·'),
      );
    });
  });
}
