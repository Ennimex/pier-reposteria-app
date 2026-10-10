// lib/data/repositories/auth_repository_remote.dart
//
// Implementación HTTP de AuthRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/). Conserva token y usuario en
// StorageService y cierra la sesión de Google.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/storage_service.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// Implementación de [AuthRepository] contra el backend vía [ApiClient].
class AuthRepositoryRemote implements AuthRepository {
  /// [google] solo se pasa en pruebas (un doble del selector de cuentas).
  AuthRepositoryRemote({required ApiClient api, GoogleSignIn? google})
      : _api = api,
        _googleSignIn = google ?? GoogleSignIn();

  final ApiClient _api;
  final StorageService _storage = StorageService();
  final GoogleSignIn _googleSignIn;

  @override
  Future<void> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
  }) async {
    final result = await _api.post(ApiConstants.register, {
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
      'password': password,
    });
    _exigirExito(result, 'Error al registrar');
  }

  @override
  Future<Map<String, dynamic>> verificarEmail({
    required String email,
    required String codigo,
  }) async {
    final result = await _api.post(ApiConstants.verifyEmail, {
      'email': email,
      'codigo': codigo,
    });
    return _guardarSesion(result, 'Código inválido o expirado');
  }

  @override
  Future<String> reenviarCodigo(String email) async {
    final result =
        await _api.post(ApiConstants.resendVerification, {'email': email});
    _exigirExito(result, 'No se pudo reenviar el código');
    return result['message']?.toString() ?? 'Código reenviado';
  }

  @override
  Future<Map<String, dynamic>> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final result = await _api.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    return _guardarSesion(result, 'Error al iniciar sesión');
  }

  @override
  Future<Map<String, dynamic>?> iniciarSesionConGoogle() async {
    // Google Sign-In solo disponible en mobile
    if (kIsWeb) {
      throw const ApiException('Google Sign-In no disponible en web');
    }

    final Map<String, dynamic> result;
    try {
      // Cerrar sesión previa de Google para forzar selector de cuenta
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // el usuario canceló

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const ApiException('No se pudo obtener el token de Google');
      }

      // Enviar idToken al backend
      result = await _api.post(ApiConstants.googleMobile, {
        'idToken': idToken,
      });
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      PierLog.error('Error al iniciar sesión con Google: $e');
      throw ApiException('Error al iniciar sesión con Google: $e');
    }
    return _guardarSesion(result, 'Error al iniciar sesión con Google');
  }

  @override
  Future<void> logout() async {
    try {
      await _api.postAuth(ApiConstants.logout, {});
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } on Object catch (e) {
      PierLog.error('Error cerrando sesión en backend: $e');
      // Si falla el backend, igual limpiamos local
    } finally {
      await _storage.clearAll();
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    final result = await _api.getAuth(ApiConstants.profile);
    if (result['success'] == true && result['user'] != null) {
      await _storage.saveUser(jsonEncode(result['user']));
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final result = await _api.putAuth(ApiConstants.updateProfile, data);
    if (result['success'] == true && result['user'] != null) {
      await _storage.saveUser(jsonEncode(result['user']));
    }
    return result;
  }

  @override
  Future<void> solicitarRestablecimiento(String email) async {
    final result =
        await _api.post(ApiConstants.requestPasswordReset, {'email': email});
    _exigirExito(result, 'No se pudo enviar el correo');
  }

  @override
  Future<void> restablecerPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  }) async {
    final result = await _api.post(ApiConstants.resetPassword, {
      'email': email,
      'codigo': codigo,
      'nuevaPassword': nuevaPassword,
    });
    _exigirExito(result, 'Código inválido o expirado');
  }

  @override
  Future<bool> isAuthenticated() async {
    return _storage.isAuthenticated();
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userStr = await _storage.getUser();
    if (userStr == null) return null;
    return jsonDecode(userStr) as Map<String, dynamic>;
  }

  /// Lanza [ApiException] si el backend no respondió `success: true`.
  static void _exigirExito(Map<String, dynamic> result, String porDefecto) {
    if (result['success'] != true) {
      throw ApiException(result['message']?.toString() ?? porDefecto);
    }
  }

  /// Respuesta que abre sesión: guarda token y usuario, y devuelve el usuario.
  Future<Map<String, dynamic>> _guardarSesion(
    Map<String, dynamic> result,
    String porDefecto,
  ) async {
    _exigirExito(result, porDefecto);
    final user = result['user'];
    if (user is! Map) throw ApiException(porDefecto);
    final usuario = Map<String, dynamic>.from(user);
    if (result['token'] != null) {
      await _storage.saveToken(result['token']);
      await _storage.saveUser(jsonEncode(usuario));
    }
    return usuario;
  }
}
