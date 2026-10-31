// test/fakes/resenas_json.dart — las reseñas de Chocoflan (producto 7) en un
// backend falso en memoria, para las pruebas de aceptación de las reseñas
// (#64; historias #41 y #42).
//
// Responde como routes/resenasRoutes.js y el detalle de
// routes/productosRoutes.js del backend: el detalle del producto y sus
// «Opiniones» solo muestran las aprobadas; POST /resenas rechaza una segunda
// reseña del mismo cliente y publica al momento las de 4 o 5 estrellas;
// «útil» (POST /resenas/:id/like) alterna el voto del cliente, salvo en su
// propia opinión; PUT /resenas/:id guarda los cambios y, con menos de 4
// estrellas, la regresa a revisión. Las reseñas no traen fecha: la app la
// muestra relativa a hoy y así las pruebas no dependen del reloj.
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';

import 'fake_api_client.dart';

/// Id del cliente con sesión (Ana López).
const int idCliente = 1;

/// Respuesta del backend al iniciar sesión como ese cliente.
const Map<String, dynamic> _sesion = {
  'success': true,
  'token': 'jwt',
  'user': {
    'id': idCliente,
    'nombre': 'Ana',
    'apellido': 'López',
    'email': 'ana@pier.mx',
    'rol': 'cliente',
  },
};

/// El producto cuyas reseñas se prueban, como lo trae el catálogo.
final Product chocoflan = Product.fromJson(const {
  'id': 7,
  'nombre': 'Chocoflan',
  'descripcion': 'Flan con pastel de chocolate',
  'precio_chico': 300,
  'categoria': 'Pasteles',
  'imagen_url': '',
  'activo': true,
});

/// Una reseña aprobada de Chocoflan; con [deAna] es del cliente con sesión.
Map<String, dynamic> resenaJson({
  required int id,
  required int rating,
  required String comentario,
  String autor = 'Luis',
  String apellido = 'Pérez',
  int util = 0,
  bool verificada = false,
  bool deAna = false,
}) => {
  'id': id,
  'producto_id': 7,
  'usuario_id': deAna ? idCliente : 100 + id,
  'rating': rating,
  'titulo': '',
  'comentario': comentario,
  'util_count': util,
  'verificada': verificada,
  'estado': 'aprobada',
  'autor_nombre': deAna ? 'Ana' : autor,
  'autor_apellido': deAna ? 'López' : apellido,
};

/// Tres opiniones aprobadas de otros clientes: 5, 4 y 2 estrellas.
List<Map<String, dynamic>> opinionesDeOtros() => [
  resenaJson(
    id: 1,
    rating: 5,
    comentario: 'El mejor flan que he probado',
    util: 3,
    verificada: true,
  ),
  resenaJson(
    id: 2,
    rating: 4,
    comentario: 'Muy rico, aunque algo dulce',
    autor: 'Carla',
    apellido: 'Ruiz',
  ),
  resenaJson(
    id: 3,
    rating: 2,
    comentario: 'Llegó un poco aplastado',
    autor: 'Mario',
    apellido: 'Díaz',
    util: 1,
  ),
];

