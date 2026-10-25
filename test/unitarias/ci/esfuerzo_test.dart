// test/unitarias/ci/esfuerzo_test.dart — lectura de la bitácora de monkey
// (adb shell monkey -v), los cierres y congelamientos contados en logcat, la
// recuperación de la app y su resumen en la corrida (#157).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/arranque.dart';
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

// Fragmento real de la corrida del 15-oct (esfuerzo.yml, 1,000 eventos): el
// reporte del ANR llega por la salida de errores de monkey y trae datos del
// sistema hasta un renglón vacío; después viene el uso de CPU.
const _monkeyAnrReal = '''
:Monkey: seed=42 count=1000
:Sending Touch (ACTION_DOWN): 0:(1008.0,972.0)
    // Injection Failed
// NOT RESPONDING: mx.com.pierreposteria (pid 2395)
ANR in mx.com.pierreposteria (mx.com.pierreposteria/.MainActivity)
PID: 2395
Reason: Input dispatching timed out (Application does not have a focused window)
Parent: mx.com.pierreposteria/.MainActivity
----- Output from /proc/pressure/cpu -----
some avg10=52.28 avg60=24.39 avg300=6.10 total=18916649
----- End output from /proc/pressure/cpu -----

CPU usage from 14495ms to -1ms ago (2026-10-16 04:22:41.505 to 2026-10-16 04:22:56.001):
  24% 506/system_server: 17% user + 7.8% kernel / faults: 35225 minor 62 major
** Monkey aborted due to error.
Events injected: 5
''';

// Renglones reales de logcat (adb logcat -d -v time) de la corrida
// 40170191471, con el ANR al arrancar, más un cierre de Java y uno nativo
// con el formato de Android 14. Hay fallas de otras apps que no cuentan.
const _logcatConFallas = '''
10-25 07:17:05.618 I/WindowManager(  506): ANR in ActivityRecord{f7ce8a7 u0 mx.com.pierreposteria/.MainActivity t8}.  Reason: Input dispatching timed out
10-25 07:17:06.223 E/ActivityManager(  506): ANR in mx.com.pierreposteria (mx.com.pierreposteria/.MainActivity)
10-25 07:17:06.225 W/Monkey  ( 2330): ANR in mx.com.pierreposteria (mx.com.pierreposteria/.MainActivity)
10-25 07:20:01.000 E/AndroidRuntime( 4321): FATAL EXCEPTION: main
10-25 07:20:01.000 E/AndroidRuntime( 4321): Process: mx.com.pierreposteria, PID: 4321
10-25 07:21:00.000 F/DEBUG   ( 5000): pid: 4999, tid: 5010, name: 1.ui  >>> mx.com.pierreposteria <<<
10-25 07:22:00.000 E/AndroidRuntime( 777): Process: com.android.systemui, PID: 777
10-25 07:23:00.000 E/ActivityManager(  506): ANR in mx.com.pierreposteria.dev (mx.com.pierreposteria.dev/.MainActivity)
''';

