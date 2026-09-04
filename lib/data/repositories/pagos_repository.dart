// lib/data/repositories/pagos_repository.dart
//
// Única puerta a los datos de pagos con Stripe. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class PagosRepository {
  final ApiClient _api;
  PagosRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /pagos/config: publishable key (público).
  Future<Map<String, dynamic>> config() => _api.get(ApiConstants.stripeConfig);

  /// POST /pagos/crear-intent: {tipo_entrega?, direccion_id?, horario_recogida?}
  /// -> {clientSecret, publishableKey, total, por_confirmar, ...}
  Future<Map<String, dynamic>> crearIntent(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearPaymentIntent, body);

  /// POST /pagos/confirmar: crea el pedido y vacía el carrito en la misma
  /// transacción (reintentar es seguro).
  Future<Map<String, dynamic>> confirmar(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.confirmarPago, body);
}
