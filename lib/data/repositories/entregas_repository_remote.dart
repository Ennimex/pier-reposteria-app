// lib/data/repositories/entregas_repository_remote.dart
//
// Implementación HTTP de EntregasRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';

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
        }),
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
  Future<String> subirEvidencia(String filePath) async {
    const porDefecto = 'No se pudo subir la foto';
    final r = await _exigir(
      _api.uploadImageAuth(
          ApiConstants.uploadImagen, filePath, {'tipo': 'entrega'}),
      porDefecto,
    );
    final imagen = r['imagen'];
    final url = imagen is Map ? imagen['url']?.toString() : null;
    if (url == null || url.isEmpty) throw const ApiException(porDefecto);
    return url;
  }

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
