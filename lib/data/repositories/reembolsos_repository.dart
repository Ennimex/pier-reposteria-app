// lib/data/repositories/reembolsos_repository.dart
//
// Única puerta a los datos de solicitudes de reembolso. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: los métodos tipados (listarMisReembolsos, solicitar) lanzan
// ApiException si el backend falla.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/reembolso.dart';

class ReembolsosRepository {
  ReembolsosRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// GET /reembolsos/mis-reembolsos
  Future<Map<String, dynamic>> misReembolsos() => _api.getAuth(ApiConstants.misReembolsos);

  /// GET /reembolsos/mis-reembolsos tipado; ignora elementos que no sean
  /// objetos.
  Future<List<Reembolso>> listarMisReembolsos() async {
    final r = await misReembolsos();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus solicitudes',
      );
    }
    final data = r['reembolsos'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Reembolso.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// POST /reembolsos: {pedido_id, monto, motivo, descripcion, ...}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearReembolso, body);

  /// POST /reembolsos tipado. El backend solo acepta pedidos propios en
  /// estado 'completado'; lanza ApiException con su mensaje si lo rechaza.
  Future<void> solicitar({
    required String pedidoId,
    required double monto,
    required String motivo,
    required String descripcion,
  }) async {
    final r = await crear({
      'pedido_id': int.tryParse(pedidoId) ?? pedidoId,
      'monto': monto,
      'motivo': motivo,
      'descripcion': descripcion,
    });
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al enviar solicitud',
      );
    }
  }
}
