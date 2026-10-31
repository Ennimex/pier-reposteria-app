// lib/data/repositories/gestion_pedidos_repository.dart
//
// Única puerta a la gestión de pedidos del personal (#137): los pedidos
// abiertos, cambiar su estado, aprobar o rechazar los que están por
// confirmar, asignar repartidor y avisar una demora. Devuelve modelos y
// lanza ApiException con el mensaje del backend. La implementación HTTP es
// GestionPedidosRepositoryRemote, registrada en lib/config/dependencies.dart.
import 'package:pier_reposteria/domain/models/pedido_del_dia.dart';

abstract class GestionPedidosRepository {
  /// GET /pedidos?vista=abiertos&completo=1: los que no están completados,
  /// entregados ni cancelados, del compromiso más próximo al más lejano.
  Future<List<PedidoDelDia>> abiertos();

  /// PUT /pedidos/:id/estado. Con `cancelado`, [nota] es el motivo.
  /// Devuelve el mensaje para el personal.
  Future<String> cambiarEstado(String id, String estado, {String? nota});

  /// PUT /pedidos/:id/aprobar: el pedido por confirmar sigue su curso.
  Future<String> aprobar(String id);

  /// PUT /pedidos/:id/rechazar con [motivo] (mín. 5 caracteres): se cancela
  /// y se genera la solicitud de reembolso.
  Future<String> rechazar(String id, {required String motivo});

  /// GET /entregas/repartidores.
  Future<List<RepartidorDisponible>> repartidores();

  /// POST /entregas: asigna el pedido a domicilio (en «listo»).
  Future<String> asignar(String pedidoId, int repartidorId);

  /// POST /entregas/avisar-demora: avisa al cliente que tardará un poco más.
  Future<String> avisarDemora(String pedidoId);
}
