// lib/ui/more/view_model/profile_view_model.dart
//
// Estado de «Mi Perfil» (MVVM, Fase 3): favoritos, pedidos recientes y
// «Volver a pedir». Cada lista tiene su propia carga; si el backend falla se
// queda vacía (la pantalla no muestra error, como antes). El carrito no se
// toca desde aquí: la vista pasa cómo agregar cada producto.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

/// Agrega al carrito: producto, cantidad, tamaño y precio unitario.
typedef AgregarAlCarrito = Future<void> Function(
  Product producto,
  int cantidad,
  String tamano,
  double precio,
);

/// Cómo terminó «Volver a pedir».
enum ResultadoReorden { agregado, sinProductos, ningunoAgregado, ocupado }

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required FavoritosRepository favoritosRepo,
    required PedidosRepository pedidosRepo,
  })  : _favoritosRepo = favoritosRepo,
        _pedidosRepo = pedidosRepo;

  final FavoritosRepository _favoritosRepo;
  final PedidosRepository _pedidosRepo;
  bool _cerrado = false;

  List<Product> _favoritos = const [];
  List<Order> _pedidos = const [];
  bool _cargandoFavoritos = true;
  bool _cargandoPedidos = true;
  String? _reordenandoId;

  List<Product> get favoritos => _favoritos;
  List<Order> get pedidos => _pedidos;
  bool get cargandoFavoritos => _cargandoFavoritos;
  bool get cargandoPedidos => _cargandoPedidos;

  /// Id del pedido que se está reordenando (su botón muestra el indicador).
  String? get reordenandoId => _reordenandoId;

  /// Carga favoritos y pedidos a la vez; cada sección termina por su cuenta.
  Future<void> cargar() => Future.wait([_cargarFavoritos(), _cargarPedidos()]);

  Future<void> _cargarFavoritos() async {
    try {
      _favoritos = await _favoritosRepo.listarProductos();
    } on ApiException {
      // Sección vacía.
    }
    if (_cerrado) return;
    _cargandoFavoritos = false;
    notifyListeners();
  }

  Future<void> _cargarPedidos() async {
    try {
      _pedidos = await _pedidosRepo.listarMisPedidos();
    } on ApiException {
      // Sección vacía.
    }
    if (_cerrado) return;
    _cargandoPedidos = false;
    notifyListeners();
  }

  /// Vuelve a agregar los productos de un pedido con [agregar]. Se salta los
  /// que no traen producto_id; sin tamaño van como 'chico'.
  Future<ResultadoReorden> reordenar(
    String pedidoId, {
    required AgregarAlCarrito agregar,
  }) async {
    if (pedidoId.isEmpty || _reordenandoId != null) {
      return ResultadoReorden.ocupado;
    }
    _reordenandoId = pedidoId;
    notifyListeners();

    var items = const <OrderItem>[];
    try {
      items = await _pedidosRepo.itemsDelPedido(pedidoId);
    } on ApiException {
      // Se trata como pedido sin productos.
    }

    var agregados = 0;
    if (!_cerrado) {
      for (final it in items) {
        final pid = it.productoId ?? '';
        if (pid.isEmpty) continue;
        await agregar(
          Product(
            id: pid,
            nombre: it.nombre,
            precio: it.precioUnitario,
            imagenUrl: '',
            descripcion: '',
            categoria: '',
          ),
          it.cantidad,
          it.tamano ?? 'chico',
          it.precioUnitario,
        );
        agregados++;
      }
    }

    if (!_cerrado) {
      _reordenandoId = null;
      notifyListeners();
    }
    if (items.isEmpty) return ResultadoReorden.sinProductos;
    if (agregados == 0) return ResultadoReorden.ningunoAgregado;
    return ResultadoReorden.agregado;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
