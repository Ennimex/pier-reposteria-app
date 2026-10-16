// tool/resumen/regresion.dart — tabla de etapas de la regresión (#157): una
// fila por etapa, sin repetir el detalle que ya dan los demás pipelines.
import 'markdown.dart';
import 'pruebas.dart';

class Etapa {
  const Etapa({required this.nombre, required this.resultado, this.linea});

  final String nombre;

  /// Resultado del paso en GitHub Actions (`steps.<id>.outcome`): success,
  /// failure, skipped o cancelled.
  final String resultado;

  /// Resumen en una línea de lo que dejó el paso, si dejó algo.
  final String? linea;
}

/// [corridas] son los reportes de pruebas de la regresión: si alguna prueba
/// falló, se lista debajo de la tabla.
String resumenRegresion(
  List<Etapa> etapas, {
  String version = '',
  List<Corrida> corridas = const [],
}) {
  final texto = StringBuffer()
    ..writeln('### 🔁 Regresión completa')
    ..writeln();
  if (version.isNotEmpty) {
    texto
      ..writeln(version)
      ..writeln();
  }
  texto
    ..writeln('| Etapa | Resultado |')
    ..writeln('|---|---|');
  for (final etapa in etapas) {
    texto.writeln('| ${etapa.nombre} | ${celda(_resultado(etapa))} |');
  }
  texto.writeln();
  for (final corrida in corridas) {
    texto.write(seccionFallas(corrida));
  }
  return texto.toString();
}

/// El resultado del paso manda: una línea con ✅ no tapa un paso que falló.
String _resultado(Etapa etapa) {
  final linea = etapa.linea;
  return switch (etapa.resultado) {
    'success' => linea ?? '✅ Correcta',
    'failure' when linea != null && linea.startsWith('❌') => linea,
    'failure' => '❌ Falló: revisa el log del paso',
    'skipped' => '⏭️ No corrió: falló una etapa anterior',
    'cancelled' => '⏹️ Se canceló',
    _ => '— Sin resultado',
  };
}
