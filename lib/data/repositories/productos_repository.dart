// lib/data/repositories/productos_repository.dart
//
// Única puerta a los datos de el catálogo (productos, categorías, filtros, promociones). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class ProductosRepository {
  final ApiClient _api;
  ProductosRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /productos: catálogo activo con precios y stock_online.
  Future<Map<String, dynamic>> listar() => _api.get(ApiConstants.productos);

  /// GET /productos/:id: detalle + reseñas aprobadas + relacionados.
  Future<Map<String, dynamic>> detalle(String id) => _api.get(ApiConstants.productoById(id));

  /// GET /categorias
  Future<Map<String, dynamic>> categorias() => _api.get(ApiConstants.categorias);

  /// GET /filtros: sabores/tamaños/tipos globales.
  Future<Map<String, dynamic>> filtros() => _api.get(ApiConstants.filtros);

  /// GET /categoria-opciones/:id: tipos y sabores de una categoría.
  Future<Map<String, dynamic>> opcionesDeCategoria(String categoriaId) =>
      _api.get(ApiConstants.categoriaOpciones(categoriaId));

  /// GET /recomendaciones/:productoId: top 3 por co-compra (público).
  Future<Map<String, dynamic>> recomendaciones(String productoId) =>
      _api.get(ApiConstants.recomendaciones(productoId));

  /// GET /promociones/activas
  Future<Map<String, dynamic>> promocionesActivas() => _api.get(ApiConstants.promocionesActivas);
}
