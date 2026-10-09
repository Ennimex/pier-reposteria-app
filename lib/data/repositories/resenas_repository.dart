// lib/data/repositories/resenas_repository.dart
//
// Única puerta a los datos de reseñas. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: los métodos tipados (crearResena, listarMisResenas, editarResena)
// lanzan ApiException si el backend falla.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/mi_resena.dart';

class ResenasRepository {
  ResenasRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// GET /resenas/mis-resenas
  Future<Map<String, dynamic>> misResenas() => _api.getAuth(ApiConstants.misResenas);

  /// GET /resenas/destacadas (público, home)
  Future<Map<String, dynamic>> destacadas() => _api.get(ApiConstants.resenasDestacadas);

  /// GET /resenas/producto/:id (público, solo aprobadas)
  Future<Map<String, dynamic>> porProducto(String productoId) =>
      _api.get(ApiConstants.resenasPorProducto(productoId));

  /// POST /resenas: {producto_id, rating, titulo, comentario}. Devuelve
  /// true si quedó publicada de inmediato (auto_aprobada) y false si quedó en
  /// revisión. Lanza ApiException con el mensaje del backend (p. ej. «Ya
  /// dejaste una reseña para este producto»).
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

  /// GET /resenas/mis-resenas tipado; ignora elementos que no sean objetos.
  /// misResenas() crudo se queda para el contador de «Más».
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

  /// PUT /resenas/:id (solo la propia). Devuelve el mensaje del backend para
  /// mostrarlo; lanza ApiException si no se guardó.
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

  /// POST /resenas/:id/like ("útil")
  Future<Map<String, dynamic>> like(String id) => _api.postAuth(ApiConstants.likeResena(id), {});
}
