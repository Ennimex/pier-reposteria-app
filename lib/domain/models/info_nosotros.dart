// lib/domain/models/info_nosotros.dart
//
// Textos de «Nosotros» que Dirección captura en el panel. Fuente:
// GET /api/configuracion/nosotros -> config{historia{titulo, contenido,
// fundacion}, mision, vision, valores[], estadisticas[{numero, label}]}
// (misma fuente que Nosotros.tsx). Cada campo es null/vacío si no se capturó;
// la app conserva entonces su texto por defecto. timeline/equipo de la web no
// se muestran en la app.
import 'package:pier_pasteleria/utils/config_format.dart';

class InfoNosotros {
  const InfoNosotros({
    this.historiaTitulo,
    this.historia,
    this.anioFundacion,
    this.mision,
    this.vision,
    this.valores = const [],
    this.estadisticas = const [],
  });

  /// Lee el mapa `config` de la sección. Los valores pueden llegar como texto,
  /// JSON serializado o ya decodificados (ver utils/config_format.dart).
  factory InfoNosotros.fromConfig(Map<dynamic, dynamic> cfg) {
    final historiaRaw = parseConfigValor(cfg['historia']);
    String? titulo;
    String? contenido;
    String? fundacion;
    if (historiaRaw is Map) {
      titulo = configTexto(historiaRaw['titulo']);
      contenido = configTexto(historiaRaw['contenido']);
      fundacion = configTexto(historiaRaw['fundacion']);
    } else {
      contenido = configTexto(historiaRaw);
    }

    final valores = <String>[];
    final valoresRaw = parseConfigValor(cfg['valores']);
    if (valoresRaw is List) {
      for (final x in valoresRaw) {
        final t = x.toString().trim();
        if (t.isNotEmpty) valores.add(t);
      }
    }

    final estadisticas = <(String, String)>[];
    final statsRaw = parseConfigValor(cfg['estadisticas']);
    if (statsRaw is List) {
      for (final x in statsRaw) {
        if (x is! Map) continue;
        final n = configTexto(x['numero']);
        final l = configTexto(x['label']);
        if (n != null && l != null) estadisticas.add((n, l));
      }
    }

    return InfoNosotros(
      historiaTitulo: titulo,
      historia: contenido,
      anioFundacion: fundacion == null ? null : int.tryParse(fundacion),
      mision: configTexto(cfg['mision']),
      vision: configTexto(cfg['vision']),
      valores: valores,
      estadisticas: estadisticas,
    );
  }

  final String? historiaTitulo;
  final String? historia;
  final int? anioFundacion;
  final String? mision;
  final String? vision;
  final List<String> valores;

  /// Pares (número, etiqueta), p. ej. ('+ 5 años', 'Experiencia').
  final List<(String, String)> estadisticas;
}
