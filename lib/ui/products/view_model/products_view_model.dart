// lib/ui/products/view_model/products_view_model.dart
//
// Estado del catálogo (MVVM, Fase 4): categoría elegida, búsqueda, orden,
// filtros de sabor/tamaño/tipo (globales o propios de la categoría),
// corazones de favoritos (optimistas) y el registro de demanda no atendida
// (búsquedas y "Avísame"). Los filtros se aplican en local sobre el catálogo
// que ya cargó ProductProvider (mismo comportamiento que antes de MVVM).
//
// La sesión, el carrito y la navegación no se tocan desde aquí: la vista
// decide si manda a iniciar sesión y avisa cuando cambia la sesión.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/domain/models/category_model.dart';
import 'package:pier_pasteleria/domain/models/filtros_catalogo.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// Criterios de orden del catálogo.
enum SortOption { popular, priceAsc, priceDesc, nameAsc, nameDesc }

class ProductsViewModel extends ChangeNotifier {
  ProductsViewModel({
    required ProductosRepository productosRepo,
    required FavoritosRepository favoritosRepo,
    required DemandaRepository demandaRepo,
    required List<Product> Function() catalogo,
    String categoriaInicial = todas,
    this.esperaRegistroBusqueda = const Duration(milliseconds: 1200),
  })  : _productosRepo = productosRepo,
        _favoritosRepo = favoritosRepo,
        _demandaRepo = demandaRepo,
        _catalogo = catalogo,
        _categoria = categoriaInicial;

  /// Categoría que muestra todo el catálogo.
  static const String todas = 'Todos';

  /// Chips de categoría mientras el backend no manda las suyas.
  static const List<String> categoriasDeRespaldo = [
    todas,
    'Pasteles',
    'Roscas',
    'Pays',
    'Postres',
    'Cafetería',
  ];

  /// Cuánto se espera tras la última tecla para registrar la búsqueda.
  final Duration esperaRegistroBusqueda;

  final ProductosRepository _productosRepo;
  final FavoritosRepository _favoritosRepo;
  final DemandaRepository _demandaRepo;
  final List<Product> Function() _catalogo;
  bool _cerrado = false;
  Timer? _registroBusqueda;

  String _categoria;
  String _busqueda = '';
  SortOption _orden = SortOption.popular;
  List<Categoria> _categorias = const [];
  FiltrosCatalogo _filtrosGlobales = const FiltrosCatalogo();
  bool _filtrosCargados = false;
  // Opciones de la categoría elegida; vacías = se usa el set global.
  FiltrosCatalogo _opcionesCategoria = const FiltrosCatalogo();
  String? _filtroSabor;
  String? _filtroTamano;
  String? _filtroTipo;
  final Set<String> _favoritos = {};

  String get categoria => _categoria;
  String get busqueda => _busqueda;
  SortOption get orden => _orden;
  bool get filtrosCargados => _filtrosCargados;
  String? get filtroSabor => _filtroSabor;
  String? get filtroTamano => _filtroTamano;
  String? get filtroTipo => _filtroTipo;

  /// 'Todos' y las categorías del backend, o las de respaldo si no hay.
  List<String> get nombresCategorias => _categorias.isEmpty
      ? categoriasDeRespaldo
      : [todas, ..._categorias.map((c) => c.nombre)];

  /// Sabores de la categoría elegida si tiene propios; si no, los globales.
  List<String> get sabores =>
      (_categoria != todas && _opcionesCategoria.sabores.isNotEmpty)
          ? _opcionesCategoria.sabores
          : _filtrosGlobales.sabores;

  List<String> get tamanos => _filtrosGlobales.tamanos;

  /// Tipos de la categoría elegida si tiene propios; si no, los globales.
  List<String> get tipos =>
      (_categoria != todas && _opcionesCategoria.tipos.isNotEmpty)
          ? _opcionesCategoria.tipos
          : _filtrosGlobales.tipos;

  /// ¿Hay algún filtro de sabor, tamaño o tipo puesto?
  bool get hayFiltrosDeOpciones =>
      _filtroSabor != null || _filtroTamano != null || _filtroTipo != null;

  /// ¿Hay algo que "Quitar filtros" pueda limpiar?
  bool get hayFiltros =>
      _busqueda.isNotEmpty || _categoria != todas || hayFiltrosDeOpciones;

  bool esFavorito(String productoId) => _favoritos.contains(productoId);

  // ── Carga ────────────────────────────────────────────────────────────────

