// lib/domain/models/notificacion.dart
//
// Un aviso del propio cliente (campana de inicio y «Notificaciones»).
// Fuente: GET /notificaciones -> notificaciones[{id, usuario_id, tipo,
// titulo, mensaje, leida, created_at}], las 50 más recientes primero. El
// tipo (pedido, pago, promocion, sistema, aviso…) se guarda crudo: uno que
// la app no conozca se muestra con la campana genérica.
//
// Al personal de producción el backend le avisa de las comandas con el folio
// en el título («Nueva comanda #5001», «Cambió la comanda #5001», «Comanda
// #5001 cancelada»): la notificación no trae el id de la comanda (punto 20
// de la nota al backend), así que la app lo busca por ese folio (#136).

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

  static final RegExp _folio = RegExp(r'#(\d+)');

  /// true si el aviso habla de una comanda.
  bool get esDeComanda => titulo.toLowerCase().contains('comanda');

  /// El folio del título («Nueva comanda #5001» → 5001); null si no lo trae.
  int? get folioComanda {
    final m = _folio.firstMatch(titulo);
    return m == null ? null : int.tryParse(m[1]!);
  }

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
