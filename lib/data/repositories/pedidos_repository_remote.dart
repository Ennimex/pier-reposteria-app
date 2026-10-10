// lib/data/repositories/pedidos_repository_remote.dart
//
// Implementación HTTP de PedidosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';

/// Implementación de [PedidosRepository] contra el backend vía [ApiClient].
class PedidosRepositoryRemote implements PedidosRepository {
  PedidosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> misPedidos() => _api.getAuth(ApiConstants.misPedidos);

  @override
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

  @override
  Future<Map<String, dynamic>> detalle(String id) => _api.getAuth(ApiConstants.pedidoById(id));

  @override
  Future<List<OrderItem>> itemsDelPedido(String id) async {
    final r = await detalle(id);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudo cargar el pedido',
      );
    }
    final data = r['items'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => OrderItem.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> cancelar(String id) =>
      _api.putAuth(ApiConstants.pedidoCancelar(id), {});

  @override
  Future<Map<String, dynamic>> productosComprados() =>
      _api.getAuth(ApiConstants.productosComprados);
}
