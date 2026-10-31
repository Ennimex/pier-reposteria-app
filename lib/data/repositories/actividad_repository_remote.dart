// lib/data/repositories/actividad_repository_remote.dart
//
// Implementación HTTP de ActividadRepository (#139). Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository.dart';
import 'package:pier_reposteria/data/repositories/respuesta_api.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';

class ActividadRepositoryRemote implements ActividadRepository {
  ActividadRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<ActividadEquipo> actividadEquipo() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.actividadEquipo),
      'No se pudo cargar la actividad del equipo. Intenta de nuevo.',
    );
    return ActividadEquipo.fromJson(r);
  }

  @override
  Future<PaginaBitacora> bitacora(
    FiltrosBitacora filtros, {
    int? antesDeId,
  }) async {
    final r = exigirExito(
      await _api.getAuth(
        ApiConstants.auditoriaFiltrada(
          limite: ActividadRepository.porPagina,
          entidad: filtros.entidad,
          usuarioId: filtros.usuarioId,
          desde: _dia(filtros.desde),
          hasta: _dia(filtros.hasta),
          antesDeId: antesDeId,
        ),
      ),
      'No se pudo cargar la bitácora. Intenta de nuevo.',
    );
    return PaginaBitacora.fromJson(r);
  }

  /// El día como lo piden los filtros del backend: «2026-10-05».
  static String? _dia(DateTime? dia) {
    if (dia == null) return null;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dia.year}-${dos(dia.month)}-${dos(dia.day)}';
  }
}