void main() {
  group('contarFallasEnLogcat', () {
    test('cuenta una vez cada cierre y cada ANR de la app', () {
      final fallas = contarFallasEnLogcat(_logcatConFallas);

      // El cierre de Java y el nativo; el de systemui no es de la app.
      expect(fallas.cierres, 2);
      // Solo el de ActivityManager: ni el de WindowManager, ni el que repite
      // monkey, ni el de la app «Pier DEV».
      expect(fallas.congelamientos, 1);
    });

    test('un logcat limpio no tiene fallas', () {
      final fallas = contarFallasEnLogcat(
        '10-25 15:59:00.000 I/ActivityManager(  506): Start proc 3000:'
        'mx.com.pierreposteria/u0a190 for top-activity\n',
      );

      expect([fallas.cierres, fallas.congelamientos], [0, 0]);
    });

    test('monkey limpio y logcat con un cierre: la corrida falla', () {
      final corrida = leerMonkey(_monkeyVerde);

      expect(hayFallas(corrida), isFalse);
      expect(hayFallas(corrida, logcat: _logcatConFallas), isTrue);
      expect(
        resumenMonkey(corrida, logcat: _logcatConFallas),
        contains('| ❌ Falló | 5,000 | 5,000 | 2 | 1 |'),
      );
    });
  });

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

  group('leerMonkey con la bitácora real', () {
    test('el bloque del ANR trae el motivo y no se lleva el uso de CPU', () {
      final corrida = leerMonkey(_monkeyAnrReal);

      expect(corrida.congelamientos, hasLength(1));
      expect(
        corrida.congelamientos.single,
        contains('Reason: Input dispatching timed out'),
      );
      expect(corrida.congelamientos.single, isNot(contains('CPU usage')));
      expect(corrida.eventosLanzados, 5);
      expect(corrida.termino, isFalse);
    });

    test('el resumen marca la corrida como fallida', () {
      expect(
        resumenMonkey(leerMonkey(_monkeyAnrReal)),
        contains('| ❌ Falló | 1,000 | 5 | 0 | 1 |'),
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

    test('dice de dónde salen los conteos y cómo se recuperó la app', () {
      final texto = resumenMonkey(
        leerMonkey(_monkeyVerde),
        logcat: '10-25 16:00:00.000 I/ActivityManager(  506): Start proc\n',
        recuperacion: const Apertura(
          estado: 'ok',
          tipo: 'COLD',
          totalMs: 3210,
        ),
        salud: 200,
      );

      expect(texto, contains('| ✅ Aprobado | 5,000 | 5,000 | 0 | 0 |'));
      expect(texto, contains('contados en logcat'));
      expect(
        texto,
        contains('✅ Recuperación: la app volvió a abrir en frío en '
            '3,210.00 ms · GET /api/health: 200.'),
      );
    });

    test('una recuperación fallida se marca con ❌', () {
      final texto = resumenMonkey(
        leerMonkey(_monkeyVerde),
        recuperacion: const Apertura(estado: 'timeout', tipo: 'UNKNOWN'),
      );

      expect(
        texto,
        contains('❌ Recuperación: la app no volvió a abrir (am start -W: '
            'timeout) · GET /api/health: sin respuesta.'),
      );
    });
  });

  // La línea de la etapa «Esfuerzo» en la tabla de evidencias del pipeline.
  group('lineaMonkey', () {
    test('sin cierres ni congelamientos', () {
      expect(
        lineaMonkey(leerMonkey(_monkeyVerde)),
        '✅ 5,000 eventos de monkey · 0 cierres · 0 congelamientos',
      );
    });

    test('con un cierre', () {
      expect(
        lineaMonkey(leerMonkey(_monkeyConCierre)),
        '❌ 1,234 eventos de monkey · 1 cierres · 0 congelamientos',
      );
    });

    test('incompleta si monkey no llegó al final', () {
      expect(
        lineaMonkey(leerMonkey(':Monkey: seed=1 count=10\nEvents injected: 3\n')),
        '⚠️ 3 eventos de monkey · 0 cierres · 0 congelamientos',
      );
    });

    test('con los conteos de logcat y la reapertura', () {
      expect(
        lineaMonkey(
          leerMonkey(_monkeyVerde),
          logcat: _logcatConFallas,
          recuperacion: const Apertura(
            estado: 'ok',
            tipo: 'COLD',
            totalMs: 3210,
          ),
        ),
        '❌ 5,000 eventos de monkey · 2 cierres · 1 congelamientos · '
        'reabrió en 3,210.00 ms',
      );
      expect(
        lineaMonkey(
          leerMonkey(_monkeyVerde),
          recuperacion: const Apertura(estado: 'timeout', tipo: 'UNKNOWN'),
        ),
        endsWith('· ❌ no volvió a abrir'),
      );
    });
  });
}
