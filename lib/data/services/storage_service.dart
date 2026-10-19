// lib/data/services/storage_service.dart
//
// El JWT vive en el almacenamiento cifrado del sistema (Keystore en Android,
// Keychain en iOS) con flutter_secure_storage (#25). El usuario actual no es
// secreto y sigue en SharedPreferences. Versiones anteriores guardaban el
// token en SharedPreferences (XML en claro): getToken lo migra la primera vez
// y lo borra de ahí.
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService({FlutterSecureStorage? seguro})
      : _seguro = seguro ?? const FlutterSecureStorage();

  static const String _tokenKey = 'pierreposteria_token';
  static const String _currentUserKey = 'pierreposteria_current_user';

  final FlutterSecureStorage _seguro;

  // Token
  Future<void> saveToken(String token) =>
      _seguro.write(key: _tokenKey, value: token);

  Future<String?> getToken() async {
    final String? token;
    try {
      token = await _seguro.read(key: _tokenKey);
    } on PlatformException catch (e) {
      // La llave del Keystore ya no descifra el valor: se descarta y el
      // usuario vuelve a iniciar sesión.
      PierLog.error('Token ilegible, se descarta: ${e.code}');
      await _seguro.delete(key: _tokenKey);
      return null;
    }
    return token ?? _migrarTokenAntiguo();
  }

  /// Mueve el token de SharedPreferences (versiones anteriores) al
  /// almacenamiento cifrado.
  Future<String?> _migrarTokenAntiguo() async {
    final prefs = await SharedPreferences.getInstance();
    final antiguo = prefs.getString(_tokenKey);
    if (antiguo == null) return null;
    await _seguro.write(key: _tokenKey, value: antiguo);
    await prefs.remove(_tokenKey);
    PierLog.auth('Token migrado al almacenamiento seguro');
    return antiguo;
  }

  Future<void> removeToken() async {
    await _seguro.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // por si quedó uno sin migrar
  }

  // Usuario actual
  Future<void> saveUser(String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userJson);
  }

  Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  Future<void> removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Limpiar todo (logout)
  Future<void> clearAll() async {
    await removeToken();
    await removeUser();
  }

  // Verificar si hay sesión activa
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
