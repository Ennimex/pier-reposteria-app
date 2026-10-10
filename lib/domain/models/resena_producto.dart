// lib/domain/models/resena_producto.dart
//
// Una reseña aprobada de un producto («Opiniones»). Fuente: GET
// /resenas/producto/:id (público) -> resenas[{id, rating, titulo,
// comentario, util_count, verificada, created_at, autor_nombre,
// autor_apellido, respuesta_negocio}]. El detalle del producto (GET
// /productos/:id) las manda con `likes_count` y `user_has_liked`.
class ResenaProducto {
  const ResenaProducto({
    required this.id,
    required this.rating,
    required this.titulo,
    required this.comentario,
    required this.verificada,
    required this.utilCount,
    required this.autorNombre,
    required this.autorApellido,
    this.creadaEn,
    this.marcadaUtil = false,
  });

  /// Tolera números como texto, faltantes y fechas inválidas.
  factory ResenaProducto.fromJson(Map<String, dynamic> j) => ResenaProducto(
        id: j['id']?.toString() ?? '',
        rating: double.tryParse(j['rating']?.toString() ?? '') ?? 0,
        titulo: j['titulo']?.toString() ?? '',
        comentario: j['comentario']?.toString() ?? '',
        verificada: j['verificada'] == true,
        utilCount: int.tryParse(
                (j['util_count'] ?? j['likes_count'])?.toString() ?? '') ??
            0,
        autorNombre: j['autor_nombre']?.toString() ?? '',
        autorApellido: j['autor_apellido']?.toString() ?? '',
        creadaEn:
            DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
        marcadaUtil: j['user_has_liked'] == true ||
            j['user_has_liked'] == 1 ||
            j['has_liked'] == 1,
      );

  final String id;
  final double rating;
  final String titulo;
  final String comentario;
  final bool verificada;

  /// Cuántos la marcaron «útil».
  final int utilCount;
  final String autorNombre;
  final String autorApellido;
  final DateTime? creadaEn;

  /// ¿El cliente con sesión ya la marcó útil? (solo lo manda el detalle).
  final bool marcadaUtil;

  /// Estrellas redondeadas (para filtrar y la distribución).
  int get estrellas => rating.round();

  /// «Ana G.»: nombre e inicial del apellido.
  String get autor => '$autorNombre '
          '${autorApellido.isNotEmpty ? '${autorApellido[0]}.' : ''}'
      .trim();

  ResenaProducto copyWith({int? utilCount, bool? marcadaUtil}) =>
      ResenaProducto(
        id: id,
        rating: rating,
        titulo: titulo,
        comentario: comentario,
        verificada: verificada,
        utilCount: utilCount ?? this.utilCount,
        autorNombre: autorNombre,
        autorApellido: autorApellido,
        creadaEn: creadaEn,
        marcadaUtil: marcadaUtil ?? this.marcadaUtil,
      );
}
