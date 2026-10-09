// lib/domain/models/queja.dart
//
// Una queja, sugerencia o comentario del propio cliente («Mis Quejas»).
// Fuente: GET /quejas/mis-quejas -> quejas[{id, ticket, pedido_id, tipo,
// categoria, asunto, descripcion, estado, respuesta, created_at}]. El backend
// no manda el número del pedido, solo su id.

/// Qué registra el cliente. [name] es el valor que guarda el backend.
enum TipoQueja {
  queja('Queja'),
  sugerencia('Sugerencia'),
  comentario('Comentario');

  const TipoQueja(this.etiqueta);

  final String etiqueta;
}

/// De qué trata. [name] es el valor que guarda el backend.
enum CategoriaQueja {
  producto('Producto'),
  servicio('Servicio'),
  plataforma('Plataforma'),
  otro('Otro');

  const CategoriaQueja(this.etiqueta);

  final String etiqueta;
}

/// Estado de atención (backend: pendiente, en_proceso, resuelto).
enum EstadoQueja {
  pendiente('Pendiente'),
  enProceso('En proceso'),
  resuelto('Resuelto');

  const EstadoQueja(this.etiqueta);

  final String etiqueta;
}

class Queja {
  const Queja({
    required this.id,
    required this.ticket,
    required this.asunto,
    required this.descripcion,
    required this.estado,
    required this.tipo,
    required this.categoria,
    this.respuesta,
    this.pedidoId,
    this.creadaEn,
  });

  /// Tolera faltantes y fechas inválidas; un estado desconocido se toma como
  /// pendiente. Tipo y categoría se guardan crudos: un valor que la app no
  /// conozca se muestra tal cual.
  factory Queja.fromJson(Map<String, dynamic> j) => Queja(
        id: j['id']?.toString() ?? '',
        ticket: j['ticket']?.toString() ?? '',
        asunto: j['asunto']?.toString() ?? '',
        descripcion: j['descripcion']?.toString() ?? '',
        estado: switch (j['estado']?.toString()) {
          'en_proceso' => EstadoQueja.enProceso,
          'resuelto' => EstadoQueja.resuelto,
          _ => EstadoQueja.pendiente,
        },
        tipo: j['tipo']?.toString() ?? '',
        categoria: j['categoria']?.toString() ?? '',
        respuesta: _textoOpcional(j['respuesta']),
        pedidoId: _textoOpcional(j['pedido_id']),
        creadaEn:
            DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
      );

  final String id;
  final String ticket;
  final String asunto;
  final String descripcion;
  final EstadoQueja estado;
  final String tipo;
  final String categoria;

  /// null si el equipo no ha respondido.
  final String? respuesta;

  /// null si no tiene pedido asociado.
  final String? pedidoId;
  final DateTime? creadaEn;

  /// Etiqueta del tipo («Sugerencia») o el valor crudo si no se conoce.
  String get tipoTexto =>
      TipoQueja.values.asNameMap()[tipo]?.etiqueta ?? tipo;

  /// Etiqueta de la categoría («Producto») o el valor crudo si no se conoce.
  String get categoriaTexto =>
      CategoriaQueja.values.asNameMap()[categoria]?.etiqueta ?? categoria;

  static String? _textoOpcional(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}
