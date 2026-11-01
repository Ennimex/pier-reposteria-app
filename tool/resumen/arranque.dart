// tool/resumen/arranque.dart — lee la salida de `adb shell am start -W` que
// guardan tool/arranque_en_frio.sh, tool/arranque_alternado.sh y esfuerzo.yml
// (una apertura de la app tras otra) y arma el resumen del arranque en frío:
// el tiempo de cada apertura y la mediana. Con las aperturas de develop
// medidas en el mismo trabajo (tool/arranque_alternado.sh), la mediana se
// compara con la de develop; sin ellas, con la línea base fija
// (tool/linea_base_rendimiento.json, escenario app_arranque_emulador).
import 'dart:math';

import 'linea_base.dart';
import 'markdown.dart';

class Apertura {
  const Apertura({required this.estado, required this.tipo, this.totalMs});

  /// «ok» si la ventana de la app apareció; «timeout» si no apareció a
  /// tiempo.
  final String estado;

  /// LaunchState: COLD si Android arrancó la app desde cero.
  final String tipo;

  /// TotalTime: desde que se pidió abrir la app hasta que dibujó su primer
  /// cuadro, en ms. Null si am start -W no lo reportó.
  final int? totalMs;

  bool get abrio => estado == 'ok';
}

/// Cada apertura empieza con el renglón «Starting: Intent { … }» de am start.
List<Apertura> leerAperturas(String salida) {
  String? campo(String bloque, String nombre) =>
      RegExp('^$nombre: (\\S+)', multiLine: true).firstMatch(bloque)?.group(1);

  final bloques = salida
      .replaceAll('\r', '')
      .split(RegExp('^Starting: ', multiLine: true))
      .skip(1);
  return [
    for (final bloque in bloques)
      Apertura(
        estado: campo(bloque, 'Status') ?? '—',
        tipo: campo(bloque, 'LaunchState') ?? '—',
        totalMs: int.tryParse(campo(bloque, 'TotalTime') ?? ''),
      ),
  ];
}

/// La mediana de los TotalTime de las aperturas, o null si ninguna lo trajo.
double? medianaDeArranque(List<Apertura> aperturas) {
  final tiempos = [
    for (final apertura in aperturas)
      if (apertura.totalMs != null) apertura.totalMs!,
  ]..sort();
  if (tiempos.isEmpty) return null;
  final mitad = tiempos.length ~/ 2;
  if (tiempos.length.isOdd) return tiempos[mitad].toDouble();
  return (tiempos[mitad - 1] + tiempos[mitad]) / 2;
}

const _titulo = '### 🚀 Arranque en frío en el emulador\n\n';

/// Tabla con cada apertura, la mediana y, con [base], la comparación con la
/// línea base. [descartadas]: cuántas aperturas no se contaron (la primera
/// después de instalar, tool/arranque_alternado.sh).
String resumenArranque(
  List<Apertura> aperturas, {
  LineaBase? base,
  int descartadas = 0,
}) {
  final mediana = medianaDeArranque(aperturas);
  if (mediana == null) {
    return '$_titulo> ⚠️ Ninguna apertura reportó su tiempo (TotalTime de '
        'am start -W). Revisa el log del paso.\n';
  }
  final texto = StringBuffer(_titulo)
    ..writeln('| Apertura | Ventana | Arranque | Hasta el primer cuadro |')
    ..writeln('|--:|:-:|:-:|--:|');
  for (final (indice, apertura) in aperturas.indexed) {
    final tiempo = apertura.totalMs;
    texto.writeln(
      '| ${indice + 1} | ${apertura.abrio ? '✅' : '❌'} ${apertura.estado} '
      '| ${apertura.tipo} '
      '| ${tiempo == null ? '—' : milisegundos(tiempo.toDouble())} |',
    );
  }
  texto
    ..writeln()
    ..writeln(
      '**Mediana: ${milisegundos(mediana)}** '
      '(${_aperturas(aperturas.length)}).',
    )
    ..writeln();
  _agregarDescartadas(texto, descartadas);
  if (base != null) {
    texto
      ..writeln(comparacionConLineaBase('mediana', mediana, base))
      ..writeln();
  }
  return texto.toString();
}

