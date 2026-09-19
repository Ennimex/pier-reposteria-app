// lib/ui/core/state/product_provider.dart
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';

class ProductProvider with ChangeNotifier {
  final ProductosRepository _repo;

  ProductProvider({ProductosRepository? repo})
      : _repo = repo ?? ProductosRepository();

  List<Product> _productos = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ✅ NUEVO: mapa productoId → promocion activa
  Map<String, Map<String, dynamic>> _promociones = {};

  List<Product> get productos => _productos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Product> get populares =>
      _productos.where((p) => p.popular && p.disponible).toList();

  List<Product> get recientes =>
      _productos.where((p) => p.disponible).take(6).toList();

  List<Product> get mejorCalificados {
    final lista = _productos
        .where((p) => p.disponible && p.rating > 0)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return lista.take(8).toList();
  }

  List<Product> get nuevos =>
      _productos.where((p) => p.disponible && p.esNuevo).take(8).toList();

  List<Product> byCategoria(String categoria) {
    if (categoria == 'Todos') {
      return _productos.where((p) => p.disponible).toList();
    }
    return _productos
        .where((p) => p.categoria == categoria && p.disponible)
        .toList();
  }

  // ✅ NUEVO: obtener promoción activa para un producto (null si no tiene)
  Map<String, dynamic>? promocionDeProducto(String productoId) =>
      _promociones[productoId];

  // Precio con descuento para un tamaño dado.
  // IMPORTANTE: el backend SOLO cobra descuentos por porcentaje
  // (descuento_porcentaje) y los redondea a entero. `precio_oferta` (precio
  // fijo) NO se cobra, así que la app tampoco lo muestra como descuento para
  // que el precio mostrado == precio cobrado. El porcentaje se aplica sobre el
  // precio del tamaño (chico/grande) y se redondea igual que el backend.
  double precioConDescuento(String productoId, double precioBase) {
    final porcentaje = _porcentajeDe(productoId);
    if (porcentaje <= 0) return precioBase;
    return (precioBase * (1 - porcentaje / 100)).roundToDouble();
  }

  // ¿Tiene un descuento efectivo (por porcentaje) que el backend sí cobra?
  bool tieneDescuento(String productoId) => _porcentajeDe(productoId) > 0;

  double _porcentajeDe(String productoId) {
    final promo = _promociones[productoId];
    if (promo == null) return 0;
    return double.tryParse(
            promo['descuento_porcentaje']?.toString() ?? '0') ??
        0;
  }

  Future<void> cargarProductos() async {
    if (_productos.isNotEmpty) return;
    PierLog.info('📦 Iniciando carga de productos desde backend...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Cargar productos y promociones en paralelo
    final results = await Future.wait([
      _repo.listar(),
      _repo.promocionesActivas(),
    ]);

    _isLoading = false;
    final resultProductos   = results[0];
    final resultPromociones = results[1];

    if (resultProductos['success'] == true) {
      final data = resultProductos['productos'] ?? resultProductos['data'] ?? [];
      _productos = (data as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
      PierLog.info('✅ Productos cargados: ${_productos.length}');
    } else {
      _errorMessage = resultProductos['message'] ?? 'Error al cargar productos';
      PierLog.error(_errorMessage!);
    }

    // Mapear promociones por producto_id
    if (resultPromociones['success'] == true) {
      final promos = List<Map<String, dynamic>>.from(
          resultPromociones['promociones'] ?? []);
      _promociones = {};
      for (final p in promos) {
        final productoId = p['producto_id']?.toString();
        if (productoId != null && productoId.isNotEmpty) {
          _promociones[productoId] = p;
        }
      }
      PierLog.info('🎉 Promociones activas cargadas: ${_promociones.length}');
    } else {
      PierLog.debug('Sin promociones activas o error al cargar');
    }

    notifyListeners();
  }

  Future<void> refrescar() async {
    PierLog.info('🔄 Refrescando productos y promociones...');
    _productos = [];
    _promociones = {};
    await cargarProductos();
  }

  Future<Map<String, dynamic>?> cargarDetalle(String id) async {
    final result = await _repo.detalle(id);
    if (result['success'] == true) {
      PierLog.info('✅ Detalle del producto $id cargado');
      return result;
    }
    PierLog.error('Error al cargar detalle del producto $id');
    return null;
  }
}