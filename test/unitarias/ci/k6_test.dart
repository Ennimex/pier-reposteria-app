// test/unitarias/ci/k6_test.dart — lectura del resumen de k6 (--summary-export)
// y comparación con la línea base de rendimiento (la regla se prueba en
// linea_base_test.dart).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/k6.dart';
import '../../../tool/resumen/linea_base.dart';

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

  group('resumenK6 y lineaK6', () {
    // La misma regla de tool/linea_base_rendimiento.json: +20 % y +25 ms.
    const base = LineaBase(
      medida: Medida.p95,
      valor: 110,
      toleranciaPorcentaje: 20,
      toleranciaMinima: 25,
    );

    test('la tabla trae peticiones, errores, tiempos y la comparación', () {
      final texto = resumenK6(
        leerK6(_resumen()),
        titulo: 'Carga normal de la API (k6)',
        base: base,
      );

      expect(texto, startsWith('### 📈 Carga normal de la API (k6)\n'));
      expect(
        texto,
        contains(
          '| 840 | 27.9 | 0.0 % | 120.00 ms | 48.20 ms | 310.70 ms | 0 |',
        ),
      );
      expect(
        texto,
        contains('✅ p95 120.00 ms contra la línea base de 110.00 ms (máximo '
            'permitido 135.00 ms: falla solo si sube más de 20 % y más de '
            '25 ms).'),
      );
    });

    test('marca con ❌ un p95 por encima del permitido', () {
      final texto = resumenK6(
        leerK6(_resumen(p95: 200)),
        titulo: 'Carga',
        base: base,
      );

      expect(texto, contains('❌ p95 200.00 ms'));
    });

    test('la línea de evidencias resume la corrida con 2 decimales', () {
      expect(
        lineaK6(leerK6(_resumen(p95: 8.5596, fallas: 0.005))),
        'k6: 840 peticiones · p95 8.56 ms · 0.5 % errores',
      );
    });

    test('con fase de recuperación, la línea la incluye', () {
      final datos = _resumen();
      (datos['metrics'] as Map<String, dynamic>)[
          'http_req_duration{fase:recuperacion}'] = {'p(95)': 30.2};

      expect(
        lineaK6(leerK6(datos)),
        endsWith('· recuperación p95 30.20 ms'),
      );
      expect(
        resumenK6(leerK6(datos), titulo: 'Esfuerzo'),
        contains(
          'Recuperación después del pico: p95 30.20 ms · errores 0.0 %.',
        ),
      );
    });
  });
}
