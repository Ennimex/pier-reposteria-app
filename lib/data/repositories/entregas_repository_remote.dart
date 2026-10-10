// lib/data/repositories/entregas_repository_remote.dart
//
// Implementación HTTP de EntregasRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Implementación de [EntregasRepository] contra el backend vía [ApiClient].
class EntregasRepositoryRemote implements EntregasRepository {
  EntregasRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> misEntregas() => _api.getAuth(ApiConstants.misEntregas);

  @override
  Future<Map<String, dynamic>> disponibilidad() => _api.getAuth(ApiConstants.disponibilidad);

  @override
  Future<Map<String, dynamic>> cambiarDisponibilidad(bool disponible) =>
      _api.putAuth(ApiConstants.disponibilidad, {'disponible': disponible});

  @override
  Future<Map<String, dynamic>> disponibles() => _api.getAuth(ApiConstants.entregasDisponibles);

  @override
  Future<Map<String, dynamic>> aceptar(String pedidoId) =>
      _api.postAuth(ApiConstants.entregasAceptar, {'pedido_id': pedidoId});

  @override
  Future<Map<String, dynamic>> cambiarEstado(String entregaId, Map<String, dynamic> body) =>
      _api.putAuth(ApiConstants.entregaEstado(entregaId), body);

  @override
  Future<Map<String, dynamic>> avisarLlegada(String entregaId) =>
      _api.postAuth(ApiConstants.entregaLlegue(entregaId), {});

  @override
  Future<Map<String, dynamic>> subirEvidencia(String filePath) =>
      _api.uploadImageAuth(
          ApiConstants.uploadImagen, filePath, {'tipo': 'entrega'});
}
