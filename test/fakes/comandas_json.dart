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
}) => {
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
}) => {
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
}) => {
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

/// Un cambio de un campo para producción (CambioCampo).
Map<String, dynamic> cambioJson(String campo, String? antes, String? despues) =>
    {'campo': campo, 'antes': antes, 'despues': despues};

/// Un evento del historial de la comanda (del más reciente al más viejo).
Map<String, dynamic> eventoJson({
  String evento = 'modificada',
  int version = 2,
  List<Map<String, dynamic>> cambios = const [],
}) => {
  'id': version * 10,
  'evento': evento,
  'version': version,
  'usuario_nombre': 'Laura Cruz',
  'cambios': cambios,
  'created_at': '2026-10-11T18:00:00.000Z',
};

/// Renglón de pastel del detalle (sin precios: producción los recibe en null).
Map<String, dynamic> pastelJson({
  String nombre = 'Pastel de chocolate',
  int cantidad = 1,
  String sabor = 'Chocolate',
  String tamano = '20 personas',
  String forma = 'Redondo',
  int pisos = 2,
  String? decoracion = 'Flores naturales',
  String? colorFondo,
  String? leyenda = 'Feliz cumpleaños Ana',
  String? descripcion,
  String? insumos,
}) => {
  'id': 1,
  'tipo': 'pastel',
  'orden': 1,
  'nombre': nombre,
  'cantidad': cantidad,
  'sabor': sabor,
  'tamano': tamano,
  'forma': forma,
  'num_pisos': pisos,
  'decoracion': decoracion,
  'color_fondo': colorFondo,
  'leyenda': leyenda,
  'descripcion': descripcion,
  'insumos': insumos,
  'precio_unitario': null,
  'subtotal': null,
};

/// Renglón de producto del catálogo del detalle.
Map<String, dynamic> productoJson({
  String nombre = 'Tart Bites 24 piezas',
  int cantidad = 2,
  String tamano = 'grande',
  String? indicaciones = 'Sin azúcar glass',
}) => {
  'id': 2,
  'tipo': 'producto',
  'orden': 2,
  'nombre': nombre,
  'cantidad': cantidad,
  'producto_id': 15,
  'categoria': 'Postres',
  'imagen_url': null,
  'tamano_catalogo': tamano,
  'indicaciones': indicaciones,
  'precio_unitario': null,
  'subtotal': null,
};

/// Respuesta completa de GET /comandas/:id para producción.
Map<String, dynamic> detalleJson({
  int id = 7,
  int folio = 5003,
  String estado = 'activa',
  int version = 1,
  int dias = 2,
  String? semaforo = 'naranja',
  String? confirmar = 'hornos',
  Map<String, dynamic>? hornos,
  Map<String, dynamic>? decoracion,
  List<Map<String, dynamic>>? items,
  List<String> imagenes = const [],
  List<Map<String, dynamic>>? cambiosPendientes,
  List<Map<String, dynamic>> historial = const [],
  String? notas = 'Entregar en salón Las Palmas',
  String? motivoCancelacion,
  String? total,
  String? anticipo,
  String? saldo,
  String? saldoCobrado,
  bool entregar = false,
  bool cancelar = false,
  bool imprimir = false,
}) => {
  'success': true,
  'comanda': {
    'id': id,
    'folio': folio,
    'estado': estado,
    'sucursal': 'Huejutla',
    'cliente_nombre': 'María López',
    'cliente_telefono': '7711234567',
    'fecha_entrega': '2026-10-14',
    'hora_entrega': '11:00',
    'dias_restantes': dias,
    'semaforo': semaforo,
    'notas': notas,
    'mesa_color_capacillos': 'Dorado',
    'mesa_color_betun': 'Blanco',
    'mesa_color_grageas': null,
    'subtotal': total,
    'descuento': total == null ? null : '0.00',
    'total': total,
    'anticipo': anticipo,
    'saldo': saldo,
    'version': version,
    'actualizada_en': '2026-10-11T18:00:00.000Z',
    'tomado_por': {'id': 3, 'nombre': 'Laura Cruz'},
    'created_at': '2026-10-10T16:00:00.000Z',
    'entregada_at': null,
    'entregada_por_nombre': null,
    'saldo_cobrado': saldoCobrado,
    'cancelada_at': null,
    'cancelada_por_nombre': null,
    'motivo_cancelacion': motivoCancelacion,
    'items': items ?? [pastelJson(), productoJson()],
    'imagenes': [
      for (final (i, url) in imagenes.indexed)
        {'id': i + 1, 'url': url, 'public_id': 'p$i', 'orden': i},
    ],
    'firmas': {
      'hornos': hornos ?? firmaJson(),
      'decoracion': decoracion ?? firmaJson(),
    },
    'confirmaciones': const [],
    'historial': historial,
    'cambios_pendientes': cambiosPendientes,
  },
  'permisos': {
    'editar': false,
    'cancelar': cancelar,
    'entregar': entregar,
    'imprimir': imprimir,
    'confirmar': confirmar,
  },
};

/// Respuesta de GET /comandas/catalogo (#130): dos sabores, opciones de una
/// sola, [pct] % de anticipo mínimo y [dias] de anticipación; productos con y
/// sin tamaño grande, y uno sin precio (se omite).
Map<String, dynamic> catalogoJson({int pct = 50, int dias = 3}) => {
      'success': true,
      'opciones': {
        'sabor': [
          {'id': 1, 'nombre': 'Chocolate', 'orden': 1},
          {'id': 2, 'nombre': 'Vainilla', 'orden': 2},
        ],
        'tamano': [
          {'id': 3, 'nombre': '20 personas', 'orden': 1},
        ],
        'forma': [
          {'id': 4, 'nombre': 'Redondo', 'orden': 1},
        ],
        'decoracion': [
          {'id': 5, 'nombre': 'Flores', 'orden': 1},
          {'id': 6, 'nombre': '  ', 'orden': 2},
        ],
      },
      'ajustes': {
        'anticipo_minimo_pct': pct,
        'dias_anticipacion_minima': dias,
        'semaforo_rojo_dias': 1,
      },
      'productos': [
        {
          'id': 10,
          'nombre': 'Gelatina',
          'categoria': 'Postres',
          'precio_chico': '45.50',
          'precio_grande': '120.00',
          'imagen_url': null,
        },
        {
          'id': 11,
          'nombre': 'Galleta',
          'categoria': 'Mesa de postres',
          'precio_chico': '12.00',
          'precio_grande': null,
        },
        {'id': 12, 'nombre': 'Sin precio'},
      ],
    };
