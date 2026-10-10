// lib/data/repositories/pedidos_repository.dart
//
// Única puerta a los datos de los pedidos del cliente. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es PedidosRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: los métodos tipados (listarMisPedidos, itemsDelPedido) lanzan
// ApiException si el
// backend falla; los crudos siguen para las pantallas aún sin ViewModel.
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

abstract class PedidosRepository {
  /// GET /pedidos/mis-pedidos
  Future<Map<String, dynamic>> misPedidos();

  /// GET /pedidos/mis-pedidos tipado. Acepta la lista en `pedidos` o `data`;
  /// ignora elementos que no sean objetos.
  Future<List<Order>> listarMisPedidos();

  /// GET /pedidos/:id (items con producto_id/tamano/cantidad/precio_unitario)
  Future<Map<String, dynamic>> detalle(String id);

  /// Productos de un pedido (para «Volver a pedir»): mis-pedidos no trae
  /// producto_id, así que se lee el detalle. Ignora elementos que no sean
  /// objetos; lanza ApiException si el backend falla.
  Future<List<OrderItem>> itemsDelPedido(String id);

  /// PUT /pedidos/:id/cancelar (solo pendiente/listo sin repartidor asignado)
  Future<Map<String, dynamic>> cancelar(String id);

  /// GET /pedidos/productos-comprados ("pide de nuevo")
  Future<Map<String, dynamic>> productosComprados();

  /// GET /pedidos/productos-comprados tipado: lo que el cliente ya pidió,
  /// con el precio que pagó (o el chico). Lanza ApiException si falla.
  Future<List<Product>> listarProductosComprados();
}
