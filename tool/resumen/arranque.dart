// tool/resumen/arranque.dart — lee la salida de `adb shell am start -W` que
// guardan tool/arranque_en_frio.sh y esfuerzo.yml (una apertura de la app tras
// otra) y arma el resumen del arranque en frío: el tiempo de cada apertura y
// la mediana, que es la que se compara con la línea base
// (tool/linea_base_rendimiento.json, escenario app_arranque_emulador).
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

/// Tabla con cada apertura, la mediana y, con [base], la comparación con la
/// línea base.
String resumenArranque(List<Apertura> aperturas, {LineaBase? base}) {
  const titulo = '### 🚀 Arranque en frío en el emulador\n\n';
  final mediana = medianaDeArranque(aperturas);
  if (mediana == null) {
    return '$titulo> ⚠️ Ninguna apertura reportó su tiempo (TotalTime de '
        'am start -W). Revisa el log del paso.\n';
  }
  final texto = StringBuffer(titulo)
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
  if (base != null) {
    texto
      ..writeln(comparacionConLineaBase('mediana', mediana, base))
      ..writeln();
  }
  return texto.toString();
}

/// Una línea para la tabla de evidencias del pipeline.
String lineaArranque(List<Apertura> aperturas) {
  final mediana = medianaDeArranque(aperturas);
  if (mediana == null) return 'Arranque en frío: sin tiempos';
  return 'Arranque en frío: mediana ${milisegundos(mediana)} '
      '(${_aperturas(aperturas.length)})';
}

String _aperturas(int cuantas) =>
    cuantas == 1 ? '1 apertura' : '${miles(cuantas)} aperturas';
