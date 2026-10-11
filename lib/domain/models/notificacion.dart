// lib/domain/models/notificacion.dart
//
// Un aviso del propio cliente (campana de inicio y «Notificaciones»).
// Fuente: GET /notificaciones -> notificaciones[{id, usuario_id, tipo,
// titulo, mensaje, leida, created_at}], las 50 más recientes primero. El
// tipo (pedido, pago, promocion, sistema, aviso…) se guarda crudo: uno que
// la app no conozca se muestra con la campana genérica.

class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    this.leida = false,
    this.creadaEn,
  });

  /// Tolera faltantes y fechas inválidas; sin tipo se toma como «sistema».
  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
        id: j['id']?.toString() ?? '',
        tipo: j['tipo']?.toString() ?? 'sistema',
        titulo: j['titulo']?.toString() ?? '',
        mensaje: j['mensaje']?.toString() ?? '',
        leida: j['leida'] == true,
        creadaEn:
            DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
      );

  final String id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final bool leida;

  /// null si el backend no mandó una fecha válida.
  final DateTime? creadaEn;

  /// La misma notificación, ya leída.
  Notificacion marcadaLeida() => Notificacion(
        id: id,
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        leida: true,
        creadaEn: creadaEn,
      );
}
