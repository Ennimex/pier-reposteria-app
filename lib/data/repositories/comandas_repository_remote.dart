// lib/data/repositories/comandas_repository_remote.dart
//
// Implementación HTTP de ComandasRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository.dart';
import 'package:pier_reposteria/data/repositories/respuesta_api.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/comanda.dart';

/// Implementación de [ComandasRepository] contra el backend vía [ApiClient].
class ComandasRepositoryRemote implements ComandasRepository {
  ComandasRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<AgendaComandas> agenda({
    VistaAgenda vista = VistaAgenda.proximas,
    String busqueda = '',
  }) async {
    final r = await _exigir(
      _api.getAuth(
        ApiConstants.agendaComandas(vista.name, busqueda: busqueda.trim()),
      ),
      'No se pudieron cargar las comandas',
    );
    return AgendaComandas.fromJson(r);
  }

  @override
  Future<DetalleComanda> detalle(int id) async {
    final r = await _exigir(
      _api.getAuth(ApiConstants.comandaDetalle(id)),
      'No se pudo abrir la comanda',
    );
    return DetalleComanda.fromJson(r);
  }

  @override
  Future<String> confirmar(int id, {required int version}) async {
    final r = await _exigir(
      _api.postAuth(ApiConstants.comandaConfirmar(id), {'version': version}),
      'No se pudo registrar el enterado',
    );
    return r['message']?.toString() ?? 'Enterado registrado';
  }

  @override
  Future<EntregaComanda> entregar(
    int id, {
    required double saldoCobrado,
  }) async {
    final r = await _exigir(
      _api.putAuth(ApiConstants.comandaEntregar(id), {
        'saldo_cobrado': saldoCobrado,
      }),
      'No se pudo marcar como entregada',
    );
    final advertencias = r['advertencias'];
    return (
      mensaje: r['message']?.toString() ?? 'Comanda entregada',
      advertencias: advertencias is List
          ? advertencias.map((a) => a.toString()).toList()
          : const <String>[],
    );
  }

  @override
  Future<String> cancelar(int id, {required String motivo}) async {
    final r = await _exigir(
      _api.putAuth(ApiConstants.comandaCancelar(id), {'motivo': motivo}),
      'No se pudo cancelar la comanda',
    );
    return r['message']?.toString() ?? 'Comanda cancelada';
  }

  /// La respuesta si trae success: true; si no, SesionInvalidaException
  /// (cuenta desactivada o cambiada), ConflictoComandaException (409 del
  /// «Enterado») o ApiException con su mensaje (o [porDefecto]).
  static Future<Map<String, dynamic>> _exigir(
    Future<Map<String, dynamic>> llamada,
    String porDefecto,
  ) async {
    final r = await llamada;
    final mensaje = r['message']?.toString() ?? porDefecto;
    switch (r['codigo']) {
      case 'VERSION_DESACTUALIZADA':
        throw ConflictoComandaException(
          mensaje,
          cambio: true,
          versionActual: (r['version_actual'] as num?)?.toInt(),
        );
      case 'YA_CONFIRMADA':
        throw ConflictoComandaException(mensaje, cambio: false);
    }
    return exigirExito(r, porDefecto);
  }
}
