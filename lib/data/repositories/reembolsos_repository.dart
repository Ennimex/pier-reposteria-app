// lib/data/repositories/reembolsos_repository.dart
//
// Única puerta a los datos de solicitudes de reembolso. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es ReembolsosRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: los métodos tipados (listarMisReembolsos, solicitar) lanzan
// ApiException si el backend falla.
import 'package:pier_pasteleria/domain/models/reembolso.dart';

abstract class ReembolsosRepository {
  /// GET /reembolsos/mis-reembolsos
  Future<Map<String, dynamic>> misReembolsos();

  /// GET /reembolsos/mis-reembolsos tipado; ignora elementos que no sean
  /// objetos.
  Future<List<Reembolso>> listarMisReembolsos();

  /// POST /reembolsos: {pedido_id, monto, motivo, descripcion, ...}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body);

  /// POST /reembolsos tipado. El backend solo acepta pedidos propios en
  /// estado 'completado'; lanza ApiException con su mensaje si lo rechaza.
  Future<void> solicitar({
    required String pedidoId,
    required double monto,
    required String motivo,
    required String descripcion,
  });
}
