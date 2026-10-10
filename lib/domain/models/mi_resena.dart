// lib/domain/models/mi_resena.dart
//
// Una reseña del propio cliente («Mis Reseñas»). Fuente: GET
// /resenas/mis-resenas -> resenas[{id, rating, titulo, comentario, estado,
// producto_nombre, producto_imagen, created_at, respuesta_negocio,
// motivo_rechazo}].

/// Estado de moderación de la reseña.
enum EstadoResena { aprobada, rechazada, enRevision }

class MiResena {
  const MiResena({
    required this.id,
    required this.rating,
    required this.titulo,
    required this.comentario,
    required this.estado,
    required this.productoNombre,
    required this.productoImagen,
    this.creadaEn,
    this.respuestaNegocio,
    this.motivoRechazo,
  });

  /// Tolera números como texto y fechas inválidas; cualquier estado que no
  /// sea aprobada/rechazada se toma como en revisión.
  factory MiResena.fromJson(Map<String, dynamic> j) => MiResena(
        id: j['id']?.toString() ?? '',
        rating: double.tryParse(j['rating']?.toString() ?? '') ?? 0,
        titulo: j['titulo']?.toString() ?? '',
        comentario: j['comentario']?.toString() ?? '',
        estado: switch (j['estado']?.toString()) {
          'aprobada' => EstadoResena.aprobada,
          'rechazada' => EstadoResena.rechazada,
          _ => EstadoResena.enRevision,
        },
        productoNombre: j['producto_nombre']?.toString() ?? '',
        productoImagen: j['producto_imagen']?.toString() ?? '',
        creadaEn: DateTime.tryParse(j['created_at']?.toString() ?? '')
            ?.toLocal(),
        respuestaNegocio: _textoOpcional(j['respuesta_negocio']),
        motivoRechazo: _textoOpcional(j['motivo_rechazo']),
      );

  final String id;
  final double rating;
  final String titulo;
  final String comentario;
  final EstadoResena estado;
  final String productoNombre;
  final String productoImagen;
  final DateTime? creadaEn;

  /// null si el negocio no ha respondido.
  final String? respuestaNegocio;

  /// Solo tiene sentido si [estado] es rechazada.
  final String? motivoRechazo;

  /// Estrellas llenas (0 a 5) y valor inicial de la hoja de edición (1 a 5).
  int get estrellas => rating.round().clamp(0, 5);

  static String? _textoOpcional(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}
