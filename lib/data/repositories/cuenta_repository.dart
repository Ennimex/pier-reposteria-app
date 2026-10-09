// lib/data/repositories/cuenta_repository.dart
//
// Única puerta a los datos de la cuenta del cliente (perfil, Alexa, contacto). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: los métodos que ya tienen ViewModel devuelven modelos tipados y
// lanzan ApiException si el backend falla (generarCodigoAlexa,
// actualizarPerfil).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/codigo_alexa.dart';

class CuentaRepository {
  CuentaRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// PUT /usuarios/perfil/actualizar -> {user: {id, nombre, apellido, email,
  /// telefono, avatar_url, rol}}. Devuelve ese `user` crudo porque
  /// AuthProvider guarda la sesión como Map (se tipa al adelgazar providers,
  /// Fase 5). Ojo: el backend usa COALESCE, así que `telefono: null` conserva
  /// el teléfono anterior (no lo borra).
  Future<Map<String, dynamic>> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    final result = await _api.putAuth(ApiConstants.updateProfileData, {
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
    });
    final user = result['user'];
    if (result['success'] != true || user is! Map) {
      throw ApiException(
        result['message']?.toString() ?? 'No se pudo guardar el perfil',
      );
    }
    return Map<String, dynamic>.from(user);
  }

  /// POST /auth/alexa/generar-codigo -> {codigo, expira_en_segundos}
  Future<CodigoAlexa> generarCodigoAlexa() async {
    final result = await _api.postAuth(ApiConstants.alexaGenerarCodigo, {});
    if (result['success'] != true || result['codigo'] == null) {
      throw ApiException(
        result['message']?.toString() ?? 'No se pudo generar el código',
      );
    }
    return CodigoAlexa.fromJson(result);
  }

  /// POST /contacto: con sesión va autenticado (queda ligado al usuario).
  Future<Map<String, dynamic>> enviarContacto(Map<String, dynamic> body,
          {required bool conSesion}) =>
      conSesion
          ? _api.postAuth(ApiConstants.enviarContacto, body)
          : _api.post(ApiConstants.enviarContacto, body);
}
