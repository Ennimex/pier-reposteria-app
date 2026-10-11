// lib/domain/models/reembolso.dart
//
// Una solicitud de reembolso del propio cliente («Reembolsos»). Fuente: GET
// /reembolsos/mis-reembolsos -> reembolsos[{id, pedido_id, pedido_numero,
// monto, motivo, descripcion, estado, respuesta_admin, created_at}].

/// Estado de la solicitud en el backend.
enum EstadoReembolso { pendiente, enRevision, aprobado, procesado, rechazado }

class Reembolso {
  const Reembolso({
    required this.id,
    required this.pedidoNumero,
    required this.estado,
    required this.monto,
    this.motivo,
    this.respuestaAdmin,
    this.creadoEn,
  });

  /// Tolera números como texto y fechas inválidas; un estado desconocido se
  /// toma como pendiente. Sin número de pedido usa su id.
  factory Reembolso.fromJson(Map<String, dynamic> j) => Reembolso(
        id: j['id']?.toString() ?? '',
        pedidoNumero:
            (j['pedido_numero'] ?? j['pedido_id'] ?? '').toString(),
        estado: switch (j['estado']?.toString()) {
          'en_revision' => EstadoReembolso.enRevision,
          'aprobado' => EstadoReembolso.aprobado,
          'procesado' => EstadoReembolso.procesado,
          'rechazado' => EstadoReembolso.rechazado,
          _ => EstadoReembolso.pendiente,
        },
        monto: double.tryParse(j['monto']?.toString() ?? '') ?? 0,
        motivo: j['motivo']?.toString(),
        respuestaAdmin: _textoOpcional(j['respuesta_admin']),
        creadoEn:
            DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
      );

  final String id;
  final String pedidoNumero;
  final EstadoReembolso estado;
  final double monto;

  /// Código del motivo (ver [motivos]).
  final String? motivo;

  /// El motivo para mostrar; un código desconocido se muestra tal cual.
  String? get motivoTexto => motivo == null ? null : motivos[motivo] ?? motivo;

  /// null si Pier no ha respondido.
  final String? respuestaAdmin;
  final DateTime? creadoEn;

  /// Motivos válidos: el ENUM `motivo_reembolso` de la base (código → texto,
  /// los mismos que la web y el panel del personal). El backend rechaza
  /// cualquier otro valor (#118).
  static const Map<String, String> motivos = {
    'producto_danado': 'Producto dañado',
    'no_satisfecho': 'No satisfecho con el producto',
    'pedido_incorrecto': 'Pedido incorrecto',
    'tardanza': 'Tardanza en preparación',
    'cantidad_incorrecta': 'Cantidad incorrecta',
    'otro': 'Otro motivo',
  };

  static String? _textoOpcional(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}
