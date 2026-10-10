// lib/data/repositories/auth_repository.dart
//
// Única puerta a autenticación (registro, login, Google, perfil, reset).
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es AuthRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 5: los métodos que usan las pantallas de auth son tipados y lanzan
// ApiException con el mensaje listo para el usuario; los que abren sesión
// devuelven el usuario (ya guardado junto con el token).

abstract class AuthRepository {
  /// Crea la cuenta; el backend manda el código de verificación por correo.
  Future<void> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
  });

  /// Verifica el email con el código de 6 dígitos y abre sesión.
  Future<Map<String, dynamic>> verificarEmail({
    required String email,
    required String codigo,
  });

  /// Reenvía el código de verificación; devuelve el mensaje del backend.
  Future<String> reenviarCodigo(String email);

  /// Inicia sesión con correo y contraseña.
  Future<Map<String, dynamic>> iniciarSesion({
    required String email,
    required String password,
  });

  /// Google Sign-In (solo Android/iOS). Devuelve null si el usuario cancela.
  Future<Map<String, dynamic>?> iniciarSesionConGoogle();

  /// Logout
  Future<void> logout();

  /// Obtener perfil del usuario
  Future<Map<String, dynamic>> getProfile();

  /// Actualizar perfil
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data);

  /// Manda por correo el código para restablecer la contraseña.
  Future<void> solicitarRestablecimiento(String email);

  /// Restablece la contraseña con el código recibido.
  Future<void> restablecerPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  });

  /// Verificar si hay sesión activa (para Splash)
  Future<bool> isAuthenticated();

  /// Obtener usuario guardado localmente
  Future<Map<String, dynamic>?> getCurrentUser();
}
