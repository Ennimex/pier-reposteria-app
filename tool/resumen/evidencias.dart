// tool/resumen/evidencias.dart — la tabla final del pipeline (pipeline.yml,
// job «Evidencias y decisión»): una fila por etapa con el resultado que dio
// GitHub Actions y sus métricas clave, sacadas de los artefactos que dejó
// cada etapa, y la decisión: el pipeline pasa solo si pasaron todas.
import 'markdown.dart';
import 'pruebas.dart';

class EtapaDelPipeline {
  const EtapaDelPipeline({
    required this.nombre,
    required this.resultado,
    this.metricas = const [],
  });

  final String nombre;

  /// `needs.<job>.result`: success, failure, cancelled o skipped.
  final String resultado;

  /// Las métricas clave de la etapa, una por artefacto que dejó.
  final List<String> metricas;

  bool get paso => resultado == 'success';
}

/// [corridas] son los reportes de pruebas de todas las etapas: las que
/// tuvieron pruebas fallidas se listan debajo de la tabla.
String resumenEvidencias(
  List<EtapaDelPipeline> etapas, {
  String version = '',
  List<Corrida> corridas = const [],
}) {
  final texto = StringBuffer()
    ..writeln('### 🧾 Evidencias del pipeline')
    ..writeln();
  if (version.isNotEmpty) {
    texto
      ..writeln(version)
      ..writeln();
  }
  texto
    ..writeln('| Etapa | Resultado | Métricas clave |')
    ..writeln('|---|---|---|');
  for (final etapa in etapas) {
    final metricas =
        etapa.metricas.isEmpty ? '—' : etapa.metricas.join(' · ');
    texto.writeln(
      '| ${etapa.nombre} | ${_resultado(etapa.resultado)} '
      '| ${celda(metricas)} |',
    );
  }
  texto
    ..writeln()
    ..writeln(_decision(etapas))
    ..writeln();
  for (final corrida in corridas) {
    texto.write(seccionFallas(corrida));
  }
  return texto.toString();
}

String _resultado(String resultado) => switch (resultado) {
      'success' => '✅ Pasó',
      'failure' => '❌ Falló',
      'skipped' => '⏭️ No corrió: falló una etapa anterior',
      'cancelled' => '⏹️ Se canceló',
      _ => '— Sin resultado',
    };

String _decision(List<EtapaDelPipeline> etapas) {
  final pendientes = [
    for (final etapa in etapas)
      if (!etapa.paso) etapa.nombre,
  ];
  if (pendientes.isEmpty) {
    return '**Decisión:** ✅ pasaron las ${etapas.length} etapas; el Pull '
        'Request puede unirse a main.';
  }
  return '**Decisión:** ❌ no pasaron: ${pendientes.join(', ')}. El pipeline '
      'falla y main no recibe el cambio.';
}
