// lib/data/repositories/favoritos_repository_remote.dart
//
// Implementación HTTP de FavoritosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'dart:async';

import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';

/// Implementación de [FavoritosRepository] contra el backend vía [ApiClient].
class FavoritosRepositoryRemote implements FavoritosRepository {
  FavoritosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;
  // Síncrono: el aviso llega antes de que termine quien agregó o quitó. Si
  // llegara después, el «agregado» de un corazón que se quitó enseguida lo
  // volvería a llenar.
  final StreamController<CambioFavorito> _cambios =
      StreamController<CambioFavorito>.broadcast(sync: true);

  @override
  Stream<CambioFavorito> get cambios => _cambios.stream;

  @override
  Future<Map<String, dynamic>> ids() => _api.getAuth(ApiConstants.favoritosIds);

  @override
  Future<List<String>> listarIds() async {
    final r = await ids();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus favoritos',
      );
    }
    final data = r['ids'];
    if (data is! List) return const [];
    return data.map((id) => id.toString()).toList();
  }

  @override
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.favoritos);

  @override
  Future<List<Product>> listarProductos() async {
    final r = await listar();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus favoritos',
      );
    }
    final data = r['favoritos'] ?? r['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Product.fromJson({...Map<String, dynamic>.from(j), 'activo': true}))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> agregar(String productoId) async {
    final r = await _api.postAuth(ApiConstants.favoritoById(productoId), {});
    _avisarSiSeAcepto(r, productoId, favorito: true);
    return r;
  }

  @override
  Future<Map<String, dynamic>> quitar(String productoId) async {
    final r = await _api.deleteAuth(ApiConstants.favoritoById(productoId));
    _avisarSiSeAcepto(r, productoId, favorito: false);
    return r;
  }

  void _avisarSiSeAcepto(
    Map<String, dynamic> r,
    String productoId, {
    required bool favorito,
  }) {
    if (r['success'] == true) {
      _cambios.add((productoId: productoId, favorito: favorito));
    }
  }

  @override
  Future<void> quitarFavorito(String productoId) async {
    final r = await quitar(productoId);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al quitar de favoritos',
      );
    }
  }

  @override
  Future<void> agregarFavorito(String productoId) async {
    final r = await agregar(productoId);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al actualizar favorito',
      );
    }
  }
}