/// Este cambio contra develop, medidos en el mismo emulador por
/// tool/arranque_alternado.sh: una fila por ronda, las dos medianas y la
/// diferencia. Con [base], el veredicto con su regla contra la mediana de
/// develop (el que decide) y la línea base fija, que solo informa. [origen]:
/// de qué corrida y commit salió el APK de develop. Si alguna de las dos no
/// trae tiempos, queda el resumen sin develop.
String resumenArranqueContraDevelop(
  List<Apertura> cambio,
  List<Apertura> develop, {
  LineaBase? base,
  int descartadas = 0,
  String origen = '',
}) {
  final medianaCambio = medianaDeArranque(cambio);
  final medianaDevelop = medianaDeArranque(develop);
  if (medianaCambio == null || medianaDevelop == null) {
    return resumenArranque(cambio, base: base, descartadas: descartadas);
  }
  final texto = StringBuffer(_titulo)
    ..writeln(
      'Este cambio y develop se turnaron en el mismo emulador, cada uno '
      'instalado desde cero: en las rondas impares abrió primero develop y en '
      'las pares este cambio.',
    )
    ..writeln()
    ..writeln('| Ronda | Este cambio | develop |')
    ..writeln('|--:|--:|--:|');
  for (var ronda = 0; ronda < max(cambio.length, develop.length); ronda++) {
    texto.writeln(
      '| ${ronda + 1} | ${_celda(cambio.elementAtOrNull(ronda))} '
      '| ${_celda(develop.elementAtOrNull(ronda))} |',
    );
  }
  texto
    ..writeln()
    ..writeln(
      '**Mediana de este cambio: ${milisegundos(medianaCambio)} '
      '(${_aperturas(cambio.length)}) · de develop: '
      '${milisegundos(medianaDevelop)} (${_aperturas(develop.length)}) · '
      'diferencia: ${_diferencia(medianaCambio, medianaDevelop)}.**',
    )
    ..writeln();
  _agregarDescartadas(texto, descartadas);
  if (base != null) {
    texto
      ..writeln(
        comparacionConLineaBase(
          'mediana',
          medianaCambio,
          base.conValor(medianaDevelop),
          referencia: 'la mediana de develop,',
        ),
      )
      ..writeln()
      ..writeln(
        'ℹ️ Solo como referencia, porque decide develop: '
        '${comparacionConLineaBase('mediana', medianaCambio, base)}',
      )
      ..writeln();
  }
  if (origen.isNotEmpty) {
    texto
      ..writeln(origen)
      ..writeln();
  }
  return texto.toString();
}

/// Una línea para la tabla de evidencias del pipeline; con las aperturas de
/// [develop], también su mediana y la diferencia.
String lineaArranque(
  List<Apertura> aperturas, {
  List<Apertura> develop = const [],
}) {
  final mediana = medianaDeArranque(aperturas);
  if (mediana == null) return 'Arranque en frío: sin tiempos';
  final linea = 'Arranque en frío: mediana ${milisegundos(mediana)} '
      '(${_aperturas(aperturas.length)})';
  final medianaDevelop = medianaDeArranque(develop);
  if (medianaDevelop == null) return linea;
  return '$linea · develop ${milisegundos(medianaDevelop)} '
      '(${_diferencia(mediana, medianaDevelop)})';
}

String _aperturas(int cuantas) =>
    cuantas == 1 ? '1 apertura' : '${miles(cuantas)} aperturas';

/// La primera apertura después de cada instalación no cuenta.
void _agregarDescartadas(StringBuffer texto, int descartadas) {
  if (descartadas <= 0) return;
  texto
    ..writeln(
      'Aperturas de calentamiento sin contar: ${miles(descartadas)} (la '
      'primera después de cada instalación: Android todavía prepara la app '
      'y tarda más).',
    )
    ..writeln();
}

/// Una apertura en la tabla de rondas: su tiempo o, sin él, su estado.
String _celda(Apertura? apertura) {
  if (apertura == null) return '—';
  final tiempo = apertura.totalMs;
  return '${apertura.abrio ? '✅' : '❌'} '
      '${tiempo == null ? apertura.estado : milisegundos(tiempo.toDouble())}';
}

/// Cuánto más tardó [medida] que [referencia]: 4,800 contra 4,000 →
/// «+20.0 %»; con signo menos si tardó menos.
String _diferencia(double medida, double referencia) {
  final cambio = (medida - referencia) / referencia * 100;
  return '${cambio > 0 ? '+' : ''}${porcentaje(cambio)}';
}
