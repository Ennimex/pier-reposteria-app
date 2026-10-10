// lib/data/repositories/quejas_repository_remote.dart
//
// Implementación HTTP de QuejasRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/queja.dart';

/// Implementación de [QuejasRepository] contra el backend vía [ApiClient].
class QuejasRepositoryRemote implements QuejasRepository {
  QuejasRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> misQuejas() => _api.getAuth(ApiConstants.misQuejas);

  @override
  Future<List<Queja>> listarMisQuejas() async {
    final r = await misQuejas();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus quejas',
      );
    }
    final data = r['quejas'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Queja.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearQueja, body);

  @override
  Future<String> crearQueja({
    required TipoQueja tipo,
    required CategoriaQueja categoria,
    required String asunto,
    required String descripcion,
    String? pedidoId,
  }) async {
    final r = await crear({
      'tipo': tipo.name,
      'categoria': categoria.name,
      'asunto': asunto,
      'descripcion': descripcion,
      if (pedidoId != null && pedidoId.isNotEmpty)
        'pedido_id': int.tryParse(pedidoId) ?? pedidoId,
    });
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al enviar la queja',
      );
    }
    final queja = r['queja'];
    return queja is Map ? queja['ticket']?.toString() ?? '' : '';
  }
}
