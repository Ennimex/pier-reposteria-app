// lib/data/repositories/entregas_repository_remote.dart
//
// Implementación HTTP de EntregasRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/entregas_repository.dart';
import 'package:pier_reposteria/data/repositories/subir_imagen.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/entrega_model.dart';

/// Implementación de [EntregasRepository] contra el backend vía [ApiClient].
class EntregasRepositoryRemote implements EntregasRepository {
  EntregasRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<EntregaRepartidor>> misEntregas() async {
    final r = await _exigir(
      _api.getAuth(ApiConstants.misEntregas),
      'No se pudieron cargar tus entregas',
    );
    return _lista(r['entregas'], EntregaRepartidor.fromJson);
  }

  @override
  Future<bool> disponibilidad() async {
    final r = await _exigir(
      _api.getAuth(ApiConstants.disponibilidad),
      'No se pudo consultar tu disponibilidad',
    );
    return r['disponible'] == true;
  }

  @override
  Future<bool> cambiarDisponibilidad({required bool disponible}) async {
    final r = await _exigir(
      _api.putAuth(ApiConstants.disponibilidad, {'disponible': disponible}),
      'No se pudo cambiar la disponibilidad',
    );
    return r['disponible'] == true;
  }

  @override
  Future<List<PedidoDisponible>> disponibles() async {
    final r = await _exigir(
      _api.getAuth(ApiConstants.entregasDisponibles),
      'No se pudieron cargar los pedidos disponibles',
    );
    return _lista(r['pedidos'], PedidoDisponible.fromJson);
  }

  @override
  Future<String> aceptar(String pedidoId) async {
    final r = await _exigir(
      _api.postAuth(ApiConstants.entregasAceptar, {'pedido_id': pedidoId}),
      'No se pudo tomar el pedido',
    );
    return r['message']?.toString() ?? 'Pedido tomado';
  }

  @override
  Future<void> cambiarEstado(
    String entregaId,
    EstadoEntrega nuevo, {
    String? evidenciaUrl,
    String? recibioNombre,
    String? motivoFallo,
  }) =>
      _exigir(
        _api.putAuth(ApiConstants.entregaEstado(entregaId), {
          'estado': nuevo.apiValue,
          'evidencia_url': ?evidenciaUrl,
          'recibio_nombre': ?recibioNombre,
          'motivo_fallo': ?motivoFallo,
        }).then(_revisarYaEntregada),
        nuevo == EstadoEntrega.entregada
            ? 'No se pudo confirmar la entrega'
            : nuevo == EstadoEntrega.fallida
                ? 'No se pudo reportar'
                : 'No se pudo actualizar',
      );

  @override
  Future<String> avisarLlegada(String entregaId) async {
    final r = await _exigir(
      _api.postAuth(ApiConstants.entregaLlegue(entregaId), {}),
      'No se pudo avisar',
    );
    return r['message']?.toString() ?? 'Cliente avisado';
  }

  @override
  Future<String> subirEvidencia(String filePath) =>
      subirImagen(_api, filePath, tipo: 'entrega');

  /// Los elementos Map de [data] convertidos con [desdeJson]; nada si no es
  /// lista.
  static List<T> _lista<T>(
    dynamic data,
    T Function(Map<String, dynamic>) desdeJson,
  ) {
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => desdeJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// Confirmar una entrega que ya estaba entregada (otro teléfono, o un
  /// reintento con mala señal cuyo primer envío sí llegó) se vuelve
  /// EntregaYaConfirmadaException con un mensaje claro (#270); [r] sigue
  /// igual en cualquier otro caso. Es la única señal del backend: responde
  /// 400 (el mismo código que sus validaciones), sin un `codigo`, con el
  /// estado actual dentro del texto, y ApiClient no expone el código HTTP.
  static Map<String, dynamic> _revisarYaEntregada(Map<String, dynamic> r) {
    if (r['success'] != true && r['message'] == _yaEntregada) {
      throw const EntregaYaConfirmadaException(
        'Esta entrega ya estaba confirmada',
      );
    }
    return r;
  }

  /// Rechazo de PUT /entregas/:id/estado (routes/entregasRoutes.js) cuando
  /// la entrega ya está entregada y se pide pasarla a entregada otra vez.
  static const _yaEntregada = 'No se puede pasar de "entregada" a "entregada"';

  /// La respuesta si trae success: true; si no, ApiException con su mensaje
  /// (o [porDefecto]).
  static Future<Map<String, dynamic>> _exigir(
    Future<Map<String, dynamic>> llamada,
    String porDefecto,
  ) async {
    final r = await llamada;
    if (r['success'] != true) {
      throw ApiException(r['message']?.toString() ?? porDefecto);
    }
    return r;
  }
}
