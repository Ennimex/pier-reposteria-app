// lib/data/repositories/quejas_repository.dart
//
// Única puerta a los datos de quejas y sugerencias. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: los métodos tipados (listarMisQuejas, crearQueja) lanzan
// ApiException si el backend falla.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/queja.dart';

class QuejasRepository {
  QuejasRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// GET /quejas/mis-quejas
  Future<Map<String, dynamic>> misQuejas() => _api.getAuth(ApiConstants.misQuejas);

  /// GET /quejas/mis-quejas tipado; ignora elementos que no sean objetos.
  Future<List<Queja>> listarMisQuejas() async {
    final r = await misQuejas();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus quejas',
      );
    }
    final data = r['quejas'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Queja.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// POST /quejas: {tipo, categoria, asunto, descripcion, pedido_id?}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearQueja, body);

  /// POST /quejas tipado. Devuelve el ticket generado (vacío si no viene);
  /// lanza ApiException con el mensaje del backend si no se creó.
  Future<String> crearQueja({
    required TipoQueja tipo,
    required CategoriaQueja categoria,
    required String asunto,
    required String descripcion,
    String? pedidoId,
  }) async {
    final r = await crear({
      'tipo': tipo.name,
      'categoria': categoria.name,
      'asunto': asunto,
      'descripcion': descripcion,
      if (pedidoId != null && pedidoId.isNotEmpty)
        'pedido_id': int.tryParse(pedidoId) ?? pedidoId,
    });
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al enviar la queja',
      );
    }
    final queja = r['queja'];
    return queja is Map ? queja['ticket']?.toString() ?? '' : '';
  }
}
