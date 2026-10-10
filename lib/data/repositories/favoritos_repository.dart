// lib/data/repositories/favoritos_repository.dart
//
// Única puerta a los datos de favoritos del cliente. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es FavoritosRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: los métodos tipados (listarIds, listarProductos, quitarFavorito) lanzan ApiException si el
// backend falla; los crudos siguen para las pantallas aún sin ViewModel.
import 'package:pier_pasteleria/domain/models/product_model.dart';

abstract class FavoritosRepository {
  /// GET /favoritos/ids: solo ids (para pintar corazones).
  Future<Map<String, dynamic>> ids();

  /// GET /favoritos/ids tipado (p. ej. para contarlos en «Más»). ids() crudo
  /// se queda para el catálogo y el detalle.
  Future<List<String>> listarIds();

  /// GET /favoritos: productos completos.
  Future<Map<String, dynamic>> listar();

  /// GET /favoritos tipado. Acepta la lista en `favoritos` o `data`; ignora
  /// elementos que no sean objetos. Se marcan disponibles (`activo`: el
  /// backend no manda el campo en este listado).
  Future<List<Product>> listarProductos();

  /// POST /favoritos/:id
  Future<Map<String, dynamic>> agregar(String productoId);

  /// DELETE /favoritos/:id
  Future<Map<String, dynamic>> quitar(String productoId);

  /// DELETE /favoritos/:id tipado: lanza ApiException si no se quitó.
  /// quitar() crudo se queda para el detalle (aún sin ViewModel).
  Future<void> quitarFavorito(String productoId);

  /// POST /favoritos/:id tipado: lanza ApiException con el mensaje del backend
  /// si no se pudo agregar. agregar() crudo se queda para el detalle.
  Future<void> agregarFavorito(String productoId);
}
