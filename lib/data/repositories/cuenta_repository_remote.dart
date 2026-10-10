// lib/data/repositories/cuenta_repository_remote.dart
//
// Implementación HTTP de CuentaRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/codigo_alexa.dart';

/// Implementación de [CuentaRepository] contra el backend vía [ApiClient].
class CuentaRepositoryRemote implements CuentaRepository {
  CuentaRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
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

  @override
  Future<CodigoAlexa> generarCodigoAlexa() async {
    final result = await _api.postAuth(ApiConstants.alexaGenerarCodigo, {});
    if (result['success'] != true || result['codigo'] == null) {
      throw ApiException(
        result['message']?.toString() ?? 'No se pudo generar el código',
      );
    }
    return CodigoAlexa.fromJson(result);
  }

  @override
  Future<void> enviarContacto({
    required String nombre,
    required String email,
    required String telefono,
    required String tipoProducto,
    required String mensaje,
    required bool conSesion,
  }) async {
    final body = {
      'nombre': nombre,
      'email': email,
      'telefono': telefono.isEmpty ? null : telefono,
      'tipo_producto': tipoProducto,
      'mensaje': mensaje,
    };
    final r = conSesion
        ? await _api.postAuth(ApiConstants.enviarContacto, body)
        : await _api.post(ApiConstants.enviarContacto, body);
    if (r['success'] != true) {
      throw ApiException(r['message']?.toString() ?? 'Error al enviar');
    }
  }
}
