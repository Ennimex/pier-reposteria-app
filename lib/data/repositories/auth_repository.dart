// lib/data/repositories/auth_repository.dart
//
// Única puerta a autenticación (registro, login, Google, perfil, reset).
// Recibe un ApiClient por constructor (ApiService en la app, FakeApiClient
// en pruebas). Conserva token y usuario en StorageService.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/storage_service.dart';

class AuthRepository {
  final ApiClient _api;
  AuthRepository({ApiClient? api}) : _api = api ?? ApiService();
  final StorageService _storage = StorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Registro
  Future<Map<String, dynamic>> register({
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
    return result;
  }

  // Verificar email con código de 6 dígitos
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String codigo,
  }) async {
    final result = await _api.post(ApiConstants.verifyEmail, {
      'email': email,
      'codigo': codigo,
    });
    if (result['success'] == true && result['token'] != null) {
      await _storage.saveToken(result['token']);
      await _storage.saveUser(jsonEncode(result['user']));
    }
    return result;
  }

  // Reenviar código de verificación
  Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    return await _api.post(ApiConstants.resendVerification, {'email': email});
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    if (result['success'] == true && result['token'] != null) {
      await _storage.saveToken(result['token']);
      await _storage.saveUser(jsonEncode(result['user']));
    }
    return result;
  }

  // ========================================
  // MÓVIL — Google Sign In (Solo Android/iOS)
  // ========================================

  Future<Map<String, dynamic>> loginWithGoogle() async {
    // Google Sign-In solo disponible en mobile
    if (kIsWeb) {
      return {
        'success': false,
        'message': 'Google Sign-In no disponible en web'
      };
    }

    try {
      // Cerrar sesión previa de Google para forzar selector de cuenta
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'message': 'Inicio de sesión cancelado'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener el token de Google'
        };
      }

      // Enviar idToken al backend
      final result = await _api.post(ApiConstants.googleMobile, {
        'idToken': idToken,
      });

      if (result['success'] == true && result['token'] != null) {
        await _storage.saveToken(result['token']);
        await _storage.saveUser(jsonEncode(result['user']));
      }

      return result;
    } catch (e) {
      PierLog.error('Error al iniciar sesión con Google: $e');
      return {
        'success': false,
        'message': 'Error al iniciar sesión con Google: $e'
      };
    }
  }

  // ========================================

  // Logout
  Future<void> logout() async {
    try {
      await _api.postAuth(ApiConstants.logout, {});
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      PierLog.error('Error cerrando sesión en backend: $e');
      // Si falla el backend, igual limpiamos local
    } finally {
      await _storage.clearAll();
    }
  }

  // Obtener perfil del usuario
  Future<Map<String, dynamic>> getProfile() async {
    final result = await _api.getAuth(ApiConstants.profile);
    if (result['success'] == true && result['user'] != null) {
      await _storage.saveUser(jsonEncode(result['user']));
    }
    return result;
  }

  // Actualizar perfil
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final result = await _api.putAuth(ApiConstants.updateProfile, data);
    if (result['success'] == true && result['user'] != null) {
      await _storage.saveUser(jsonEncode(result['user']));
    }
    return result;
  }

  // Solicitar reset de contraseña
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return await _api.post(ApiConstants.requestPasswordReset, {'email': email});
  }

  // Restablecer contraseña con código
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  }) async {
    return await _api.post(ApiConstants.resetPassword, {
      'email': email,
      'codigo': codigo,
      'nuevaPassword': nuevaPassword,
    });
  }

  // Verificar si hay sesión activa (para Splash)
  Future<bool> isAuthenticated() async {
    return await _storage.isAuthenticated();
  }

  // Obtener usuario guardado localmente
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userStr = await _storage.getUser();
    if (userStr == null) return null;
    return jsonDecode(userStr) as Map<String, dynamic>;
  }
}