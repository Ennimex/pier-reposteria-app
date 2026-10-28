// lib/data/services/storage_service.dart
//
// El JWT y el usuario actual (nombre, correo, teléfono, rol…) viven en el
// almacenamiento cifrado del sistema (Keystore en Android, Keychain en iOS)
// con flutter_secure_storage (#25, #217). Versiones anteriores los guardaban
// en SharedPreferences (XML en claro): getToken y getUser los migran la
// primera vez y los borran de ahí.
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

  // Usuario actual (datos personales: cifrado, #217)
  Future<void> saveUser(String userJson) async {
    await _seguro.write(key: _currentUserKey, value: userJson);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey); // por si quedó uno sin migrar
  }

  Future<String?> getUser() async {
    final String? usuario;
    try {
      usuario = await _seguro.read(key: _currentUserKey);
    } on PlatformException catch (e) {
      // Sin el usuario la sesión queda a medias (sin rol, la app abriría
      // la pantalla equivocada): se descarta completa.
      PierLog.error('Usuario ilegible, se cierra la sesión: ${e.code}');
      await _seguro.delete(key: _currentUserKey);
      await removeToken();
      return null;
    }
    return usuario ?? _migrarUsuarioAntiguo();
  }

  /// Mueve el usuario de SharedPreferences (versiones anteriores) al
  /// almacenamiento cifrado.
  Future<String?> _migrarUsuarioAntiguo() async {
    final prefs = await SharedPreferences.getInstance();
    final antiguo = prefs.getString(_currentUserKey);
    if (antiguo == null) return null;
    await _seguro.write(key: _currentUserKey, value: antiguo);
    await prefs.remove(_currentUserKey);
    PierLog.auth('Usuario migrado al almacenamiento seguro');
    return antiguo;
  }

  Future<void> removeUser() async {
    await _seguro.delete(key: _currentUserKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Limpiar todo (logout)
  Future<void> clearAll() async {
    await removeToken();
    await removeUser();
  }

  /// Hay sesión si hay token y usuario. Un token sin usuario (p. ej. el
  /// usuario no se pudo descifrar) no cuenta: se borra y se pide iniciar
  /// sesión, en lugar de abrir la app sin rol.
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    if (await getUser() != null) return true;
    PierLog.auth('Token sin usuario: se cierra la sesión');
    await clearAll();
    return false;
  }
}
