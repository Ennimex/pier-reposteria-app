// lib/domain/models/publicacion.dart
//
// Publicaciones del inicio del cliente (módulo del backend del 11-oct,
// migración 011). Fuente: /api/publicaciones (routes/publicacionesRoutes.js):
// el feed por páginas con cursor, las promociones vigentes para intercalar y
// los productos sugeridos. Los precios llegan como texto (NUMERIC).
import 'package:pier_pasteleria/domain/models/product_model.dart';

double _precio(Object? valor) => double.tryParse(valor?.toString() ?? '') ?? 0;

int _entero(Object? valor) => (valor as num?)?.toInt() ?? 0;

String? _opcional(Object? valor) {
  final t = valor?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

List<Map<String, dynamic>> _mapas(Object? lista) => lista is List
    ? lista
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList()
    : const [];

/// Una foto o un video de la publicación (URLs de Cloudinary).
class MedioPublicacion {
  MedioPublicacion.fromJson(Map<String, dynamic> json)
    : esVideo = json['tipo'] == 'video',
      url = json['url']?.toString() ?? '',
      portada = _opcional(json['poster_url']),
      duracion = (json['duracion'] as num?)?.toDouble(),
      proporcion = _proporcion(json['ancho'], json['alto']);

  final bool esVideo;
  final String url;

  /// Portada del video (cuadro inicial en jpg).
  final String? portada;

  /// Segundos del video.
  final double? duracion;

  /// Ancho / alto, acotado como en la web: ni más alta que 4:5 ni más ancha
  /// que 1.91:1 (1 si no llegaron las medidas).
  final double proporcion;

  static double _proporcion(Object? ancho, Object? alto) {
    final a = _entero(ancho);
    final h = _entero(alto);
    if (a <= 0 || h <= 0) return 1;
    return (a / h).clamp(0.8, 1.91);
  }
}

/// Un comentario visible. La respuesta oficial sale a nombre de la marca.
class ComentarioPublicacion {
  ComentarioPublicacion.fromJson(Map<String, dynamic> json)
    : id = _entero(json['id']),
      texto = json['texto']?.toString() ?? '',
      creado = DateTime.tryParse(json['created_at']?.toString() ?? ''),
      esOficial = json['es_oficial'] == true,
      autorNombre =
          (json['autor'] is Map
              ? (json['autor'] as Map)['nombre']?.toString()
              : null) ??
          '',
      avatarUrl = json['autor'] is Map
          ? _opcional((json['autor'] as Map)['avatar_url'])
          : null,
      esTuyo =
          json['autor'] is Map && (json['autor'] as Map)['es_tuyo'] == true,
      puedeBorrar = json['puede_borrar'] == true;

  final int id;
  final String texto;
  final DateTime? creado;
  final bool esOficial;

  /// 'Carla C.' o 'Pier Repostería'.
  final String autorNombre;
  final String? avatarUrl;
  final bool esTuyo;
  final bool puedeBorrar;
}

/// Una publicación del feed: texto, fotos o videos, «Me encanta» y los
/// comentarios más recientes.
class Publicacion {
  const Publicacion._({
    required this.id,
    required this.texto,
    required this.creada,
    required this.editada,
    required this.medios,
    required this.corazones,
    required this.meEncanta,
    required this.totalComentarios,
    required this.comentariosRecientes,
  });

  Publicacion.fromJson(Map<String, dynamic> json)
    : id = _entero(json['id']),
      texto = _opcional(json['texto']),
      creada = DateTime.tryParse(json['created_at']?.toString() ?? ''),
      editada = json['editada'] == true,
      medios = _mapas(json['medios']).map(MedioPublicacion.fromJson).toList(),
      corazones = _entero(json['corazones']),
      meEncanta = json['me_encanta'] == true,
      totalComentarios = _entero(json['total_comentarios']),
      comentariosRecientes = _mapas(
        json['comentarios_recientes'],
      ).map(ComentarioPublicacion.fromJson).toList();

  final int id;
  final String? texto;
  final DateTime? creada;
  final bool editada;
  final List<MedioPublicacion> medios;
  final int corazones;
  final bool meEncanta;
  final int totalComentarios;

  /// Los 2 más recientes, en orden cronológico.
  final List<ComentarioPublicacion> comentariosRecientes;

  /// La misma publicación con otros contadores o comentarios recientes.
  Publicacion copiaCon({
    bool? meEncanta,
    int? corazones,
    int? totalComentarios,
    List<ComentarioPublicacion>? comentariosRecientes,
  }) => Publicacion._(
    id: id,
    texto: texto,
    creada: creada,
    editada: editada,
    medios: medios,
    corazones: corazones ?? this.corazones,
    meEncanta: meEncanta ?? this.meEncanta,
    totalComentarios: totalComentarios ?? this.totalComentarios,
    comentariosRecientes: comentariosRecientes ?? this.comentariosRecientes,
  );
}

/// Cómo quedó «Me encanta» de una publicación.
typedef ReaccionPublicacion = ({bool meEncanta, int corazones});

/// Una página de comentarios visibles.
typedef PaginaComentarios = ({
  List<ComentarioPublicacion> comentarios,
  bool hayMas,
});

/// Lee la respuesta de GET /publicaciones/:id/comentarios.
PaginaComentarios paginaComentariosDe(Map<String, dynamic> json) => (
  comentarios: _mapas(
    json['comentarios'],
  ).map(ComentarioPublicacion.fromJson).toList(),
  hayMas: json['hay_mas'] == true,
);

/// Dónde sigue el feed: la última publicación vista (fecha con
/// microsegundos e id).
class CursorFeed {
  const CursorFeed({required this.antes, required this.antesId});

  final String antes;
  final int antesId;
}

/// Una página del feed; el cursor siguiente es null si ya no hay más.
typedef PaginaFeed = ({List<Publicacion> publicaciones, CursorFeed? siguiente});

/// Una página de sugerencias.
typedef PaginaSugerencias = ({List<ProductoSugerido> productos, bool hayMas});

/// Lee la respuesta de GET /publicaciones/feed.
PaginaFeed paginaFeedDe(Map<String, dynamic> json) {
  final s = json['siguiente'];
  return (
    publicaciones: _mapas(
      json['publicaciones'],
    ).map(Publicacion.fromJson).toList(),
    siguiente: s is Map && s['antes'] != null
        ? CursorFeed(
            antes: s['antes'].toString(),
            antesId: _entero(s['antes_id']),
          )
        : null,
  );
}

/// Lee la respuesta de GET /publicaciones/sugerencias.
PaginaSugerencias paginaSugerenciasDe(Map<String, dynamic> json) => (
  productos: _mapas(json['productos']).map(ProductoSugerido.fromJson).toList(),
  hayMas: json['hay_mas'] == true,
);

/// Un producto del catálogo tal como se agrega al carrito desde el feed.
Product _producto({
  required int id,
  required String nombre,
  required double precio,
  required double? precioGrande,
  required String categoria,
  required String imagenUrl,
}) => Product(
  id: '$id',
  nombre: nombre,
  descripcion: '',
  precio: precio,
  precioGrande: precioGrande,
  categoria: categoria,
  imagenUrl: imagenUrl,
);

/// Promoción vigente para intercalar (una por producto, con stock).
class PromocionFeed {
  PromocionFeed.fromJson(Map<String, dynamic> json)
    : this._(
        json,
        json['producto'] is Map
            ? Map<String, dynamic>.from(json['producto'] as Map)
            : const {},
      );

  PromocionFeed._(Map<String, dynamic> json, Map<String, dynamic> p)
    : id = _entero(json['id']),
      titulo = json['titulo']?.toString() ?? '',
      subtitulo = _opcional(json['subtitulo']),
      etiqueta = _opcional(json['etiqueta']),
      descuentoPorcentaje = (json['descuento_porcentaje'] as num?)?.toInt(),
      precioNormal = _precio(json['precio_normal']),
      precioPromocion = _precio(json['precio_promocion']),
      productoId = _entero(p['id']),
      productoNombre = p['nombre']?.toString() ?? '',
      imagenUrl = p['imagen_url']?.toString() ?? '',
      categoria = p['categoria']?.toString() ?? '',
      precioGrande = p['precio_grande'] == null
          ? null
          : _precio(p['precio_grande']);

  final int id;
  final String titulo;
  final String? subtitulo;

  /// 'Favorito', 'Nuevo'… (solo promociones destacadas).
  final String? etiqueta;
  final int? descuentoPorcentaje;

  /// Precio chico sin y con el descuento (lo que cobran carrito y pago).
  final double precioNormal;
  final double precioPromocion;
  final int productoId;
  final String productoNombre;
  final String imagenUrl;
  final String categoria;
  final double? precioGrande;

  Product get comoProducto => _producto(
    id: productoId,
    nombre: productoNombre,
    precio: precioNormal,
    precioGrande: precioGrande,
    categoria: categoria,
    imagenUrl: imagenUrl,
  );
}

/// Producto sugerido: afín a lo que compró el cliente o de los más pedidos.
class ProductoSugerido {
  ProductoSugerido.fromJson(Map<String, dynamic> json)
    : id = _entero(json['id']),
      nombre = json['nombre']?.toString() ?? '',
      imagenUrl = json['imagen_url']?.toString() ?? '',
      categoria = json['categoria']?.toString() ?? '',
      precioChico = _precio(json['precio_chico']),
      precioGrande = json['precio_grande'] == null
          ? null
          : _precio(json['precio_grande']),
      motivo = json['motivo']?.toString() ?? '';

  final int id;
  final String nombre;
  final String imagenUrl;
  final String categoria;
  final double precioChico;
  final double? precioGrande;

  /// 'Porque te gustó Chocoflan' o 'De los más pedidos'.
  final String motivo;

  Product get comoProducto => _producto(
    id: id,
    nombre: nombre,
    precio: precioChico,
    precioGrande: precioGrande,
    categoria: categoria,
    imagenUrl: imagenUrl,
  );
}
