// lib/data/repositories/publicaciones_repository_remote.dart
//
// Implementación HTTP de PublicacionesRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository.dart';
import 'package:pier_reposteria/data/repositories/respuesta_api.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';

/// Implementación de [PublicacionesRepository] contra el backend vía
/// [ApiClient].
class PublicacionesRepositoryRemote implements PublicacionesRepository {
  PublicacionesRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<PaginaFeed> feed({CursorFeed? despues}) async {
    final r = exigirExito(
      await _api.getAuth(
        ApiConstants.publicacionesFeed(
          antes: despues?.antes,
          antesId: despues?.antesId,
        ),
      ),
      'No se pudieron cargar las publicaciones',
    );
    return paginaFeedDe(r);
  }

  @override
  Future<List<PromocionFeed>> promociones() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.publicacionesPromociones),
      'No se pudieron cargar las promociones',
    );
    final lista = r['promociones'];
    return lista is List
        ? lista
              .whereType<Map<dynamic, dynamic>>()
              .map((j) => PromocionFeed.fromJson(Map<String, dynamic>.from(j)))
              .toList()
        : const [];
  }

  @override
  Future<PaginaSugerencias> sugerencias({required int pagina}) async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.publicacionesSugerencias(pagina)),
      'No se pudieron cargar las sugerencias',
    );
    return paginaSugerenciasDe(r);
  }

  @override
  Future<ReaccionPublicacion> meEncanta(int id, {required bool poner}) async {
    final endpoint = ApiConstants.publicacionCorazon(id);
    final r = _exigir(
      await (poner ? _api.putAuth(endpoint, {}) : _api.deleteAuth(endpoint)),
      'No se pudo guardar tu reacción',
    );
    return (
      meEncanta: r['me_encanta'] == true,
      corazones: (r['corazones'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<PaginaComentarios> comentarios(int id, {int? despuesId}) async {
    final r = _exigir(
      await _api.getAuth(
        ApiConstants.publicacionComentarios(id, despuesId: despuesId),
      ),
      'No se pudieron cargar los comentarios',
    );
    return paginaComentariosDe(r);
  }

  @override
  Future<ComentarioPublicacion> comentar(int id, String texto) async {
    final r = _exigir(
      await _api.postAuth(ApiConstants.publicacionComentar(id), {
        'texto': texto,
      }),
      'No se pudo publicar tu comentario',
    );
    final c = r['comentario'];
    if (c is! Map) {
      throw const ApiException('No se pudo publicar tu comentario');
    }
    return ComentarioPublicacion.fromJson(Map<String, dynamic>.from(c));
  }

  @override
  Future<void> borrarComentario(int comentarioId) async {
    _exigir(
      await _api.deleteAuth(ApiConstants.comentarioPublicacion(comentarioId)),
      'No se pudo eliminar el comentario',
    );
  }

  /// Como [exigirExito], pero el 404 de una publicación eliminada se vuelve
  /// PublicacionNoDisponibleException (la vista la quita del inicio).
  static Map<String, dynamic> _exigir(
    Map<String, dynamic> respuesta,
    String porDefecto,
  ) {
    if (respuesta['success'] != true &&
        respuesta['message'] == _publicacionNoEncontrada) {
      throw const PublicacionNoDisponibleException(
        'Esta publicación ya no está disponible',
      );
    }
    return exigirExito(respuesta, porDefecto);
  }

  static const _publicacionNoEncontrada = 'Publicación no encontrada';
}