/// Las reseñas de Chocoflan como las tiene el backend, con los votos «útil»
/// del cliente con sesión.
class BackendResenas {
  BackendResenas(List<Map<String, dynamic>> iniciales)
    : resenas = [for (final r in iniciales) {...r}] {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.login: _sesion,
        ApiConstants.productoById('7'): _detalle,
        ApiConstants.recomendaciones('7'): {
          'success': true,
          'recomendaciones': <Map<String, dynamic>>[],
        },
        ApiConstants.resenasPorProducto('7'): _opiniones,
        ApiConstants.misUtiles('7'): _misUtiles,
        ApiConstants.crearResena: _crear,
        ApiConstants.misResenas: _misResenas,
        // Las reseñas que ya hay y la que se cree (ids 1 a idNueva).
        for (var id = 1; id <= idNueva; id++) ...{
          ApiConstants.likeResena('$id'): _util,
          ApiConstants.editarResena('$id'): _editar,
        },
      },
    );
  }

  /// Id que el backend le da a la siguiente reseña.
  static const int idNueva = 20;

  /// Lo que responde POST /resenas si el cliente ya reseñó el producto.
  static const String yaResenada = 'Ya dejaste una reseña para este producto';

  /// Todas las reseñas de Chocoflan, de la más nueva a la más vieja.
  final List<Map<String, dynamic>> resenas;
  late final FakeApiClient api;

  /// Las reseñas que el cliente marcó «útil».
  final Set<int> utiles = {};

  /// Las reseñas del cliente con sesión.
  List<Map<String, dynamic>> get deAna => [
    for (final r in resenas)
      if (r['usuario_id'] == idCliente) r,
  ];

  /// Las que se publican (el resto espera revisión).
  List<Map<String, dynamic>> get _aprobadas => [
    for (final r in resenas)
      if (r['estado'] == 'aprobada') r,
  ];

  /// GET /productos/7: el producto con su promedio y sus opiniones.
  Map<String, dynamic> _detalle(LlamadaApi _) {
    final aprobadas = _aprobadas;
    final suma = aprobadas.fold<int>(
      0,
      (total, r) => total + (r['rating'] as int),
    );
    return {
      'success': true,
      'producto': {
        'imagenes': <String>[],
        'reviews': aprobadas.length,
        'rating_promedio': aprobadas.isEmpty
            ? '0.0'
            : (suma / aprobadas.length).toStringAsFixed(1),
      },
      'resenas': [for (final r in aprobadas) {...r}],
    };
  }

  /// GET /resenas/producto/7.
  Map<String, dynamic> _opiniones(LlamadaApi _) => {
    'success': true,
    'resenas': [for (final r in _aprobadas) {...r}],
  };

  /// GET /resenas/mis-utiles?producto_id=7.
  Map<String, dynamic> _misUtiles(LlamadaApi _) => {
    'success': true,
    'ids': [...utiles],
  };

  /// POST /resenas/:id/like: alterna el voto «útil» del cliente.
  Map<String, dynamic> _util(LlamadaApi llamada) {
    final resena = _deEndpoint(llamada);
    if (resena == null) {
      return {'success': false, 'message': 'Reseña no encontrada'};
    }
    if (resena['usuario_id'] == idCliente) {
      return {
        'success': false,
        'message': 'No puedes marcar como útil tu propia opinión',
      };
    }
    final id = resena['id'] as int;
    final marcada = utiles.add(id);
    if (!marcada) utiles.remove(id);
    resena['util_count'] = (resena['util_count'] as int) + (marcada ? 1 : -1);
    return {
      'success': true,
      'liked': marcada,
      'message': marcada ? 'Like agregado' : 'Like removido',
      'util_count': resena['util_count'],
    };
  }

  /// POST /resenas: una sola por cliente y producto. Con 4 o 5 estrellas se
  /// publica al momento; como el cliente compró el producto, queda como
  /// «Compra verificada».
  Map<String, dynamic> _crear(LlamadaApi llamada) {
    if (deAna.isNotEmpty) {
      return {'success': false, 'message': yaResenada};
    }
    final body = llamada.body!;
    final rating = body['rating'] as int;
    final publicada = rating >= 4;
    final nueva = {
      ...resenaJson(
        id: idNueva,
        rating: rating,
        comentario: body['comentario'] as String,
        verificada: true,
        deAna: true,
      ),
      'titulo': body['titulo'],
      'estado': publicada ? 'aprobada' : 'pendiente',
    };
    resenas.insert(0, nueva);
    return {
      'success': true,
      'resena': {...nueva, 'auto_aprobada': publicada},
      'message': publicada ? 'Reseña publicada' : 'Reseña en revisión',
    };
  }

  /// GET /resenas/mis-resenas: las del cliente, con su producto.
  Map<String, dynamic> _misResenas(LlamadaApi _) => {
    'success': true,
    'resenas': [
      for (final r in deAna)
        {...r, 'producto_nombre': 'Chocoflan', 'producto_imagen': ''},
    ],
  };

  /// PUT /resenas/:id: guarda los cambios; con menos de 4 estrellas la
  /// reseña regresa a revisión.
  Map<String, dynamic> _editar(LlamadaApi llamada) {
    final resena = _deEndpoint(llamada);
    if (resena == null || resena['usuario_id'] != idCliente) {
      return {'success': false, 'message': 'No puedes editar esta reseña'};
    }
    final body = llamada.body!;
    final publicada = (body['rating'] as int) >= 4;
    resena
      ..['rating'] = body['rating']
      ..['titulo'] = body['titulo']
      ..['comentario'] = body['comentario']
      ..['estado'] = publicada ? 'aprobada' : 'pendiente';
    return {
      'success': true,
      'message': publicada
          ? 'Reseña actualizada'
          : 'Reseña actualizada: la revisaremos antes de publicarla',
    };
  }

  /// La reseña de /resenas/:id o de /resenas/:id/like (null si no existe).
  Map<String, dynamic>? _deEndpoint(LlamadaApi llamada) {
    final id = int.parse(llamada.endpoint.split('/')[2]);
    return resenas.where((r) => r['id'] == id).firstOrNull;
  }
}
