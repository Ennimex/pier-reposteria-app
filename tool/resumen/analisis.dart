// tool/resumen/analisis.dart — lee la salida de flutter analyze, la compara
// con la línea base de tool/check_analysis.sh y arma su resumen (#157).
import 'dart:convert';

import 'markdown.dart';

enum Gravedad { error, advertencia, aviso }

class Hallazgo {
  const Hallazgo({
    required this.gravedad,
    required this.mensaje,
    required this.archivo,
    required this.linea,
    required this.regla,
  });

  final Gravedad gravedad;
  final String mensaje;
  final String archivo;
  final int linea;
  final String regla;

  String get ubicacion => '$archivo:$linea';
}

class LineaBase {
  const LineaBase({
    required this.errores,
    required this.advertencias,
    required this.avisos,
  });

  final int errores;
  final int advertencias;
  final int avisos;

  String get texto => '$errores/$advertencias/$avisos';
}

// «   info • mensaje • lib/x.dart:45:7 • regla» en Linux (CI); en Windows los
// campos se separan con « - ».
final _renglon = RegExp(
  r'^\s*(error|warning|info) [•-] (.*) [•-] (\S+):(\d+):\d+ [•-] ([a-z0-9_]+)\s*$',
);

List<Hallazgo> leerAnalisis(String salida) => [
      for (final renglon in const LineSplitter().convert(salida))
        if (_renglon.firstMatch(renglon) case final datos?)
          Hallazgo(
            gravedad: switch (datos.group(1)) {
              'error' => Gravedad.error,
              'warning' => Gravedad.advertencia,
              _ => Gravedad.aviso,
            },
            mensaje: datos.group(2)!.trim(),
            archivo: datos.group(3)!,
            linea: int.parse(datos.group(4)!),
            regla: datos.group(5)!,
          ),
    ];

/// La línea base vive en tool/check_analysis.sh; se lee de ahí para no
/// repetirla en los workflows.
LineaBase? leerLineaBase(String script) {
  final valores = {
    for (final dato in RegExp(
      r'^baseline_(errors|warnings|infos)=(\d+)',
      multiLine: true,
    ).allMatches(script))
      dato.group(1)!: int.parse(dato.group(2)!),
  };
  final errores = valores['errors'];
  final advertencias = valores['warnings'];
  final avisos = valores['infos'];
  if (errores == null || advertencias == null || avisos == null) return null;
  return LineaBase(
    errores: errores,
    advertencias: advertencias,
    avisos: avisos,
  );
}

