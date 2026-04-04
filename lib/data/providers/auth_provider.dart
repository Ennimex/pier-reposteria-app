//lib/data/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Verificar sesión al iniciar app
  Future<void> checkSession() async {
    _isAuthenticated = await _authService.isAuthenticated();
    if (_isAuthenticated) {
      _currentUser = await _authService.getCurrentUser();
    }
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.login(email: email, password: password);
    _isLoading = false;

    if (result['success'] == true) {
      _isAuthenticated = true;
      _currentUser = result['user'];
      notifyListeners();
      return true;
    }

    _errorMessage = result['message'] ?? 'Error al iniciar sesión';
    notifyListeners();
    return false;
  }

  // ========================================
  // MÓVIL — Google Sign In
  // ========================================

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint('🔵 [AuthProvider] loginWithGoogle iniciado');

    final result = await _authService.loginWithGoogle();

    debugPrint('🔵 [AuthProvider] resultado: $result');

    _isLoading = false;

    if (result['success'] == true) {
      _isAuthenticated = true;
      _currentUser = result['user'];
      debugPrint('🟢 [AuthProvider] isAuthenticated = $_isAuthenticated, llamando notifyListeners()');
      notifyListeners();
      debugPrint('🟢 [AuthProvider] notifyListeners() completado');
      return true;
    }

    _errorMessage = result['message'] ?? 'Error al iniciar sesión con Google';
    debugPrint('🔴 [AuthProvider] error: $_errorMessage');
    notifyListeners();
    return false;
  }

  // ========================================

  // Registro
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.register(
      nombre: nombre,
      apellido: apellido,
      email: email,
      telefono: telefono,
      password: password,
    );

    _isLoading = false;
    notifyListeners();
    return result;
  }

  // Verificar email
  Future<bool> verifyEmail(String email, String codigo) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.verifyEmail(email: email, codigo: codigo);
    _isLoading = false;

    if (result['success'] == true) {
      _isAuthenticated = true;
      _currentUser = result['user'];
      notifyListeners();
      return true;
    }

    _errorMessage = result['message'];
    notifyListeners();
    return false;
  }

  // Reenviar código
  Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    return await _authService.resendVerificationCode(email);
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  // Solicitar reset de contraseña
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return await _authService.requestPasswordReset(email);
  }

  // Restablecer contraseña
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  }) async {
    return await _authService.resetPassword(
      email: email,
      codigo: codigo,
      nuevaPassword: nuevaPassword,
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}