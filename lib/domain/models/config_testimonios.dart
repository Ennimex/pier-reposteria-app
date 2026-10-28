// lib/domain/models/config_testimonios.dart
//
// Lo que Dirección configura para los testimonios del Inicio (#169), en
// GET /contenido: `inicio.testimonios` = { titulo, subtitulo, cantidad (1–6),
// min_estrellas (1–5) }. Como la web, si no viene se usa la clave anterior
// `inicio.testimonios_config`; si tampoco viene o no es válido, el Inicio
// muestra las reseñas destacadas como antes.
class ConfigTestimonios {
  const ConfigTestimonios({
    required this.titulo,
    required this.cantidad,
    required this.minEstrellas,
    this.subtitulo,
  });

  static const tituloPorDefecto = 'Lo que dicen nuestros clientes';

  final String titulo;
  final String? subtitulo;

  /// Cuántas reseñas mostrar como máximo.
  final int cantidad;

  /// Calificación mínima de las reseñas que se muestran.
  final int minEstrellas;

  /// La configuración que trae [contenido], o null si no hay o no es válida.
  static ConfigTestimonios? desdeContenido(Map<String, dynamic>? contenido) {
    final bloque = contenido?['inicio.testimonios'] ??
        contenido?['inicio.testimonios_config'];
    if (bloque is! Map) return null;
    final cantidad = _entero(bloque['cantidad']);
    final minEstrellas = _entero(bloque['min_estrellas']);
    if (cantidad == null || cantidad < 1 || cantidad > 6) return null;
    if (minEstrellas == null || minEstrellas < 1 || minEstrellas > 5) {
      return null;
    }
    final titulo = bloque['titulo']?.toString().trim() ?? '';
    final subtitulo = bloque['subtitulo']?.toString().trim() ?? '';
    return ConfigTestimonios(
      titulo: titulo.isEmpty ? tituloPorDefecto : titulo,
      subtitulo: subtitulo.isEmpty ? null : subtitulo,
      cantidad: cantidad,
      minEstrellas: minEstrellas,
    );
  }

  static int? _entero(Object? valor) =>
      valor is num ? valor.toInt() : int.tryParse(valor?.toString() ?? '');
}
