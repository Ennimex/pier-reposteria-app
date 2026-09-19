// lib/data/repositories/cuenta_repository.dart
//
// Única puerta a los datos de la cuenta del cliente (perfil, Alexa, contacto). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class CuentaRepository {
  final ApiClient _api;
  CuentaRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// PUT /usuarios/perfil/actualizar
  Future<Map<String, dynamic>> actualizarPerfil(Map<String, dynamic> body) =>
      _api.putAuth(ApiConstants.updateProfileData, body);

  /// POST /auth/alexa/generar-codigo -> {codigo, expira_en_segundos}
  Future<Map<String, dynamic>> generarCodigoAlexa() =>
      _api.postAuth(ApiConstants.alexaGenerarCodigo, {});

  /// POST /contacto: con sesión va autenticado (queda ligado al usuario).
  Future<Map<String, dynamic>> enviarContacto(Map<String, dynamic> body,
          {required bool conSesion}) =>
      conSesion
          ? _api.postAuth(ApiConstants.enviarContacto, body)
          : _api.post(ApiConstants.enviarContacto, body);
}