  /// Carga categorías, filtros y favoritos a la vez.
  Future<void> cargar({required bool autenticado}) => Future.wait([
        cargarCategorias(),
        cargarFiltros(),
        cargarFavoritos(autenticado: autenticado),
      ]);

  Future<void> cargarCategorias() async {
    try {
      final lista = await _productosRepo.listarCategorias();
      if (_cerrado || lista.isEmpty) return;
      PierLog.info('✅ Categorías cargadas: ${lista.length}');
      _categorias = lista;
      notifyListeners();
      // Con los ids ya disponibles, cargar opciones si se entró con una
      // categoría preseleccionada (p. ej. desde el home).
      if (_categoria != todas) await _cargarOpcionesCategoria();
    } on ApiException catch (e) {
      PierLog.error('Error al cargar categorías: ${e.message}');
    }
  }

  Future<void> cargarFiltros() async {
    try {
      final filtros = await _productosRepo.filtrosDelCatalogo();
      if (_cerrado) return;
      _filtrosGlobales = filtros;
      _filtrosCargados = true;
      notifyListeners();
      PierLog.info('✅ Filtros cargados — sabores:${filtros.sabores.length} '
          'tamaños:${filtros.tamanos.length} tipos:${filtros.tipos.length}');
    } on ApiException catch (e) {
      PierLog.error('Error al cargar filtros: ${e.message}');
    }
  }

  /// Corazones del cliente. Sin sesión se limpian (la pestaña vive en el
  /// IndexedStack y conservaría los del usuario anterior).
  Future<void> cargarFavoritos({required bool autenticado}) async {
    if (!autenticado) {
      if (_favoritos.isNotEmpty) {
        _favoritos.clear();
        notifyListeners();
      }
      return;
    }
    try {
      final ids = await _favoritosRepo.listarIds();
      if (_cerrado) return;
      _favoritos
        ..clear()
        ..addAll(ids);
      notifyListeners();
      PierLog.info('✅ Favoritos cargados: ${ids.length}');
    } on ApiException catch (e) {
      PierLog.error('Error al cargar favoritos: ${e.message}');
    }
  }

  /// Sabores/tipos propios de la categoría elegida. Si no tiene (o falla la
  /// llamada) se queda el set global.
  Future<void> _cargarOpcionesCategoria() async {
    final solicitada = _categoria;
    if (solicitada == todas) {
      _opcionesCategoria = const FiltrosCatalogo();
      notifyListeners();
      return;
    }
    final id = _categorias
        .where((c) => c.nombre == solicitada)
        .map((c) => c.id)
        .firstOrNull;
    if (id == null || id.isEmpty) return;
    try {
      final opciones = await _productosRepo.opcionesDeLaCategoria(id);
      // Si el cliente ya cambió de categoría, se descarta esta respuesta.
      if (_cerrado || _categoria != solicitada) return;
      _opcionesCategoria = opciones;
      // Filtros puestos que ya no existen en esta categoría se limpian.
      if (_filtroSabor != null && !sabores.contains(_filtroSabor)) {
        _filtroSabor = null;
      }
      if (_filtroTipo != null && !tipos.contains(_filtroTipo)) {
        _filtroTipo = null;
      }
      notifyListeners();
      PierLog.info('✅ Opciones de "$solicitada" — '
          'sabores:${opciones.sabores.length} tipos:${opciones.tipos.length}');
    } on ApiException {
      // Se queda el set global.
    }
  }

  // ── Acciones del cliente ─────────────────────────────────────────────────

  Future<void> seleccionarCategoria(String nombre) {
    _categoria = nombre;
    notifyListeners();
    return _cargarOpcionesCategoria();
  }

  /// Filtra al instante y registra el término (con cuántos resultados dio)
  /// [esperaRegistroBusqueda] después de la última tecla, como la web.
  void buscar(String texto) {
    _busqueda = texto;
    notifyListeners();
    _registroBusqueda?.cancel();
    final termino = texto.trim();
    if (termino.length < 2) return;
    _registroBusqueda = Timer(esperaRegistroBusqueda, () {
      if (_cerrado || _busqueda.trim() != termino) return;
      _demandaRepo.registrarBusqueda(termino, filtrar(_catalogo()).length);
    });
  }

  void limpiarBusqueda() {
    _registroBusqueda?.cancel();
    _busqueda = '';
    notifyListeners();
  }

  void ordenarPor(SortOption orden) {
    _orden = orden;
    notifyListeners();
  }

