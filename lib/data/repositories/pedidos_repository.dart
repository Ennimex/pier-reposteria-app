// lib/data/repositories/pedidos_repository.dart
//
// Única puerta a los datos de los pedidos del cliente. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class PedidosRepository {
  final ApiClient _api;
  PedidosRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /pedidos/mis-pedidos
  Future<Map<String, dynamic>> misPedidos() => _api.getAuth(ApiConstants.misPedidos);

  /// GET /pedidos/:id (items con producto_id/tamano/cantidad/precio_unitario)
  Future<Map<String, dynamic>> detalle(String id) => _api.getAuth(ApiConstants.pedidoById(id));

  /// PUT /pedidos/:id/cancelar (solo pendiente/listo sin repartidor asignado)
  Future<Map<String, dynamic>> cancelar(String id) =>
      _api.putAuth(ApiConstants.pedidoCancelar(id), {});

  /// GET /pedidos/productos-comprados ("pide de nuevo")
  Future<Map<String, dynamic>> productosComprados() =>
      _api.getAuth(ApiConstants.productosComprados);
}
