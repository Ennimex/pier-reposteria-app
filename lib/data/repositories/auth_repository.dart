// lib/data/repositories/auth_repository.dart
//
// Única puerta a autenticación (registro, login, Google, perfil, reset).
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es AuthRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class AuthRepository {
  /// Registro
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
  });

  /// Verificar email con código de 6 dígitos
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String codigo,
  });

  /// Reenviar código de verificación
  Future<Map<String, dynamic>> resendVerificationCode(String email);

  /// Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  /// Google Sign-In (solo Android/iOS; en web devuelve success: false).
  Future<Map<String, dynamic>> loginWithGoogle();

  /// Logout
  Future<void> logout();

  /// Obtener perfil del usuario
  Future<Map<String, dynamic>> getProfile();

  /// Actualizar perfil
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data);

  /// Solicitar reset de contraseña
  Future<Map<String, dynamic>> requestPasswordReset(String email);

  /// Restablecer contraseña con código
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  });

  /// Verificar si hay sesión activa (para Splash)
  Future<bool> isAuthenticated();

  /// Obtener usuario guardado localmente
  Future<Map<String, dynamic>?> getCurrentUser();
}