  /// Pone el sabor, o lo quita si ya estaba puesto.
  void alternarSabor(String sabor) {
    _filtroSabor = _filtroSabor == sabor ? null : sabor;
    notifyListeners();
  }

  void alternarTamano(String tamano) {
    _filtroTamano = _filtroTamano == tamano ? null : tamano;
    notifyListeners();
  }

  void alternarTipo(String tipo) {
    _filtroTipo = _filtroTipo == tipo ? null : tipo;
    notifyListeners();
  }

  /// "Limpiar" de la hoja de filtros: solo sabor, tamaño y tipo.
  void limpiarFiltrosDeOpciones() {
    _filtroSabor = null;
    _filtroTamano = null;
    _filtroTipo = null;
    notifyListeners();
  }

  /// "Quitar filtros": búsqueda, categoría, orden y filtros.
  void limpiarTodo() {
    PierLog.debug('Filtros limpiados');
    _registroBusqueda?.cancel();
    _busqueda = '';
    _categoria = todas;
    _orden = SortOption.popular;
    _filtroSabor = null;
    _filtroTamano = null;
    _filtroTipo = null;
    _opcionesCategoria = const FiltrosCatalogo();
    notifyListeners();
  }

  /// Pone o quita el corazón al instante y lo confirma con el backend; si
  /// falla lo regresa y devuelve el mensaje de error (null = todo bien).
  Future<String?> alternarFavorito(String productoId) async {
    final yaEsFav = _favoritos.contains(productoId);
    _ponerFavorito(productoId, !yaEsFav);
    try {
      if (yaEsFav) {
        await _favoritosRepo.quitarFavorito(productoId);
      } else {
        await _favoritosRepo.agregarFavorito(productoId);
      }
      return null;
    } on ApiException catch (e) {
      PierLog.error(
          'Error al ${yaEsFav ? 'quitar' : 'agregar'} favorito $productoId');
      if (!_cerrado) _ponerFavorito(productoId, yaEsFav);
      return e.message;
    }
  }

  void _ponerFavorito(String productoId, bool favorito) {
    if (favorito) {
      _favoritos.add(productoId);
    } else {
      _favoritos.remove(productoId);
    }
    notifyListeners();
  }

  /// "Avísame": registra el interés en un agotado (no bloquea ni falla).
  void avisarme(Product producto) =>
      _demandaRepo.registrarClicAgotado(producto.id);

  // ── Filtrado local ───────────────────────────────────────────────────────

  /// Lo que se ve de [todos] con la categoría, búsqueda, filtros y orden
  /// actuales. Lo agotado siempre al final (como la web), conservando el
  /// orden elegido dentro de cada grupo.
  List<Product> filtrar(List<Product> todos) {
    var lista = _categoria == todas
        ? List<Product>.from(todos)
        : todos.where((p) => p.categoria == _categoria).toList();

    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista
          .where((p) =>
              p.nombre.toLowerCase().contains(q) ||
              p.descripcion.toLowerCase().contains(q) ||
              p.categoria.toLowerCase().contains(q))
          .toList();
    }
    if (_filtroSabor != null && _filtroSabor != todas) {
      lista = lista.where((p) => p.sabor == _filtroSabor).toList();
    }
    if (_filtroTamano != null && _filtroTamano != todas) {
      lista = lista.where((p) => p.tamano == _filtroTamano).toList();
    }
    if (_filtroTipo != null && _filtroTipo != todas) {
      lista = lista.where((p) => p.tipo == _filtroTipo).toList();
    }

    switch (_orden) {
      case SortOption.priceAsc:
        lista.sort((a, b) => a.precio.compareTo(b.precio));
      case SortOption.priceDesc:
        lista.sort((a, b) => b.precio.compareTo(a.precio));
      case SortOption.nameAsc:
        lista.sort((a, b) => a.nombre.compareTo(b.nombre));
      case SortOption.nameDesc:
        lista.sort((a, b) => b.nombre.compareTo(a.nombre));
      case SortOption.popular:
        lista.sort((a, b) {
          if (a.popular && !b.popular) return -1;
          if (!a.popular && b.popular) return 1;
          return 0;
        });
    }
    return [
      ...lista.where((p) => !p.agotado),
      ...lista.where((p) => p.agotado),
    ];
  }

  @override
  void dispose() {
    _cerrado = true;
    _registroBusqueda?.cancel();
    super.dispose();
  }
}
