// lib/data/repositories/atencion_clientes_repository_remote.dart
//
// Implementación HTTP de AtencionClientesRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository.dart';
import 'package:pier_reposteria/data/repositories/respuesta_api.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';

class AtencionClientesRepositoryRemote implements AtencionClientesRepository {
  AtencionClientesRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<QuejaPersonal>> quejas() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.quejasPersonal),
      'No se pudieron cargar las quejas y sugerencias.',
    );
    return [
      if (r['quejas'] case final List lista)
        for (final q in lista) ?QuejaPersonal.fromJson(q),
    ];
  }

  @override
  Future<String> atenderQueja(
    String id, {
    required String estado,
    String? respuesta,
  }) =>
      _mensaje(
        _api.putAuth(ApiConstants.atenderQueja(id), {
          'estado': estado,
          'respuesta': ?respuesta,
        }),
        'No se pudo guardar el ticket. Intenta de nuevo.',
        'Queja actualizada',
      );

  @override
  Future<List<ReembolsoPersonal>> reembolsos() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.reembolsosPersonal),
      'No se pudieron cargar las solicitudes de reembolso.',
    );
    return [
      if (r['reembolsos'] case final List lista)
        for (final x in lista) ?ReembolsoPersonal.fromJson(x),
    ];
  }

  @override
  Future<String> resolverReembolso(
    String id, {
    required String estado,
    String? respuestaAdmin,
    String? justificacionRechazo,
  }) =>
      _mensaje(
        _api.putAuth(ApiConstants.resolverReembolso(id), {
          'estado': estado,
          'respuesta_admin': ?respuestaAdmin,
          'justificacion_rechazo': ?justificacionRechazo,
        }),
        'No se pudo guardar el cambio. Intenta de nuevo.',
        'Reembolso actualizado',
      );

  @override
  Future<List<ResenaPersonal>> resenas() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.resenasPersonal),
      'No se pudieron cargar las reseñas.',
    );
    return [
      if (r['resenas'] case final List lista)
        for (final x in lista) ?ResenaPersonal.fromJson(x),
    ];
  }

  @override
  Future<String> moderarResena(
    String id, {
    String? estado,
    String? motivoRechazo,
    String? respuestaNegocio,
  }) =>
      _mensaje(
        _api.putAuth(ApiConstants.moderarResena(id), {
          'estado': ?estado,
          'motivo_rechazo': ?motivoRechazo,
          'respuesta_negocio': ?respuestaNegocio,
        }),
        'No se pudo guardar la reseña. Intenta de nuevo.',
        'Reseña actualizada',
      );

  /// El `message` del backend si salió bien; si no, ApiException.
  static Future<String> _mensaje(
    Future<Map<String, dynamic>> llamada,
    String error,
    String exito,
  ) async {
    final r = exigirExito(await llamada, error);
    return r['message']?.toString() ?? exito;
  }
}
