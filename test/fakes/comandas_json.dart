// test/fakes/comandas_json.dart — respuestas de ejemplo de GET /comandas
// (routes/comandasRoutes.js del backend) para las pruebas de la agenda de
// producción (#127). Los montos llegan como texto (NUMERIC de Postgres) y en
// null para hornos y decoración, igual que en el backend.

/// Firma de un área tal como la manda el backend (FirmaArea).
Map<String, dynamic> firmaJson({
  bool vigente = false,
  int? version,
  String? usuario,
  String? fecha,
}) =>
    {
      'vigente': vigente,
      'version': version,
      'usuario_nombre': usuario,
      'fecha': fecha,
    };

/// Una comanda del resumen de la agenda (resumenDeFila).
Map<String, dynamic> comandaJson({
  int id = 1,
  int folio = 5001,
  String estado = 'activa',
  String cliente = 'María López',
  String fecha = '2026-10-14',
  String hora = '11:00',
  int dias = 2,
  String? semaforo = 'naranja',
  int version = 1,
  String resumen = 'Pastel Chocolate · 20 personas',
  int imagenes = 0,
  Map<String, dynamic>? hornos,
  Map<String, dynamic>? decoracion,
  String? total,
  String? anticipo,
  String? saldo,
  String? entregadaAt,
  String? canceladaAt,
}) =>
    {
      'id': id,
      'folio': folio,
      'estado': estado,
      'cliente_nombre': cliente,
      'cliente_telefono': '7711234567',
      'fecha_entrega': fecha,
      'hora_entrega': hora,
      'dias_restantes': dias,
      'semaforo': semaforo,
      'version': version,
      'resumen': resumen,
      'num_productos': 1,
      'tiene_pastel': true,
      'num_imagenes': imagenes,
      'total': total,
      'anticipo': anticipo,
      'saldo': saldo,
      'tomado_por': {'id': 3, 'nombre': 'Laura Cruz'},
      'firmas': {
        'hornos': hornos ?? firmaJson(),
        'decoracion': decoracion ?? firmaJson(),
      },
      'created_at': '2026-10-10T16:00:00.000Z',
      'entregada_at': entregadaAt,
      'cancelada_at': canceladaAt,
    };

/// Respuesta completa de GET /comandas.
Map<String, dynamic> agendaJson(
  List<Map<String, dynamic>> comandas, {
  String hoy = '2026-10-12',
}) =>
    {
      'success': true,
      'hoy': hoy,
      'ajustes': {
        'anticipo_minimo_pct': 20,
        'dias_anticipacion_minima': 3,
        'semaforo_rojo_dias': 1,
        'semaforo_naranja_dias': 3,
        'semaforo_amarillo_dias': 7,
      },
      'comandas': comandas,
    };
