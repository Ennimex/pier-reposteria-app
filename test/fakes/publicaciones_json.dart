// test/fakes/publicaciones_json.dart — respuestas de ejemplo de
// /publicaciones (routes/publicacionesRoutes.js del backend) para las pruebas
// de las publicaciones del cliente (#132). Los precios llegan como texto
// (NUMERIC de Postgres), igual que en el backend.

/// Una foto o video de una publicación.
Map<String, dynamic> medioJson({
  int id = 1,
  String tipo = 'imagen',
  String url = 'https://res.cloudinary.com/pier/feed/a.webp',
  String? poster,
  int ancho = 1200,
  int alto = 900,
  num? duracion,
}) => {
  'id': id,
  'tipo': tipo,
  'url': url,
  'poster_url': poster,
  'ancho': ancho,
  'alto': alto,
  'duracion': duracion,
};

/// Un comentario visible de una publicación.
Map<String, dynamic> comentarioJson({
  int id = 1,
  String texto = '¡Se ve delicioso!',
  String autor = 'Carla C.',
  bool oficial = false,
  bool tuyo = false,
}) => {
  'id': id,
  'texto': texto,
  'created_at': '2026-10-12T17:00:00.000Z',
  'es_oficial': oficial,
  'autor': {'nombre': autor, 'avatar_url': null, 'es_tuyo': tuyo},
  'puede_borrar': tuyo,
};

/// Una publicación del feed.
Map<String, dynamic> publicacionJson({
  int id = 1,
  String? texto = 'Pastel de chocolate recién salido del horno',
  String creada = '2026-10-12T16:00:00.000Z',
  bool editada = false,
  List<Map<String, dynamic>>? medios,
  int corazones = 3,
  bool meEncanta = false,
  int totalComentarios = 0,
  List<Map<String, dynamic>> comentarios = const [],
}) => {
  'id': id,
  'texto': texto,
  'created_at': creada,
  'editada': editada,
  'autor': {'nombre': 'Pier Repostería'},
  'medios': medios ?? [medioJson()],
  'corazones': corazones,
  'me_encanta': meEncanta,
  'total_comentarios': totalComentarios,
  'comentarios_recientes': comentarios,
};

/// Respuesta de GET /publicaciones/feed; con [siguiente] hay otra página.
Map<String, dynamic> feedJson(
  List<Map<String, dynamic>> publicaciones, {
  Map<String, dynamic>? siguiente,
}) => {'success': true, 'publicaciones': publicaciones, 'siguiente': siguiente};

/// Cursor de la siguiente página del feed.
Map<String, dynamic> cursorJson({
  String antes = '2026-10-10T12:00:00.123456Z',
  int antesId = 5,
}) => {'antes': antes, 'antes_id': antesId};

/// Una promoción vigente para intercalar.
Map<String, dynamic> promocionFeedJson({
  int id = 1,
  int productoId = 10,
  String titulo = 'Chocoflan',
  String? subtitulo = 'Solo esta semana',
  String? etiqueta,
  int? descuento = 20,
  String normal = '250.00',
  String promocion = '200.00',
}) => {
  'id': id,
  'tipo': 'relampago',
  'titulo': titulo,
  'subtitulo': subtitulo,
  'etiqueta': etiqueta,
  'producto': {
    'id': productoId,
    'nombre': titulo,
    'imagen_url': 'https://res.cloudinary.com/pier/p$productoId.webp',
    'categoria': 'Postres',
    'precio_grande': '400.00',
  },
  'descuento_porcentaje': descuento,
  'precio_normal': normal,
  'precio_promocion': promocion,
  'fecha_fin': '2026-10-20T06:00:00.000Z',
};

/// Respuesta de GET /publicaciones/promociones.
Map<String, dynamic> promocionesFeedJson(List<Map<String, dynamic>> lista) => {
  'success': true,
  'promociones': lista,
};

/// Un producto sugerido.
Map<String, dynamic> sugeridoJson({
  int id = 20,
  String nombre = 'Pay de queso',
  String motivo = 'De los más pedidos',
  String chico = '180.00',
}) => {
  'id': id,
  'nombre': nombre,
  'imagen_url': 'https://res.cloudinary.com/pier/s$id.webp',
  'categoria': 'Pays',
  'precio_chico': chico,
  'precio_grande': '320.00',
  'motivo': motivo,
};

/// Respuesta de GET /publicaciones/sugerencias.
Map<String, dynamic> sugerenciasJson(
  List<Map<String, dynamic>> productos, {
  bool hayMas = false,
}) => {'success': true, 'productos': productos, 'hay_mas': hayMas};
