// lib/data/repositories/publicaciones_repository_remote.dart
//
// Implementación HTTP de PublicacionesRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/publicaciones_repository.dart';
import 'package:pier_pasteleria/data/repositories/respuesta_api.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/publicacion.dart';

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
}
