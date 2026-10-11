// lib/data/repositories/reembolsos_repository_remote.dart
//
// Implementación HTTP de ReembolsosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository.dart';
import 'package:pier_pasteleria/data/repositories/subir_imagen.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/reembolso.dart';

/// Implementación de [ReembolsosRepository] contra el backend vía [ApiClient].
class ReembolsosRepositoryRemote implements ReembolsosRepository {
  ReembolsosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> misReembolsos() => _api.getAuth(ApiConstants.misReembolsos);

  @override
  Future<List<Reembolso>> listarMisReembolsos() async {
    final r = await misReembolsos();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus solicitudes',
      );
    }
    final data = r['reembolsos'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Reembolso.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearReembolso, body);

  @override
  Future<void> solicitar({
    required String pedidoId,
    required double monto,
    required String motivo,
    required String descripcion,
    List<String> fotos = const [],
  }) async {
    final r = await crear({
      'pedido_id': int.tryParse(pedidoId) ?? pedidoId,
      'monto': monto,
      'motivo': motivo,
      'descripcion': descripcion,
      if (fotos.isNotEmpty) 'fotos_evidencia': fotos,
    });
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al enviar solicitud',
      );
    }
  }

  @override
  Future<String> subirEvidencia(String filePath) =>
      subirImagen(_api, filePath, tipo: 'reembolso');
}
