// lib/ui/core/state/order_provider.dart
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';

class OrderProvider extends ChangeNotifier {
  final PedidosRepository _repo;

  OrderProvider({PedidosRepository? repo})
      : _repo = repo ?? PedidosRepository();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Order> get activeOrders =>
      _orders.where((o) => !o.esFinalizado).toList();

  List<Order> get completedOrders =>
      _orders.where((o) => o.esFinalizado).toList();

  Future<void> cargarPedidos() async {
    PierLog.info('📦 Descargando historial de pedidos...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repo.misPedidos();

    _isLoading = false;

    if (result['success'] == true) {
      final data = result['pedidos'] ?? result['data'] ?? [];
      _orders = (data as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
      PierLog.info('✅ Historial de pedidos cargados: ${_orders.length}');
    } else {
      _errorMessage = result['message'] ?? 'Error al cargar pedidos';
      PierLog.error('Error al cargar pedidos: $_errorMessage');
    }

    notifyListeners();
  }

  Future<void> refrescar() async {
    _orders = [];
    await cargarPedidos();
  }

  /// Limpia el estado en memoria al cerrar sesión: los pedidos son del
  /// usuario anterior y no deben seguir visibles como invitado ni
  /// aparecer al entrar con otra cuenta.
  void limpiar() {
    _orders = [];
    _errorMessage = null;
    notifyListeners();
  }

  Order? getOrderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Trae el detalle fresco de un pedido (GET /pedidos/:id) y sincroniza la
  /// copia cacheada en la lista. El backend valida que el pedido sea del
  /// usuario (403 si no). El detalle devuelve los items por separado; aquí se
  /// fusionan para que Order.fromJson los lea.
  Future<Order?> fetchOrderDetail(String id) async {
    final result = await _repo.detalle(id);
    if (result['success'] == true && result['pedido'] != null) {
      final pedidoJson = Map<String, dynamic>.from(result['pedido'] as Map);
      pedidoJson['items'] =
          result['items'] ?? pedidoJson['items'] ?? <dynamic>[];
      final fresh = Order.fromJson(pedidoJson);
      final idx = _orders.indexWhere((o) => o.id == fresh.id);
      if (idx != -1) {
        _orders[idx] = fresh;
        notifyListeners();
      }
      return fresh;
    }
    PierLog.error('Error detalle pedido $id: ${result['message']}');
    return null;
  }

  /// Cancela un pedido propio (PUT /pedidos/:id/cancelar). El backend solo lo
  /// permite en 'pendiente' o 'listo' y mientras ningún repartidor lo haya
  /// tomado; repone el stock y genera la solicitud de reembolso automática
  /// (aparece sola en Reembolsos).
  ///
  /// Si el servidor responde error, se re-consulta el detalle antes de darlo
  /// por fallido: el backend puede fallar DESPUÉS de aplicar la cancelación
  /// (p. ej. al enviar el correo de confirmación) y el pedido SÍ quedó
  /// cancelado.
  Future<Map<String, dynamic>> cancelarPedido(String id) async {
    final result = await _repo.cancelar(id);
    final okServidor = result['success'] == true;

    // Sincroniza lista y detalle con el estado real (éxito o no).
    final fresh = await fetchOrderDetail(id);
    final cancelado =
        okServidor || fresh?.status == OrderStatus.cancelled;

    final String message;
    if (okServidor) {
      message = result['message'] ??
          'Pedido cancelado; tu reembolso ya está en proceso';
    } else if (cancelado) {
      // El backend falló tras el COMMIT (correo): la cancelación sí aplicó.
      message = 'Pedido cancelado; tu reembolso ya está en proceso';
    } else {
      message = result['message'] ?? 'No se pudo cancelar el pedido';
      PierLog.error('Error al cancelar pedido $id: $message');
    }

    return {'ok': cancelado, 'order': fresh, 'message': message};
  }
}