/// Tabla contra la línea base; errores y advertencias a la vista; avisos
/// plegados por regla y en lista con archivo y línea.
String resumenAnalisis(List<Hallazgo> hallazgos, LineaBase base) {
  final conteo = _Conteo(hallazgos);
  final texto = StringBuffer()
    ..writeln('### 🔍 Análisis estático (flutter analyze)')
    ..writeln()
    ..writeln('| | Encontrados | Línea base | |')
    ..writeln('|---|--:|--:|:-:|')
    ..writeln(_fila('Errores', conteo.errores, base.errores))
    ..writeln(_fila('Advertencias', conteo.advertencias, base.advertencias))
    ..writeln(_fila('Avisos', conteo.avisos, base.avisos))
    ..writeln();

  if (conteo.rebasa(base)) {
    texto
      ..writeln(
        '> ❌ El análisis rebasa la línea base: corrige los hallazgos nuevos '
        'antes de mezclar.',
      )
      ..writeln();
  } else if (conteo.texto != base.texto) {
    texto
      ..writeln(
        '> ℹ️ Hay menos hallazgos que la línea base: bájala a '
        '${conteo.texto} en `tool/check_analysis.sh` para fijar la mejora.',
      )
      ..writeln();
  }

  final graves =
      hallazgos.where((h) => h.gravedad != Gravedad.aviso).toList();
  if (graves.isNotEmpty) {
    texto
      ..writeln('#### Errores y advertencias (${miles(graves.length)})')
      ..writeln()
      ..writeln('| | Archivo | Regla | Mensaje |')
      ..writeln('|:-:|---|---|---|');
    for (final hallazgo in graves) {
      final icono = hallazgo.gravedad == Gravedad.error ? '❌' : '⚠️';
      texto.writeln(
        '| $icono | `${hallazgo.ubicacion}` | `${hallazgo.regla}` '
        '| ${celda(hallazgo.mensaje)} |',
      );
    }
    texto.writeln();
  }

  final avisos = hallazgos.where((h) => h.gravedad == Gravedad.aviso).toList();
  if (avisos.isNotEmpty) {
    final porRegla = <String, List<Hallazgo>>{};
    for (final aviso in avisos) {
      porRegla.putIfAbsent(aviso.regla, () => []).add(aviso);
    }
    final reglas = porRegla.keys.toList()
      ..sort((a, b) {
        final orden = porRegla[b]!.length.compareTo(porRegla[a]!.length);
        return orden != 0 ? orden : a.compareTo(b);
      });
    final tablaReglas = StringBuffer()
      ..writeln('| Regla | Cuántos | Mensaje |')
      ..writeln('|---|--:|---|');
    for (final regla in reglas) {
      final ejemplos = porRegla[regla]!;
      tablaReglas.writeln(
        '| `$regla` | ${miles(ejemplos.length)} '
        '| ${celda(_primeraOracion(ejemplos.first.mensaje))} |',
      );
    }
    final lista = StringBuffer()
      ..writeln('| Archivo | Regla |')
      ..writeln('|---|---|');
    for (final aviso in avisos) {
      lista.writeln('| `${aviso.ubicacion}` | `${aviso.regla}` |');
    }
    final cuantos = miles(avisos.length);
    texto
      ..write(plegable('Avisos por regla ($cuantos)', tablaReglas.toString()))
      ..writeln()
      ..write(
        plegable(
          'Lista de avisos con archivo y línea ($cuantos)',
          lista.toString(),
        ),
      );
  }
  return texto.toString();
}

/// Una línea para la tabla de etapas de la regresión.
String lineaAnalisis(List<Hallazgo> hallazgos, LineaBase base) {
  final conteo = _Conteo(hallazgos);
  final icono = conteo.rebasa(base) ? '❌' : '✅';
  return '$icono ${_cuantos(conteo.errores, 'error', 'errores')} · '
      '${_cuantos(conteo.advertencias, 'advertencia', 'advertencias')} · '
      '${_cuantos(conteo.avisos, 'aviso', 'avisos')} '
      '(línea base ${base.texto})';
}

class _Conteo {
  _Conteo(List<Hallazgo> hallazgos)
      : errores = _contar(hallazgos, Gravedad.error),
        advertencias = _contar(hallazgos, Gravedad.advertencia),
        avisos = _contar(hallazgos, Gravedad.aviso);

  final int errores;
  final int advertencias;
  final int avisos;

  String get texto => '$errores/$advertencias/$avisos';

  bool rebasa(LineaBase base) =>
      errores > base.errores ||
      advertencias > base.advertencias ||
      avisos > base.avisos;

  static int _contar(List<Hallazgo> hallazgos, Gravedad gravedad) =>
      hallazgos.where((h) => h.gravedad == gravedad).length;
}

String _fila(String nombre, int encontrados, int base) =>
    '| $nombre | ${miles(encontrados)} | ${miles(base)} '
    '| ${encontrados > base ? '❌' : '✅'} |';

String _cuantos(int numero, String singular, String plural) =>
    '${miles(numero)} ${numero == 1 ? singular : plural}';

/// «Constructor declarations should be … declarations. Try moving…» → solo
/// la primera oración, que dice qué pide la regla.
String _primeraOracion(String mensaje) {
  final fin = mensaje.indexOf('. ');
  return fin == -1 ? mensaje : mensaje.substring(0, fin + 1);
}
