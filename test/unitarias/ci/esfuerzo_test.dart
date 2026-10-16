// test/unitarias/ci/esfuerzo_test.dart — lectura de la bitácora de monkey
// (adb shell monkey -v) y su resumen en la corrida (#157).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/esfuerzo.dart';

const _monkeyVerde = '''
:Monkey: seed=42 count=5000
:AllowPackage: mx.com.pierreposteria
// Event percentages:
//   0: 15.0%
:Sending Touch (ACTION_DOWN): 0:(540.0,1200.0)
Events injected: 5000
:Dropped: keys=0 pointers=0 trackballs=0 flips=0 rotations=0
## Network stats: elapsed time=48210ms (0ms mobile, 0ms wifi, 48210ms not connected)
// Monkey finished
''';

const _monkeyConCierre = '''
:Monkey: seed=42 count=5000
:Sending Touch (ACTION_DOWN): 0:(540.0,1200.0)
// CRASH: mx.com.pierreposteria (pid 4321)
// Short Msg: java.lang.IllegalStateException
// Long Msg: java.lang.IllegalStateException: Carrito vacío
// java.lang.IllegalStateException: Carrito vacío
// 	at mx.com.pierreposteria.MainActivity.onResume(MainActivity.kt:20)
//
** Monkey aborted due to error.
Events injected: 1234
''';

const _monkeyConAnr = '''
:Monkey: seed=7 count=500
// NOT RESPONDING: mx.com.pierreposteria (pid 99)
ANR in mx.com.pierreposteria (mx.com.pierreposteria/.MainActivity)
Reason: Input dispatching timed out

:Sending Touch (ACTION_UP): 0:(1.0,2.0)
Events injected: 500
// Monkey finished
''';

void main() {
  group('leerMonkey', () {
    test('lee semilla, eventos y tiempo de una corrida limpia', () {
      final corrida = leerMonkey(_monkeyVerde);

      expect(corrida.semilla, 42);
      expect(corrida.eventosPedidos, 5000);
      expect(corrida.eventosLanzados, 5000);
      expect(corrida.duracion, const Duration(milliseconds: 48210));
      expect(corrida.cierres, isEmpty);
      expect(corrida.congelamientos, isEmpty);
      expect(corrida.termino, isTrue);
    });

    test('guarda el bloque de cada cierre de la app', () {
      final corrida = leerMonkey(_monkeyConCierre);

      expect(corrida.cierres, hasLength(1));
      expect(
        corrida.cierres.single,
        startsWith('// CRASH: mx.com.pierreposteria (pid 4321)\n'
            '// Short Msg: java.lang.IllegalStateException'),
      );
      expect(corrida.cierres.single, isNot(contains('Monkey aborted')));
      expect(corrida.termino, isFalse);
      expect(corrida.eventosLanzados, 1234);
    });

    test('guarda el bloque de cada congelamiento hasta el renglón vacío', () {
      final corrida = leerMonkey(_monkeyConAnr);

      expect(corrida.congelamientos, hasLength(1));
      expect(
        corrida.congelamientos.single,
        '// NOT RESPONDING: mx.com.pierreposteria (pid 99)\n'
        'ANR in mx.com.pierreposteria (mx.com.pierreposteria/.MainActivity)\n'
        'Reason: Input dispatching timed out',
      );
    });
  });

  group('resumenMonkey', () {
    test('aprueba una corrida sin cierres ni congelamientos', () {
      final texto = resumenMonkey(leerMonkey(_monkeyVerde));

      expect(texto, startsWith('### 🐒 Uso aleatorio (monkey)\n'));
      expect(
        texto,
        contains('| ✅ Aprobado | 5,000 | 5,000 | 0 | 0 | 48 s | 42 |'),
      );
      expect(texto, contains('<summary>Últimos renglones de monkey.txt'));
    });

    test('muestra el cierre y los errores de logcat a la vista', () {
      final texto = resumenMonkey(
        leerMonkey(_monkeyConCierre),
        logcat: '10-15 12:00:00.000 I/ActivityManager( 1): Start proc\n'
            '10-15 12:00:01.000 E/AndroidRuntime( 4321): FATAL EXCEPTION: main\n'
            '10-15 12:00:01.001 E/flutter ( 4321): Bad state\n',
      );

      expect(texto, contains('| ❌ Falló | 5,000 | 1,234 | 1 | 0 |'));
      expect(texto, contains('#### ❌ La app se cerró (1)'));
      expect(texto, contains('// Long Msg: java.lang.IllegalStateException'));
      expect(texto, contains('#### Errores en logcat'));
      expect(texto, contains('E/AndroidRuntime( 4321): FATAL EXCEPTION'));
      expect(texto, isNot(contains('I/ActivityManager')));
    });

    test('marca como incompleta una corrida que no llegó al final', () {
      final texto = resumenMonkey(
        leerMonkey(':Monkey: seed=1 count=10\nEvents injected: 3\n'),
      );

      expect(texto, contains('| ⚠️ Incompleta | 10 | 3 | 0 | 0 |'));
    });
  });
}
