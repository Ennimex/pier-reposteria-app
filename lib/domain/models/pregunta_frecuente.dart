// lib/domain/models/pregunta_frecuente.dart
//
// Una pregunta de «Preguntas Frecuentes». Fuente: GET /api/configuracion/faq
// -> config{preguntas[{categoria, pregunta, respuesta}]} (misma fuente que
// FAQ.tsx de la web).
import 'package:pier_pasteleria/utils/config_format.dart';

class PreguntaFrecuente {
  const PreguntaFrecuente({
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
  });

  /// Lee la clave `preguntas` del mapa `config`. Descarta las que no tienen
  /// pregunta o respuesta; sin categoría van a 'General'. El valor puede
  /// llegar como JSON serializado o ya decodificado.
  static List<PreguntaFrecuente> listaDesdeConfig(Map<dynamic, dynamic> cfg) {
    final raw = parseConfigValor(cfg['preguntas']);
    if (raw is! List) return const [];
    final lista = <PreguntaFrecuente>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final q = configTexto(item['pregunta']);
      final a = configTexto(item['respuesta']);
      if (q == null || a == null) continue;
      lista.add(
        PreguntaFrecuente(
          categoria: configTexto(item['categoria']) ?? 'General',
          pregunta: q,
          respuesta: a,
        ),
      );
    }
    return lista;
  }

  final String categoria;
  final String pregunta;
  final String respuesta;
}
