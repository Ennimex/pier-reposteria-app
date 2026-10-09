// lib/ui/favorites/view_model/favorites_view_model.dart
//
// Estado de «Mis Favoritos» (MVVM, Fase 3): la lista, la búsqueda local, las
// categorías sugeridas del estado vacío, quitar un favorito (optimista) y
// «Avísame» de los agotados. Si el backend falla la lista se queda como
// estaba (la pantalla no muestra error, como antes). El carrito y la sesión
// no se tocan desde aquí: la vista decide si agrega o manda a iniciar sesión.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/services/demanda_service.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

/// Registra el interés en un producto agotado (demanda no atendida).
typedef RegistrarInteres = void Function(String productoId);

class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel({
    required FavoritosRepository favoritosRepo,
    required ProductosRepository productosRepo,
    RegistrarInteres? registrarInteres,
  })  : _favoritosRepo = favoritosRepo,
        _productosRepo = productosRepo,
        _registrarInteres =
            registrarInteres ?? DemandaService.registrarClicAgotado;

  /// Categorías del estado vacío si el backend no manda ninguna.
  static const List<String> categoriasDeRespaldo = [
    'Pasteles',
    'Roscas',
    'Pays',
    'Cafetería',
  ];

  final FavoritosRepository _favoritosRepo;
  final ProductosRepository _productosRepo;
  final RegistrarInteres _registrarInteres;
  bool _cerrado = false;

  List<Product> _favoritos = const [];
  List<String> _categorias = const [];
  String _busqueda = '';
  bool _cargando = true;

  List<Product> get favoritos => _favoritos;
  bool get cargando => _cargando;
  String get busqueda => _busqueda;

  /// Favoritos que coinciden con la búsqueda (nombre o categoría).
  List<Product> get filtrados {
    if (_busqueda.isEmpty) return _favoritos;
    final q = _busqueda.toLowerCase();
    return _favoritos
        .where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            p.categoria.toLowerCase().contains(q))
        .toList();
  }

  /// Hasta 4 categorías para «Explora por categoría».
  List<String> get categoriasSugeridas => _categorias.isNotEmpty
      ? _categorias.take(4).toList()
      : categoriasDeRespaldo;

  /// Carga favoritos y categorías a la vez.
  Future<void> cargar() =>
      Future.wait([cargarFavoritos(), _cargarCategorias()]);

  /// Vuelve a pedir la lista (también al regresar del detalle, donde el
  /// cliente pudo quitar el corazón).
  Future<void> cargarFavoritos() async {
    _cargando = true;
    notifyListeners();
    try {
      _favoritos = await _favoritosRepo.listarProductos();
    } on ApiException {
      // Se queda la lista anterior.
    }
    if (_cerrado) return;
    _cargando = false;
    notifyListeners();
  }

  Future<void> _cargarCategorias() async {
    try {
      _categorias = await _productosRepo.nombresDeCategorias();
    } on ApiException {
      // Se usan las de respaldo.
    }
    if (_cerrado) return;
    notifyListeners();
  }

  void buscar(String texto) {
    _busqueda = texto;
    notifyListeners();
  }

  /// Quita [producto] al instante y lo confirma con el backend; si falla lo
  /// regresa a su lugar y devuelve false.
  Future<bool> quitar(Product producto) async {
    final indice = _favoritos.indexOf(producto);
    if (indice == -1) return true;
    _favoritos = [..._favoritos]..removeAt(indice);
    notifyListeners();
    try {
      await _favoritosRepo.quitarFavorito(producto.id);
      return true;
    } on ApiException {
      if (!_cerrado) {
        final lista = [..._favoritos];
        lista.insert(indice.clamp(0, lista.length), producto);
        _favoritos = lista;
        notifyListeners();
      }
      return false;
    }
  }

  /// «Avísame»: registra el interés en un agotado (no bloquea ni falla).
  void avisarme(Product producto) => _registrarInteres(producto.id);

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
