// tool/resumen/esfuerzo.dart — lee la bitácora de monkey (adb shell monkey
// -v, monkey.txt) y los mensajes del celular (logcat.txt), y arma su resumen
// con los cierres y congelamientos y la recuperación de la app (#157).
import 'dart:convert';
import 'dart:math';

import 'arranque.dart';
import 'markdown.dart';

/// La app que prueba monkey: la versión de producción, la que se arma sin
/// --flavor (android/app/build.gradle.kts).
const paqueteDeLaApp = 'mx.com.pierreposteria';

class CorridaMonkey {
  const CorridaMonkey({
    required this.cierres,
    required this.congelamientos,
    required this.termino,
    required this.ultimos,
    this.semilla,
    this.eventosPedidos,
    this.eventosLanzados,
    this.duracion,
  });

  /// Bloque «// CRASH: …» de cada vez que la app se cerró.
  final List<String> cierres;

  /// Bloque «// NOT RESPONDING: …» (ANR) de cada vez que se congeló.
  final List<String> congelamientos;

  /// monkey escribió «// Monkey finished».
  final bool termino;

  /// Últimos renglones de la bitácora.
  final String ultimos;
  final int? semilla;
  final int? eventosPedidos;
  final int? eventosLanzados;
  final Duration? duracion;
}

const _maximoPorBloque = 40;
const _ultimosRenglones = 30;

CorridaMonkey leerMonkey(String bitacora) {
  final renglones = const LineSplitter().convert(bitacora);
  final cierres = <String>[];
  final congelamientos = <String>[];

  var i = 0;
  while (i < renglones.length) {
    final renglon = renglones[i];
    final esCierre = renglon.startsWith('// CRASH');
    final esCongelamiento =
        renglon.startsWith('// NOT RESPONDING') || renglon.startsWith('ANR in ');
    if (!esCierre && !esCongelamiento) {
      i++;
      continue;
    }
    // El cierre sigue en renglones «// …»; el ANR, hasta un renglón vacío.
    final bloque = [renglon];
    i++;
    while (i < renglones.length &&
        (esCierre
            ? renglones[i].startsWith('//')
            : renglones[i].trim().isNotEmpty)) {
      bloque.add(renglones[i]);
      i++;
    }
    while (bloque.length > 1 && bloque.last.trim() == '//') {
      bloque.removeLast();
    }
    (esCierre ? cierres : congelamientos)
        .add(bloque.take(_maximoPorBloque).join('\n'));
  }

  final encabezado = RegExp(r':Monkey: seed=(-?\d+) count=(\d+)')
      .firstMatch(bitacora);
  final lanzados = RegExp(r'^Events injected: (\d+)', multiLine: true)
      .allMatches(bitacora)
      .lastOrNull;
  final tiempo = RegExp(r'elapsed time=(\d+)ms').firstMatch(bitacora);

  return CorridaMonkey(
    cierres: cierres,
    congelamientos: congelamientos,
    termino: renglones.any((r) => r.trim() == '// Monkey finished'),
    ultimos: renglones
        .skip(renglones.length > _ultimosRenglones
            ? renglones.length - _ultimosRenglones
            : 0)
        .join('\n'),
    semilla: _entero(encabezado?.group(1)),
    eventosPedidos: _entero(encabezado?.group(2)),
    eventosLanzados: _entero(lanzados?.group(1)),
    duracion: tiempo == null
        ? null
        : Duration(milliseconds: int.parse(tiempo.group(1)!)),
  );
}

/// Cuántas veces registró Android en logcat que la app se cerró o se
/// congeló.
class FallasEnLogcat {
  const FallasEnLogcat({required this.cierres, required this.congelamientos});

  final int cierres;
  final int congelamientos;
}

/// Cuenta en [logcat] (adb logcat -d -v time) los renglones que Android
/// escribe una sola vez por falla de la app [paquete]:
///   · cierre de Java o Kotlin: `E/AndroidRuntime(…): Process: <paquete>, PID: …`;
///   · cierre nativo: `F/DEBUG(…): pid: …, name: …  >>> <paquete> <<<`;
///   · congelamiento (ANR): `E/ActivityManager(…): ANR in <paquete> …`.
/// Los de otras apps no cuentan, ni el «ANR in» que repite monkey.
FallasEnLogcat contarFallasEnLogcat(
  String logcat, {
  String paquete = paqueteDeLaApp,
}) {
  final app = RegExp.escape(paquete);
  final cierreDeJava = RegExp('AndroidRuntime.*: Process: $app, PID:');
  final cierreNativo = RegExp('>>> $app <<<');
  final congelamiento = RegExp('ActivityManager.*: ANR in $app( |\$)');
  var cierres = 0;
  var congelamientos = 0;
  for (final renglon in const LineSplitter().convert(logcat)) {
    if (cierreDeJava.hasMatch(renglon) || cierreNativo.hasMatch(renglon)) {
      cierres++;
    } else if (congelamiento.hasMatch(renglon)) {
      congelamientos++;
    }
  }
  return FallasEnLogcat(cierres: cierres, congelamientos: congelamientos);
}

/// Cierres y congelamientos de la corrida: los que registró logcat o, si
/// logcat no los alcanzó a guardar, los que reportó monkey (el mayor).
FallasEnLogcat fallasDeLaCorrida(CorridaMonkey corrida, String logcat) {
  final enLogcat = contarFallasEnLogcat(logcat);
  return FallasEnLogcat(
    cierres: max(enLogcat.cierres, corrida.cierres.length),
    congelamientos: max(enLogcat.congelamientos, corrida.congelamientos.length),
  );
}

