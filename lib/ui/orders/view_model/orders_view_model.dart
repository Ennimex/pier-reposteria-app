// lib/ui/orders/view_model/orders_view_model.dart
//
// Estado de «Mis Pedidos» (MVVM, Fase 3): pedidos activos y finalizados del
// cliente. Si el backend falla se conserva la última lista (la pantalla no
// muestra error, como antes). La vista decide cuándo recargar (al entrar a la
// pestaña, al jalar para refrescar) y le dice si hay sesión.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel({required PedidosRepository repo}) : _repo = repo;

  final PedidosRepository _repo;
  bool _cerrado = false;

  List<Order> _activos = const [];
  List<Order> _finalizados = const [];
  bool _cargando = true;

  List<Order> get activos => _activos;
  List<Order> get finalizados => _finalizados;

  /// true durante la primera carga (o una no silenciosa): la vista pinta
  /// esqueletos.
  bool get cargando => _cargando;

  /// [conSesion] false limpia la lista: la pestaña vive en el IndexedStack y
  /// sin esto el historial del usuario anterior seguía visible como invitado.
  /// [silenciosa] recarga sin esqueletos (pull-to-refresh, volver a la
  /// pestaña).
  Future<void> cargar({required bool conSesion, bool silenciosa = false}) async {
    if (!conSesion) {
      _activos = const [];
      _finalizados = const [];
      _cargando = false;
      notifyListeners();
      return;
    }
    if (!silenciosa) {
      _cargando = true;
      notifyListeners();
    }
    try {
      final todos = await _repo.listarMisPedidos();
      if (_cerrado) return;
      _activos = todos.where((o) => !o.esFinalizado).toList();
      _finalizados = todos.where((o) => o.esFinalizado).toList();
    } on ApiException {
      // Se conserva la última lista.
    }
    if (_cerrado) return;
    if (!silenciosa) _cargando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
