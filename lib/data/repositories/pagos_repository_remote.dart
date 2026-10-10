// lib/data/repositories/pagos_repository_remote.dart
//
// Implementación HTTP de PagosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Implementación de [PagosRepository] contra el backend vía [ApiClient].
class PagosRepositoryRemote implements PagosRepository {
  PagosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> config() => _api.get(ApiConstants.stripeConfig);

  @override
  Future<Map<String, dynamic>> crearIntent(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearPaymentIntent, body);

  @override
  Future<Map<String, dynamic>> confirmar(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.confirmarPago, body);
}