bool hayFallas(CorridaMonkey corrida, {String logcat = ''}) {
  final fallas = fallasDeLaCorrida(corrida, logcat);
  return fallas.cierres > 0 || fallas.congelamientos > 0;
}

/// Tabla de la corrida, con los cierres y congelamientos contados en
/// [logcat]; si hubo, su bloque de monkey y los errores de logcat a la
/// vista; después, la [recuperacion] (la app reabierta en frío) y la
/// respuesta de /api/health ([salud]); la cola de monkey.txt, plegada.
String resumenMonkey(
  CorridaMonkey corrida, {
  String logcat = '',
  Apertura? recuperacion,
  int? salud,
}) {
  final fallas = fallasDeLaCorrida(corrida, logcat);
  final conFallas = fallas.cierres > 0 || fallas.congelamientos > 0;
  final veredicto = conFallas
      ? '❌ Falló'
      : corrida.termino
          ? '✅ Aprobado'
          : '⚠️ Incompleta';
  final texto = StringBuffer()
    ..writeln('### 🐒 Uso aleatorio (monkey)')
    ..writeln()
    ..writeln(
      '| Resultado | Eventos pedidos | Eventos lanzados | Cierres '
      '| Congelamientos | Tiempo | Semilla |',
    )
    ..writeln('|:-:|--:|--:|--:|--:|--:|--:|')
    ..writeln(
      '| $veredicto | ${_numero(corrida.eventosPedidos)} '
      '| ${_numero(corrida.eventosLanzados)} '
      '| ${miles(fallas.cierres)} '
      '| ${miles(fallas.congelamientos)} '
      '| ${corrida.duracion == null ? '—' : duracion(corrida.duracion!)} '
      '| ${corrida.semilla ?? '—'} |',
    )
    ..writeln();
  if (logcat.isNotEmpty) {
    texto
      ..writeln(
        'Cierres y congelamientos contados en logcat (`AndroidRuntime`, '
        '`ActivityManager: ANR in`).',
      )
      ..writeln();
  }
  if (recuperacion != null) {
    texto
      ..writeln(_lineaRecuperacion(recuperacion, salud))
      ..writeln();
  }

  if (!conFallas && !corrida.termino) {
    texto
      ..writeln(
        '> ⚠️ monkey no llegó al final: revisa el log del paso para saber '
        'por qué se detuvo.',
      )
      ..writeln();
  }
  _escribirBloques(texto, '❌ La app se cerró', corrida.cierres);
  _escribirBloques(texto, '❌ La app dejó de responder', corrida.congelamientos);

  if (conFallas) {
    final errores = const LineSplitter()
        .convert(logcat)
        .where(
          (r) => RegExp('E/AndroidRuntime|E/flutter|FATAL EXCEPTION').hasMatch(r),
        )
        .take(_maximoPorBloque)
        .toList();
    if (errores.isNotEmpty) {
      texto
        ..writeln('#### Errores en logcat')
        ..writeln()
        ..writeln(bloque(errores.join('\n')));
    }
  }

  if (corrida.ultimos.isNotEmpty) {
    texto.write(
      plegable('Últimos renglones de monkey.txt', bloque(corrida.ultimos)),
    );
  }
  return texto.toString();
}

/// Una línea para la tabla de evidencias del pipeline.
String lineaMonkey(
  CorridaMonkey corrida, {
  String logcat = '',
  Apertura? recuperacion,
}) {
  final fallas = fallasDeLaCorrida(corrida, logcat);
  final icono = fallas.cierres > 0 || fallas.congelamientos > 0
      ? '❌'
      : corrida.termino
          ? '✅'
          : '⚠️';
  final linea = '$icono ${_numero(corrida.eventosLanzados)} eventos de '
      'monkey · ${miles(fallas.cierres)} cierres · '
      '${miles(fallas.congelamientos)} congelamientos';
  final reapertura = recuperacion?.totalMs;
  if (recuperacion == null) return linea;
  if (!recuperacion.abrio || reapertura == null) {
    return '$linea · ❌ no volvió a abrir';
  }
  return '$linea · reabrió en ${milisegundos(reapertura.toDouble())}';
}

/// «✅ Recuperación: la app volvió a abrir en frío en 1,234.00 ms · GET
/// /api/health: 200».
String _lineaRecuperacion(Apertura recuperacion, int? salud) {
  final reapertura = recuperacion.totalMs;
  final abrio = recuperacion.abrio && reapertura != null;
  final saludBien = salud == 200;
  final texto = StringBuffer(abrio && saludBien ? '✅' : '❌')
    ..write(
      abrio
          ? ' Recuperación: la app volvió a abrir en frío en '
              '${milisegundos(reapertura.toDouble())}'
          : ' Recuperación: la app no volvió a abrir '
              '(am start -W: ${recuperacion.estado})',
    )
    ..write(' · GET /api/health: ${salud ?? 'sin respuesta'}.');
  return texto.toString();
}

void _escribirBloques(StringBuffer texto, String titulo, List<String> bloques) {
  if (bloques.isEmpty) return;
  texto
    ..writeln('#### $titulo (${miles(bloques.length)})')
    ..writeln();
  for (final contenido in bloques) {
    texto.writeln(bloque(contenido));
  }
}

int? _entero(String? texto) => texto == null ? null : int.tryParse(texto);

String _numero(int? valor) => valor == null ? '—' : miles(valor);
