// lib/data/repositories/pedidos_repository.dart
//
// Única puerta a los datos de los pedidos del cliente. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: los métodos tipados (listarMisPedidos) lanzan ApiException si el
// backend falla; los crudos siguen para las pantallas aún sin ViewModel.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';

class PedidosRepository {
  PedidosRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// GET /pedidos/mis-pedidos
  Future<Map<String, dynamic>> misPedidos() => _api.getAuth(ApiConstants.misPedidos);

  /// GET /pedidos/mis-pedidos tipado. Acepta la lista en `pedidos` o `data`;
  /// ignora elementos que no sean objetos.
  Future<List<Order>> listarMisPedidos() async {
    final r = await misPedidos();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus pedidos',
      );
    }
    final data = r['pedidos'] ?? r['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Order.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /pedidos/:id (items con producto_id/tamano/cantidad/precio_unitario)
  Future<Map<String, dynamic>> detalle(String id) => _api.getAuth(ApiConstants.pedidoById(id));

  /// PUT /pedidos/:id/cancelar (solo pendiente/listo sin repartidor asignado)
  Future<Map<String, dynamic>> cancelar(String id) =>
      _api.putAuth(ApiConstants.pedidoCancelar(id), {});

  /// GET /pedidos/productos-comprados ("pide de nuevo")
  Future<Map<String, dynamic>> productosComprados() =>
      _api.getAuth(ApiConstants.productosComprados);
}
