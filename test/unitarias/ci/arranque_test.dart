// test/unitarias/ci/arranque_test.dart — lectura de la salida de am start -W
// (tool/arranque_en_frio.sh) y el resumen del arranque en frío.
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/arranque.dart';
import '../../../tool/resumen/linea_base.dart';

/// Lo que imprime `adb shell am start -W` en Android 14 por cada apertura.
String _apertura(int totalMs, {String estado = 'ok'}) => '''
Starting: Intent { cmp=mx.com.pierreposteria/.MainActivity }
Status: $estado
LaunchState: COLD
Activity: mx.com.pierreposteria/.MainActivity
TotalTime: $totalMs
WaitTime: ${totalMs + 3}
Complete
''';

// La salida real cuando la ventana no apareció (corrida 40172543786): sin
// TotalTime.
const _sinVentana = '''
Starting: Intent { cmp=mx.com.pierreposteria/.MainActivity }
Status: timeout
LaunchState: UNKNOWN (-1)
Activity: mx.com.pierreposteria/.MainActivity
WaitTime: 10370
Complete
''';

void main() {
  group('leerAperturas', () {
    test('lee estado, tipo y tiempo de cada apertura', () {
      final aperturas = leerAperturas(
        '${_apertura(3469)}\r\n${_apertura(5601)}',
      );

      expect(aperturas, hasLength(2));
      expect(aperturas.first.estado, 'ok');
      expect(aperturas.first.tipo, 'COLD');
      expect(aperturas.first.totalMs, 3469);
      expect(aperturas.first.abrio, isTrue);
      expect(aperturas.last.totalMs, 5601);
    });

    test('una apertura sin ventana no trae tiempo', () {
      final apertura = leerAperturas(_sinVentana).single;

      expect(apertura.abrio, isFalse);
      expect(apertura.tipo, 'UNKNOWN');
      expect(apertura.totalMs, isNull);
    });

    test('sin «Starting:» no hay aperturas', () {
      expect(leerAperturas('error: no devices/emulators found'), isEmpty);
    });
  });

  group('medianaDeArranque', () {
    test('con 5 aperturas es la de en medio', () {
      final salida = [5601, 3469, 4651, 5670, 3900].map(_apertura).join();

      expect(medianaDeArranque(leerAperturas(salida)), 4651);
    });

    test('con un número par es el promedio de las dos de en medio', () {
      final salida = [3000, 1000, 2000, 4000].map(_apertura).join();

      expect(medianaDeArranque(leerAperturas(salida)), 2500);
    });

    test('sin tiempos no hay mediana', () {
      expect(medianaDeArranque(leerAperturas(_sinVentana)), isNull);
    });
  });

  group('resumenArranque y lineaArranque', () {
    final salida = [3469, 5601, 4651].map(_apertura).join();

    test('una fila por apertura, la mediana y la línea base', () {
      final texto = resumenArranque(
        leerAperturas(salida),
        base: const LineaBase(
          medida: Medida.medianaDeArranque,
          valor: 4000,
          toleranciaPorcentaje: 20,
          toleranciaMinima: 25,
        ),
      );

      expect(texto, startsWith('### 🚀 Arranque en frío en el emulador\n'));
      expect(texto, contains('| 2 | ✅ ok | COLD | 5,601.00 ms |'));
      expect(texto, contains('**Mediana: 4,651.00 ms** (3 aperturas).'));
      expect(
        texto,
        contains('✅ mediana 4,651.00 ms contra la línea base de 4,000.00 ms '
            '(máximo permitido 4,800.00 ms'),
      );
    });

    test('marca la apertura que no mostró su ventana', () {
      final texto = resumenArranque(leerAperturas('${_apertura(3000)}'
          '$_sinVentana'));

      expect(texto, contains('| 2 | ❌ timeout | UNKNOWN | — |'));
      expect(texto, contains('(2 aperturas)'));
    });

    test('sin tiempos avisa en vez de inventar una mediana', () {
      expect(
        resumenArranque(leerAperturas(_sinVentana)),
        contains('Ninguna apertura reportó su tiempo'),
      );
      expect(lineaArranque(const []), 'Arranque en frío: sin tiempos');
    });

    test('la línea de evidencias trae la mediana con 2 decimales', () {
      expect(
        lineaArranque(leerAperturas(salida)),
        'Arranque en frío: mediana 4,651.00 ms (3 aperturas)',
      );
    });

    test('cuenta las aperturas de calentamiento que no se contaron', () {
      expect(
        resumenArranque(leerAperturas(salida), descartadas: 1),
        contains('Aperturas de calentamiento sin contar: 1 (la primera '
            'después de cada instalación'),
      );
      expect(
        resumenArranque(leerAperturas(salida)),
        isNot(contains('calentamiento')),
      );
    });
  });

  // tool/arranque_alternado.sh: este cambio y develop en el mismo emulador.
  group('resumenArranqueContraDevelop', () {
    // La línea base fija de app_arranque_emulador: con develop solo informa.
    const base = LineaBase(
      medida: Medida.medianaDeArranque,
      valor: 4717,
      toleranciaPorcentaje: 20,
      toleranciaMinima: 25,
    );

    List<Apertura> aperturas(List<int> tiempos) =>
        leerAperturas(tiempos.map(_apertura).join());

    test('una fila por ronda, las dos medianas, la diferencia y quién decide',
        () {
      final texto = resumenArranqueContraDevelop(
        aperturas([4100, 4300, 4200]),
        aperturas([4000, 3900, 4100]),
        base: base,
        descartadas: 6,
        origen: 'APK de develop: corrida 41182773384, commit 623a76f.',
      );

      expect(texto, startsWith('### 🚀 Arranque en frío en el emulador\n'));
      expect(texto, contains('| Ronda | Este cambio | develop |'));
      expect(texto, contains('| 2 | ✅ 4,300.00 ms | ✅ 3,900.00 ms |'));
      expect(
        texto,
        contains('**Mediana de este cambio: 4,200.00 ms (3 aperturas) · de '
            'develop: 4,000.00 ms (3 aperturas) · diferencia: +5.0 %.**'),
      );
      expect(texto, contains('Aperturas de calentamiento sin contar: 6'));
      expect(
        texto,
        contains('✅ mediana 4,200.00 ms contra la mediana de develop, '
            '4,000.00 ms (máximo permitido 4,800.00 ms: falla solo si sube '
            'más de 20 % y más de 25 ms).'),
      );
      expect(
        texto,
        contains('ℹ️ Solo como referencia, porque decide develop: ✅ mediana '
            '4,200.00 ms contra la línea base de 4,717.00 ms'),
      );
      expect(
        texto,
        contains('APK de develop: corrida 41182773384, commit 623a76f.'),
      );
    });

    test('más de 20 % y más de 25 ms sobre develop es ❌ aunque pase la línea '
        'base', () {
      // develop 3,000 ms → máximo 3,600; 3,700 sigue debajo de la línea base
      // fija (5,660.40).
      final texto = resumenArranqueContraDevelop(
        aperturas([3700]),
        aperturas([3000]),
        base: base,
      );

      expect(texto, contains('diferencia: +23.3 %'));
      expect(
        texto,
        contains('❌ mediana 3,700.00 ms contra la mediana de develop, '
            '3,000.00 ms'),
      );
      expect(texto, contains('porque decide develop: ✅ mediana 3,700.00 ms'));
    });

    test('más rápido que develop: la diferencia es negativa', () {
      expect(
        resumenArranqueContraDevelop(aperturas([3600]), aperturas([4000])),
        contains('diferencia: -10.0 %'),
      );
    });

    test('rondas incompletas, aperturas sin ventana y sin línea base', () {
      final texto = resumenArranqueContraDevelop(
        leerAperturas('${_apertura(4000)}$_sinVentana'),
        aperturas([4000]),
      );

      expect(texto, contains('| 2 | ❌ timeout | — |'));
      expect(texto, contains('diferencia: 0.0 %'));
      // Sin línea base no hay regla con qué decidir.
      expect(texto, isNot(contains('máximo permitido')));
      expect(texto, isNot(contains('calentamiento')));
      expect(texto, isNot(contains('APK de develop')));
    });

    test('sin tiempos de develop queda el resumen con la línea base', () {
      final texto = resumenArranqueContraDevelop(
        aperturas([4000]),
        leerAperturas(_sinVentana),
        base: base,
        descartadas: 1,
      );

      expect(
        texto,
        contains('| Apertura | Ventana | Arranque | Hasta el primer cuadro |'),
      );
      expect(
        texto,
        contains('✅ mediana 4,000.00 ms contra la línea base de 4,717.00 ms'),
      );
      expect(texto, contains('Aperturas de calentamiento sin contar: 1'));
    });

    test('la línea de evidencias suma la mediana de develop', () {
      expect(
        lineaArranque(aperturas([4200]), develop: aperturas([4000])),
        'Arranque en frío: mediana 4,200.00 ms (1 apertura) · develop '
        '4,000.00 ms (+5.0 %)',
      );
      expect(
        lineaArranque(aperturas([4200]), develop: leerAperturas(_sinVentana)),
        'Arranque en frío: mediana 4,200.00 ms (1 apertura)',
      );
    });
  });
}
