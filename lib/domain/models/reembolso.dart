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
  final String? motivo;

  /// null si Pier no ha respondido.
  final String? respuestaAdmin;
  final DateTime? creadoEn;

  static String? _textoOpcional(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}
