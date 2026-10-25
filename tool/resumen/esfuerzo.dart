// tool/resumen/esfuerzo.dart — lee la bitácora de monkey (adb shell monkey
// -v, monkey.txt) y arma su resumen con los cierres y congelamientos (#157).
import 'dart:convert';

import 'markdown.dart';

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

/// Tabla de la corrida; si hubo cierres o congelamientos, su bloque y los
/// errores de [logcat] a la vista; la cola de monkey.txt, plegada.
String resumenMonkey(CorridaMonkey corrida, {String logcat = ''}) {
  final hayFallas =
      corrida.cierres.isNotEmpty || corrida.congelamientos.isNotEmpty;
  final veredicto = hayFallas
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
      '| ${miles(corrida.cierres.length)} '
      '| ${miles(corrida.congelamientos.length)} '
      '| ${corrida.duracion == null ? '—' : duracion(corrida.duracion!)} '
      '| ${corrida.semilla ?? '—'} |',
    )
    ..writeln();

  if (!hayFallas && !corrida.termino) {
    texto
      ..writeln(
        '> ⚠️ monkey no llegó al final: revisa el log del paso para saber '
        'por qué se detuvo.',
      )
      ..writeln();
  }
  _escribirBloques(texto, '❌ La app se cerró', corrida.cierres);
  _escribirBloques(texto, '❌ La app dejó de responder', corrida.congelamientos);

  if (hayFallas) {
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
String lineaMonkey(CorridaMonkey corrida) {
  final hayFallas =
      corrida.cierres.isNotEmpty || corrida.congelamientos.isNotEmpty;
  final icono = hayFallas
      ? '❌'
      : corrida.termino
          ? '✅'
          : '⚠️';
  return '$icono ${_numero(corrida.eventosLanzados)} eventos de monkey · '
      '${miles(corrida.cierres.length)} cierres · '
      '${miles(corrida.congelamientos.length)} congelamientos';
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
