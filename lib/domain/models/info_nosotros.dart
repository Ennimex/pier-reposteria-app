// lib/domain/models/info_nosotros.dart
//
// Textos de «Nosotros» que Dirección captura en el panel. Fuente:
// GET /api/configuracion/nosotros -> config{historia{titulo, contenido,
// fundacion}, mision, vision, valores[], estadisticas[{numero, label}]}
// (misma fuente que Nosotros.tsx), además de timeline[{year, title,
// description, image}] y equipo[{name, role, description, emoji, photo}]
// (contenidoSitio.js: de 1 a 10 etapas y de 0 a 12 personas; image y photo
// son opcionales). Cada campo es null/vacío si no se capturó; la app conserva
// entonces su texto por defecto.
import 'package:pier_reposteria/domain/models/imagen_sitio.dart';
import 'package:pier_reposteria/utils/config_format.dart';

/// Una etapa de «Nuestro recorrido».
class EtapaRecorrido {
  const EtapaRecorrido({
    required this.anio,
    required this.titulo,
    this.descripcion,
    this.imagen,
  });

  final String anio;
  final String titulo;
  final String? descripcion;

  /// Asset de la app o URL https (ver imagen_sitio.dart); null sin foto.
  final String? imagen;
}

/// Una persona de «Conoce al equipo».
class IntegranteEquipo {
  const IntegranteEquipo({
    required this.nombre,
    required this.puesto,
    this.descripcion,
    this.emoji,
    this.foto,
  });

  final String nombre;
  final String puesto;
  final String? descripcion;
  final String? emoji;

  /// Asset de la app o URL https (ver imagen_sitio.dart); null sin foto.
  final String? foto;
}

class InfoNosotros {
  const InfoNosotros({
    this.historiaTitulo,
    this.historia,
    this.anioFundacion,
    this.mision,
    this.vision,
    this.valores = const [],
    this.estadisticas = const [],
    this.recorrido = const [],
    this.equipo = const [],
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

    // Una etapa sin título o una persona sin nombre no tiene qué mostrar.
    final recorrido = <EtapaRecorrido>[];
    final timelineRaw = parseConfigValor(cfg['timeline']);
    if (timelineRaw is List) {
      for (final x in timelineRaw) {
        if (x is! Map) continue;
        final t = configTexto(x['title']);
        if (t == null) continue;
        recorrido.add(EtapaRecorrido(
          anio: configTexto(x['year']) ?? '',
          titulo: t,
          descripcion: configTexto(x['description']),
          imagen: imagenDelSitio(configTexto(x['image'])),
        ));
      }
    }

    final equipo = <IntegranteEquipo>[];
    final equipoRaw = parseConfigValor(cfg['equipo']);
    if (equipoRaw is List) {
      for (final x in equipoRaw) {
        if (x is! Map) continue;
        final n = configTexto(x['name']);
        if (n == null) continue;
        equipo.add(IntegranteEquipo(
          nombre: n,
          puesto: configTexto(x['role']) ?? '',
          descripcion: configTexto(x['description']),
          emoji: configTexto(x['emoji']),
          foto: imagenDelSitio(configTexto(x['photo'])),
        ));
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
      recorrido: recorrido,
      equipo: equipo,
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

  /// Etapas capturadas, en orden; vacía si no hay.
  final List<EtapaRecorrido> recorrido;

  /// Personas capturadas, en orden; vacía si no hay.
  final List<IntegranteEquipo> equipo;
}
