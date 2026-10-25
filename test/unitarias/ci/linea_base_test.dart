// test/unitarias/ci/linea_base_test.dart — la línea base de rendimiento
// (tool/linea_base_rendimiento.json) y su regla: una medición falla solo si
// la supera en más de su porcentaje y, además, en más de su piso en ms.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/linea_base.dart';

void main() {
  group('regla del porcentaje y el piso', () {
    // Una API de pocos milisegundos: el +20 % es menor que el piso.
    const apiRapida = LineaBase(
      medida: Medida.p95,
      valor: 7.22,
      toleranciaPorcentaje: 20,
      toleranciaMinima: 25,
    );

    test('con una línea base chica manda el piso: hasta 7.22 + 25 ms', () {
      expect(apiRapida.permitido, closeTo(32.22, 0.0001));
      // 8.67 ms ya es más de 20 % sobre 7.22, pero no más de 25 ms.
      expect(apiRapida.rebasa(8.67), isFalse);
      expect(apiRapida.rebasa(32.2), isFalse);
      expect(apiRapida.rebasa(32.23), isTrue);
    });

    test('con una línea base grande manda el porcentaje', () {
      const arranque = LineaBase(
        medida: Medida.medianaDeArranque,
        valor: 3000,
        toleranciaPorcentaje: 20,
        toleranciaMinima: 25,
      );

      // 3,100 ms ya es más de 25 ms sobre 3,000, pero no más de 20 %.
      expect(arranque.rebasa(3100), isFalse);
      expect(arranque.permitido, closeTo(3600, 0.0001));
      expect(arranque.rebasa(3600.01), isTrue);
    });

    test('sin piso solo cuenta el porcentaje', () {
      const peso = LineaBase(
        medida: Medida.peso,
        valor: 1000,
        toleranciaPorcentaje: 10,
      );

      expect(peso.rebasa(1100), isFalse);
      expect(peso.rebasa(1101), isTrue);
      expect(peso.regla, 'falla si sube más de 10 %');
    });

    test('la regla y las cantidades se dicen en las unidades de la medida', () {
      expect(apiRapida.regla, 'falla solo si sube más de 20 % y más de 25 ms');
      expect(apiRapida.formato(8.5596), '8.56 ms');
      expect(
        const LineaBase(
          medida: Medida.peso,
          valor: 1,
          toleranciaPorcentaje: 10,
        ).formato(41204220),
        '39.3 MB',
      );
    });

    test('el renglón de la comparación trae el veredicto y la regla', () {
      expect(
        comparacionConLineaBase('p95', 8.5596, apiRapida),
        '✅ p95 8.56 ms contra la línea base de 7.22 ms (máximo permitido '
        '32.22 ms: falla solo si sube más de 20 % y más de 25 ms).',
      );
      expect(
        comparacionConLineaBase('p95', 40, apiRapida),
        startsWith('❌ p95 40.00 ms'),
      );
    });
  });

  group('leerLineaBaseDeRendimiento', () {
    test('reconoce la medida por su campo y lee su tolerancia', () {
      final datos = {
        'api': {
          'p95_ms': 7.22,
          'tolerancia_porcentaje': 20,
          'tolerancia_minima_ms': 25,
          'corrida': '40202658750',
        },
        'arranque': {'mediana_ms': 2950.5, 'tolerancia_porcentaje': 20},
        'apk': {'bytes': 41204220, 'tolerancia_porcentaje': 10},
      };

      final api = leerLineaBaseDeRendimiento(datos, 'api')!;
      expect(api.medida, Medida.p95);
      expect(api.valor, 7.22);
      expect(api.toleranciaMinima, 25);
      expect(api.corrida, '40202658750');
      expect(
        leerLineaBaseDeRendimiento(datos, 'arranque')?.medida,
        Medida.medianaDeArranque,
      );
      final apk = leerLineaBaseDeRendimiento(datos, 'apk')!;
      expect(apk.medida, Medida.peso);
      expect(apk.toleranciaMinima, 0);
    });

    test('sin valor positivo o sin tolerancia no hay línea base', () {
      final datos = {
        'sin_medir': {'p95_ms': 0, 'tolerancia_porcentaje': 20},
        'sin_tolerancia': {'p95_ms': 7.22},
        'basura': 'texto',
      };

      expect(leerLineaBaseDeRendimiento(datos, 'sin_medir'), isNull);
      expect(leerLineaBaseDeRendimiento(datos, 'sin_tolerancia'), isNull);
      expect(leerLineaBaseDeRendimiento(datos, 'basura'), isNull);
      expect(leerLineaBaseDeRendimiento(datos, 'otra'), isNull);
    });

    // El archivo del repositorio: cada línea base que usa el pipeline está
    // completa y con la regla que pide la entrega.
    test('tool/linea_base_rendimiento.json trae las tres líneas base', () {
      final datos = jsonDecode(
        File('tool/linea_base_rendimiento.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final api = leerLineaBaseDeRendimiento(datos, 'api_carga_normal')!;
      expect(api.medida, Medida.p95);
      expect([api.toleranciaPorcentaje, api.toleranciaMinima], [20, 25]);

      final arranque =
          leerLineaBaseDeRendimiento(datos, 'app_arranque_emulador')!;
      expect(arranque.medida, Medida.medianaDeArranque);
      expect(
        [arranque.toleranciaPorcentaje, arranque.toleranciaMinima],
        [20, 25],
      );

      final apk = leerLineaBaseDeRendimiento(datos, 'app_peso_apk')!;
      expect(apk.medida, Medida.peso);
      expect([apk.toleranciaPorcentaje, apk.toleranciaMinima], [10, 0]);
    });
  });
}
