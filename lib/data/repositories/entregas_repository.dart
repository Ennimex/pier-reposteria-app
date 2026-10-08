// lib/data/repositories/entregas_repository.dart
//
// Única puerta a los datos de entregas del repartidor. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class EntregasRepository {
  final ApiClient _api;
  EntregasRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /entregas/mis-entregas (asignadas / en camino)
  Future<Map<String, dynamic>> misEntregas() => _api.getAuth(ApiConstants.misEntregas);

  /// GET /entregas/disponibilidad
  Future<Map<String, dynamic>> disponibilidad() => _api.getAuth(ApiConstants.disponibilidad);

  /// PUT /entregas/disponibilidad
  Future<Map<String, dynamic>> cambiarDisponibilidad(bool disponible) =>
      _api.putAuth(ApiConstants.disponibilidad, {'disponible': disponible});

  /// GET /entregas/disponibles: pool de pedidos 'listo' a domicilio.
  Future<Map<String, dynamic>> disponibles() => _api.getAuth(ApiConstants.entregasDisponibles);

  /// POST /entregas/aceptar: el primero que acepta gana (409 si ya se tomó).
  Future<Map<String, dynamic>> aceptar(String pedidoId) =>
      _api.postAuth(ApiConstants.entregasAceptar, {'pedido_id': pedidoId});

  /// PUT /entregas/:id/estado: body {estado, evidencia_url?, motivo_fallo?}
  Future<Map<String, dynamic>> cambiarEstado(String entregaId, Map<String, dynamic> body) =>
      _api.putAuth(ApiConstants.entregaEstado(entregaId), body);

  /// POST /entregas/:id/llegue: avisa al cliente sin cambiar estado.
  Future<Map<String, dynamic>> avisarLlegada(String entregaId) =>
      _api.postAuth(ApiConstants.entregaLlegue(entregaId), {});

  /// POST /upload/imagen (tipo entrega): evidencia de la entrega.
  Future<Map<String, dynamic>> subirEvidencia(String filePath) =>
      _api.uploadImageAuth(
          ApiConstants.uploadImagen, filePath, {'tipo': 'entrega'});
}
