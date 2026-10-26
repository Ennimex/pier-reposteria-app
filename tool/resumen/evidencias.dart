// tool/resumen/evidencias.dart — la tabla final del pipeline (pipeline.yml,
// job «Evidencias y decisión»): una fila por etapa con el resultado que dio
// GitHub Actions y sus métricas clave, sacadas de los artefactos que dejó
// cada etapa, y la decisión: el pipeline pasa solo si pasaron todas. La
// decisión nombra la rama real: la de destino en un Pull Request (develop o
// main) o la rama donde corrió en un push o a mano.
import 'markdown.dart';
import 'pruebas.dart';

/// Dónde corrió el pipeline, para que la decisión diga a qué rama aplica.
class DestinoDelCambio {
  /// Un Pull Request que quiere unirse a [rama].
  const DestinoDelCambio.pullRequest(this.rama) : esPullRequest = true;

  /// Un push a [rama] o una ejecución manual sobre ella.
  const DestinoDelCambio.rama(this.rama) : esPullRequest = false;

  final String rama;
  final bool esPullRequest;
}

/// El destino según las variables de GitHub Actions: en un Pull Request,
/// GITHUB_BASE_REF trae la rama de destino; en un push o a mano viene vacía
/// y la rama es GITHUB_REF_NAME. Null si no hay ninguna (fuera de Actions).
DestinoDelCambio? destinoDelCambio(Map<String, String> entorno) {
  final ramaDeDestino = entorno['GITHUB_BASE_REF'] ?? '';
  if (ramaDeDestino.isNotEmpty) {
    return DestinoDelCambio.pullRequest(ramaDeDestino);
  }
  final ramaDondeCorrio = entorno['GITHUB_REF_NAME'] ?? '';
  return ramaDondeCorrio.isEmpty
      ? null
      : DestinoDelCambio.rama(ramaDondeCorrio);
}

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
/// tuvieron pruebas fallidas se listan debajo de la tabla. [destino] es la
/// rama que nombra la decisión; sin él, la decisión no nombra ninguna.
String resumenEvidencias(
  List<EtapaDelPipeline> etapas, {
  String version = '',
  List<Corrida> corridas = const [],
  DestinoDelCambio? destino,
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
    ..writeln(_decision(etapas, destino))
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

String _decision(List<EtapaDelPipeline> etapas, DestinoDelCambio? destino) {
  final pendientes = [
    for (final etapa in etapas)
      if (!etapa.paso) etapa.nombre,
  ];
  final rama = destino?.rama;
  final esPullRequest = destino?.esPullRequest ?? false;

  if (pendientes.isEmpty) {
    final pasaron = '**Decisión:** ✅ pasaron las ${etapas.length} etapas';
    if (rama == null) return '$pasaron.';
    return esPullRequest
        ? '$pasaron; el Pull Request puede unirse a $rama.'
        : '$pasaron en $rama.';
  }
  final noPasaron =
      '**Decisión:** ❌ no pasaron: ${pendientes.join(', ')}. El pipeline falla';
  if (rama == null) return '$noPasaron.';
  return esPullRequest
      ? '$noPasaron y $rama no recibe el cambio.'
      : '$noPasaron en $rama.';
}
