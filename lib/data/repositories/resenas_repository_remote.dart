// lib/data/repositories/resenas_repository_remote.dart
//
// Implementación HTTP de ResenasRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/mi_resena.dart';
import 'package:pier_pasteleria/domain/models/resena_producto.dart';

/// Implementación de [ResenasRepository] contra el backend vía [ApiClient].
class ResenasRepositoryRemote implements ResenasRepository {
  ResenasRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> misResenas() => _api.getAuth(ApiConstants.misResenas);

  @override
  Future<Map<String, dynamic>> destacadas() => _api.get(ApiConstants.resenasDestacadas);

  @override
  Future<Map<String, dynamic>> porProducto(String productoId) =>
      _api.get(ApiConstants.resenasPorProducto(productoId));

  @override
  Future<List<ResenaProducto>> listarDeProducto(String productoId) async {
    final r = await porProducto(productoId);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las opiniones',
      );
    }
    final data = r['resenas'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => ResenaProducto.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<bool> crearResena({
    required String productoId,
    required int rating,
    required String titulo,
    required String comentario,
  }) async {
    final r = await _api.postAuth(ApiConstants.crearResena, {
      'producto_id': productoId,
      'rating': rating,
      'titulo': titulo,
      'comentario': comentario,
    });
    if (r['success'] != true) {
      throw ApiException(r['message']?.toString() ?? 'Error al enviar');
    }
    final resena = r['resena'];
    return resena is Map && resena['auto_aprobada'] == true;
  }

  @override
  Future<List<MiResena>> listarMisResenas() async {
    final r = await misResenas();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus reseñas',
      );
    }
    final data = r['resenas'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => MiResena.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<String> editarResena({
    required String id,
    required int rating,
    required String titulo,
    required String comentario,
  }) async {
    final r = await _api.putAuth(ApiConstants.editarResena(id), {
      'rating': rating,
      'titulo': titulo,
      'comentario': comentario,
    });
    final mensaje = r['message']?.toString();
    if (r['success'] != true) {
      throw ApiException(mensaje ?? 'No se pudo actualizar la reseña');
    }
    return mensaje ?? 'Reseña actualizada';
  }

  @override
  Future<Map<String, dynamic>> like(String id) => _api.postAuth(ApiConstants.likeResena(id), {});

  @override
  Future<bool> alternarUtil(String id) async {
    final r = await like(id);
    if (r['success'] != true) {
      throw ApiException(r['message']?.toString() ?? 'Error al dar like');
    }
    return r['liked'] == true;
  }

  @override
  Future<List<Map<String, dynamic>>> listarDestacadas() async {
    final r = await destacadas();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las reseñas',
      );
    }
    final data = r['resenas'];
    return data is List
        ? data.whereType<Map<String, dynamic>>().toList()
        : const [];
  }
}
