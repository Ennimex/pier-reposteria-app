// lib/data/repositories/productos_repository_remote.dart
//
// Implementación HTTP de ProductosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/category_model.dart';
import 'package:pier_pasteleria/domain/models/detalle_producto.dart';
import 'package:pier_pasteleria/domain/models/filtros_catalogo.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

/// Implementación de [ProductosRepository] contra el backend vía [ApiClient].
class ProductosRepositoryRemote implements ProductosRepository {
  ProductosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> listar() => _api.get(ApiConstants.productos);

  @override
  Future<Map<String, dynamic>> detalle(String id) => _api.get(ApiConstants.productoById(id));

  @override
  Future<Map<String, dynamic>> categorias() => _api.get(ApiConstants.categorias);

  @override
  Future<List<String>> nombresDeCategorias() async {
    final r = await categorias();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las categorías',
      );
    }
    final data = r['categorias'] ?? r['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((c) => (c['nombre'] ?? c['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Categoria>> listarCategorias() async {
    final r = await categorias();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las categorías',
      );
    }
    final data = r['categorias'] ?? r['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map(Categoria.fromJson)
        .toList();
  }

  @override
  Future<FiltrosCatalogo> filtrosDelCatalogo() async {
    final r = await _api.get(ApiConstants.filtros);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar los filtros',
      );
    }
    final filtros = r['filtros'];
    return filtros is Map
        ? FiltrosCatalogo.fromFiltros(filtros)
        : const FiltrosCatalogo();
  }

  @override
  Future<FiltrosCatalogo> opcionesDeLaCategoria(String categoriaId) async {
    final r = await _api.get(ApiConstants.categoriaOpciones(categoriaId));
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ??
            'No se pudieron cargar las opciones de la categoría',
      );
    }
    return FiltrosCatalogo.fromOpcionesCategoria(r);
  }

  @override
  Future<DetalleProducto> detalleDelProducto(String id) async {
    final r = await detalle(id);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudo cargar el producto',
      );
    }
    return DetalleProducto.fromJson(r);
  }

  @override
  Future<Map<String, dynamic>> recomendaciones(String productoId) =>
      _api.get(ApiConstants.recomendaciones(productoId));

  @override
  Future<List<Product>> recomendacionesDe(String productoId) async {
    final r = await recomendaciones(productoId);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Sin recomendaciones',
      );
    }
    final data = r['recomendaciones'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> promocionesActivas() => _api.get(ApiConstants.promocionesActivas);
}
