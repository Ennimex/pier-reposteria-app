// test/unitarias/ci/k6_test.dart — lectura del resumen de k6 (--summary-export)
// y comparación con la línea base de rendimiento.
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/k6.dart';

/// Resumen como lo deja `k6 run --summary-export` (métricas planas).
Map<String, dynamic> _resumen({double p95 = 120, double fallas = 0}) => {
      'metrics': {
        'http_reqs': {'count': 840, 'rate': 27.9},
        'http_req_failed': {'passes': 0, 'fails': 840, 'value': fallas},
        'http_req_duration': {
          'avg': 48.2,
          'min': 2.1,
          'med': 40.0,
          'max': 310.7,
          'p(90)': 95.0,
          'p(95)': p95,
        },
        'respuestas_429': {'count': 0, 'rate': 0},
      },
    };

void main() {
  group('leerK6', () {
    test('lee peticiones, errores y tiempos del resumen exportado', () {
      final reporte = leerK6(_resumen());

      expect(reporte.peticiones, 840);
      expect(reporte.porSegundo, 27.9);
      expect(reporte.tasaDeFallas, 0);
      expect(reporte.p95Ms, 120);
      expect(reporte.promedioMs, 48.2);
      expect(reporte.maximoMs, 310.7);
      expect(reporte.respuestas429, 0);
      expect(reporte.p95RecuperacionMs, isNull);
    });

    test('acepta las métricas dentro de «values» y la fase de recuperación',
        () {
      final reporte = leerK6({
        'metrics': {
          'http_reqs': {
            'values': {'count': 1700, 'rate': 9.4},
          },
          'http_req_duration': {
            'values': {'p(95)': 410.5, 'avg': 90, 'max': 1200},
          },
          'http_req_duration{fase:recuperacion}': {
            'values': {'p(95)': 35.0},
          },
          'http_req_failed{fase:recuperacion}': {
            'values': {'rate': 0.0},
          },
        },
      });

      expect(reporte.peticiones, 1700);
      expect(reporte.p95Ms, 410.5);
      expect(reporte.p95RecuperacionMs, 35);
      expect(reporte.tasaDeFallasRecuperacion, 0);
    });

    test('un resumen vacío no rompe nada: todo en cero', () {
      final reporte = leerK6({'metrics': 'basura'});

      expect(reporte.peticiones, 0);
      expect(reporte.p95Ms, 0);
    });
  });

  group('línea base', () {
    const base = LineaBaseK6(p95Ms: 100, corrida: '123');

    test('permite hasta 20 % más que la línea base', () {
      expect(p95Permitido(base), closeTo(120, 0.0001));
      // _resumen() trae un p95 de 120 ms: justo el máximo permitido.
      expect(rebasaLaLineaBase(leerK6(_resumen()), base), isFalse);
      expect(rebasaLaLineaBase(leerK6(_resumen(p95: 120.1)), base), isTrue);
    });

    test('lee la línea base del escenario; sin p95 no hay línea base', () {
      final datos = {
        'api_carga_normal': {'p95_ms': 85.5, 'corrida': '40200000000'},
        'api_sin_medir': {'p95_ms': 0},
      };

      expect(leerLineaBaseK6(datos, 'api_carga_normal')?.p95Ms, 85.5);
      expect(leerLineaBaseK6(datos, 'api_carga_normal')?.corrida,
          '40200000000');
      expect(leerLineaBaseK6(datos, 'api_sin_medir'), isNull);
      expect(leerLineaBaseK6(datos, 'otro'), isNull);
    });
  });

  group('resumenK6 y lineaK6', () {
    test('la tabla trae peticiones, errores, tiempos y la comparación', () {
      final texto = resumenK6(
        leerK6(_resumen()),
        titulo: 'Carga normal de la API (k6)',
        base: const LineaBaseK6(p95Ms: 110),
      );

      expect(texto, startsWith('### 📈 Carga normal de la API (k6)\n'));
      expect(
        texto,
        contains('| 840 | 27.9 | 0.0 % | 120 ms | 48 ms | 311 ms | 0 |'),
      );
      expect(
        texto,
        contains('✅ p95 120 ms contra la línea base de 110 ms (máximo '
            'permitido 132 ms, +20 %).'),
      );
    });

    test('marca con ❌ un p95 por encima del permitido', () {
      final texto = resumenK6(
        leerK6(_resumen(p95: 200)),
        titulo: 'Carga',
        base: const LineaBaseK6(p95Ms: 100),
      );

      expect(texto, contains('❌ p95 200 ms'));
    });

    test('la línea de evidencias resume la corrida', () {
      expect(
        lineaK6(leerK6(_resumen(fallas: 0.005))),
        'k6: 840 peticiones · p95 120 ms · 0.5 % errores',
      );
    });

    test('con fase de recuperación, la línea la incluye', () {
      final datos = _resumen();
      (datos['metrics'] as Map<String, dynamic>)[
          'http_req_duration{fase:recuperacion}'] = {'p(95)': 30.2};

      expect(lineaK6(leerK6(datos)), endsWith('· recuperación p95 30 ms'));
      expect(
        resumenK6(leerK6(datos), titulo: 'Esfuerzo'),
        contains('Recuperación después del pico: p95 30 ms · errores 0.0 %.'),
      );
    });
  });
}
