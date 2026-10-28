// lib/data/repositories/gestion_pedidos_repository_remote.dart
//
// Implementación HTTP de GestionPedidosRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/gestion_pedidos_repository.dart';
import 'package:pier_reposteria/data/repositories/respuesta_api.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/domain/models/pedido_del_dia.dart';

class GestionPedidosRepositoryRemote implements GestionPedidosRepository {
  GestionPedidosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<PedidoDelDia>> abiertos() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.pedidosAbiertos),
      'No se pudieron cargar los pedidos',
    );
    return [
      if (r['pedidos'] case final List lista)
        for (final p in lista) ?PedidoDelDia.fromJson(p),
    ];
  }

  @override
  Future<String> cambiarEstado(String id, String estado, {String? nota}) =>
      _mensaje(
        _api.putAuth(ApiConstants.pedidoEstado(id), {
          'estado': estado,
          'nota_cancelacion': ?nota,
        }),
        'No se pudo cambiar el estado del pedido',
        'Pedido actualizado',
      );

  @override
  Future<String> aprobar(String id) => _mensaje(
        _api.putAuth(ApiConstants.pedidoAprobar(id), const {}),
        'No se pudo aprobar el pedido',
        'Pedido aprobado',
      );

  @override
  Future<String> rechazar(String id, {required String motivo}) => _mensaje(
        _api.putAuth(ApiConstants.pedidoRechazar(id), {'motivo': motivo}),
        'No se pudo rechazar el pedido',
        'Pedido rechazado',
      );

  @override
  Future<List<RepartidorDisponible>> repartidores() async {
    final r = exigirExito(
      await _api.getAuth(ApiConstants.repartidores),
      'No se pudieron cargar los repartidores',
    );
    return [
      if (r['repartidores'] case final List lista)
        for (final x in lista) ?RepartidorDisponible.fromJson(x),
    ];
  }

  @override
  Future<String> asignar(String pedidoId, int repartidorId) => _mensaje(
        _api.postAuth(ApiConstants.asignarEntrega, {
          'pedido_id': int.tryParse(pedidoId) ?? pedidoId,
          'repartidor_id': repartidorId,
        }),
        'No se pudo asignar el repartidor',
        'Repartidor asignado',
      );

  @override
  Future<String> avisarDemora(String pedidoId) => _mensaje(
        _api.postAuth(ApiConstants.avisarDemora, {
          'pedido_id': int.tryParse(pedidoId) ?? pedidoId,
        }),
        'No se pudo avisar la demora',
        'Aviso de demora enviado',
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
