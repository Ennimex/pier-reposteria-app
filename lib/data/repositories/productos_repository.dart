// lib/data/repositories/productos_repository.dart
//
// Única puerta a los datos de el catálogo (productos, categorías, filtros, promociones). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es ProductosRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class ProductosRepository {
  /// GET /productos: catálogo activo con precios y stock_online.
  Future<Map<String, dynamic>> listar();

  /// GET /productos/:id: detalle + reseñas aprobadas + relacionados.
  Future<Map<String, dynamic>> detalle(String id);

  /// GET /categorias
  Future<Map<String, dynamic>> categorias();

  /// GET /categorias tipado a solo los nombres (`nombre` o `name`), en el
  /// orden del backend; ignora los vacíos y lo que no sea objeto. Lanza
  /// ApiException si falla. categorias() crudo sigue para home y catálogo.
  Future<List<String>> nombresDeCategorias();

  /// GET /filtros: sabores/tamaños/tipos globales.
  Future<Map<String, dynamic>> filtros();

  /// GET /categoria-opciones/:id: tipos y sabores de una categoría.
  Future<Map<String, dynamic>> opcionesDeCategoria(String categoriaId);

  /// GET /recomendaciones/:productoId: top 3 por co-compra (público).
  Future<Map<String, dynamic>> recomendaciones(String productoId);

  /// GET /promociones/activas
  Future<Map<String, dynamic>> promocionesActivas();
}
