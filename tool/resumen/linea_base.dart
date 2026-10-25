// tool/resumen/linea_base.dart — la línea base de rendimiento
// (tool/linea_base_rendimiento.json) y la regla con la que se compara cada
// medición: falla solo si la supera en más de su tolerancia en porcentaje y,
// además, en más de su piso absoluto (tolerancia_minima_ms). El piso evita
// fallar por el ruido de las computadoras de GitHub cuando la línea base es
// de pocos milisegundos.
import 'dart:math';

import 'markdown.dart';

/// Qué mide una línea base y en qué campo del JSON viene su valor.
enum Medida {
  /// p95 de una corrida de k6 (k6 run --summary-export), en ms.
  p95('p95_ms', 'El p95'),

  /// Mediana del arranque en frío (tool/arranque_en_frio.sh), en ms.
  medianaDeArranque('mediana_ms', 'La mediana del arranque'),

  /// Peso de un archivo (el APK), en bytes.
  peso('bytes', 'El peso');

  const Medida(this.campo, this.nombre);

  final String campo;

  /// Cómo empieza la frase del resultado: «El p95 de … es …».
  final String nombre;
}

class LineaBase {
  const LineaBase({
    required this.medida,
    required this.valor,
    required this.toleranciaPorcentaje,
    this.toleranciaMinima = 0,
    this.corrida = '',
  });

  final Medida medida;

  /// El valor de referencia, en las unidades de [medida].
  final double valor;

  /// Cuánto puede subir, en porcentaje (20 = 20 %).
  final double toleranciaPorcentaje;

  /// Cuánto puede subir como mínimo, en ms, aunque sea más que el
  /// porcentaje (0 = sin piso).
  final double toleranciaMinima;

  /// Corrida de GitHub Actions que fijó la línea base.
  final String corrida;

  /// El máximo permitido: el mayor entre la línea base más su porcentaje y
  /// la línea base más el piso. Rebasarlo es rebasar los dos.
  double get permitido => max(
        valor * (1 + toleranciaPorcentaje / 100),
        valor + toleranciaMinima,
      );

  bool rebasa(double medido) => medido > permitido;

  /// [cantidad] en las unidades de la medida: «8.56 ms» o «39.3 MB».
  String formato(double cantidad) => medida == Medida.peso
      ? tamano(cantidad.round())
      : milisegundos(cantidad);

  /// La regla en palabras: «falla solo si sube más de 20 % y más de 25 ms».
  String get regla {
    final porcentaje = '${_sinCeros(toleranciaPorcentaje)} %';
    if (toleranciaMinima <= 0) return 'falla si sube más de $porcentaje';
    return 'falla solo si sube más de $porcentaje y más de '
        '${_sinCeros(toleranciaMinima)} ms';
  }
}

/// La línea base de [clave] o null si el archivo no la trae completa: un
/// valor positivo en el campo de alguna [Medida] y tolerancia_porcentaje.
LineaBase? leerLineaBaseDeRendimiento(
  Map<String, dynamic> datos,
  String clave,
) {
  final escenario = datos[clave];
  if (escenario is! Map<String, dynamic>) return null;
  final porcentaje = escenario['tolerancia_porcentaje'];
  if (porcentaje is! num || porcentaje < 0) return null;
  final minima = escenario['tolerancia_minima_ms'];
  for (final medida in Medida.values) {
    final valor = escenario[medida.campo];
    if (valor is! num || valor <= 0) continue;
    return LineaBase(
      medida: medida,
      valor: valor.toDouble(),
      toleranciaPorcentaje: porcentaje.toDouble(),
      toleranciaMinima: minima is num && minima > 0 ? minima.toDouble() : 0,
      corrida: escenario['corrida']?.toString() ?? '',
    );
  }
  return null;
}

/// Renglón con el veredicto: «✅ p95 8.56 ms contra la línea base de 7.22 ms
/// (máximo permitido 32.22 ms: falla solo si sube más de 20 % y más de
/// 25 ms).».
String comparacionConLineaBase(
  String que,
  double medido,
  LineaBase base,
) {
  final veredicto = base.rebasa(medido) ? '❌' : '✅';
  return '$veredicto $que ${base.formato(medido)} contra la línea base de '
      '${base.formato(base.valor)} (máximo permitido '
      '${base.formato(base.permitido)}: ${base.regla}).';
}

/// 20.0 → «20»; 2.5 → «2.5».
String _sinCeros(double numero) => numero == numero.roundToDouble()
    ? numero.round().toString()
    : numero.toString();
