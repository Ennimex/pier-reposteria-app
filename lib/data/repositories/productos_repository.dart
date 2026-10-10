// lib/data/repositories/productos_repository.dart
//
// Única puerta a los datos de el catálogo (productos, categorías, filtros, promociones). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es ProductosRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 4: el catálogo usa listarCategorias, filtrosDelCatalogo y
// opcionesDeLaCategoria, tipados y con ApiException si el backend falla.
import 'package:pier_pasteleria/domain/models/category_model.dart';
import 'package:pier_pasteleria/domain/models/filtros_catalogo.dart';

abstract class ProductosRepository {
  /// GET /productos: catálogo activo con precios y stock_online.
  Future<Map<String, dynamic>> listar();

  /// GET /productos/:id: detalle + reseñas aprobadas + relacionados.
  Future<Map<String, dynamic>> detalle(String id);

  /// GET /categorias
  Future<Map<String, dynamic>> categorias();

  /// GET /categorias tipado a solo los nombres (`nombre` o `name`), en el
  /// orden del backend; ignora los vacíos y lo que no sea objeto. Lanza
  /// ApiException si falla. categorias() crudo sigue para el home.
  Future<List<String>> nombresDeCategorias();

  /// GET /categorias tipado: id y nombre, en el orden del backend; ignora
  /// lo que no sea objeto. Lanza ApiException si falla.
  Future<List<Categoria>> listarCategorias();

  /// GET /filtros: sabores, tamaños y tipos globales (vacíos si no viene
  /// `filtros`). Lanza ApiException si falla.
  Future<FiltrosCatalogo> filtrosDelCatalogo();

  /// GET /categoria-opciones/:id: sabores y tipos propios de una categoría
  /// (sin tamaños). Lanza ApiException si falla.
  Future<FiltrosCatalogo> opcionesDeLaCategoria(String categoriaId);

  /// GET /recomendaciones/:productoId: top 3 por co-compra (público).
  Future<Map<String, dynamic>> recomendaciones(String productoId);

  /// GET /promociones/activas
  Future<Map<String, dynamic>> promocionesActivas();
}
