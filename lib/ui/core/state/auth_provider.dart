// lib/ui/core/state/auth_provider.dart
//
// Sesión de la app (estado compartido): quién está dentro y con qué rol. El
// router la escucha para redirigir. Desde la Fase 5 no habla con el backend
// para entrar: los ViewModels de ui/auth/ llaman al AuthRepository y, con el
// usuario que devuelve, la vista abre aquí la sesión con [abrirSesion].
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({required AuthRepository auth}) : _authService = auth {
    _expiraciones = auth.sesionExpirada.listen((_) => _cerrarPorExpiracion());
  }

  final AuthRepository _authService;
  late final StreamSubscription<void> _expiraciones;

  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  bool _sesionExpiro = false;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// La sesión se cerró porque el servidor rechazó el token (#218) y el
  /// aviso todavía no se muestra.
  bool get sesionExpiro => _sesionExpiro;

  // Rol del usuario autenticado (cliente, repartidor, empleado, etc.)
  String? get rol => _currentUser?['rol']?.toString();
  bool get isRepartidor => rol == 'repartidor';

  // Roles internos: operan desde el panel web, no tienen experiencia en la app.
  bool get isEmpleado => rol == 'empleado';
  bool get isGerencia => rol == 'gerencia';
  bool get isDireccion => rol == 'direccion_general';
  // Producción (hornos y decoración): trabajan las comandas del mostrador.
  bool get isProduccion => rol == 'hornos' || rol == 'decoracion';
  bool get isRolInterno =>
      isEmpleado || isGerencia || isDireccion || isProduccion;

  /// Cliente con sesión (ni repartidor ni personal): ve las publicaciones
  /// del inicio.
  bool get esCliente => isAuthenticated && !isRepartidor && !isRolInterno;

  // Verificar sesión al iniciar app
  Future<void> checkSession() async {
    _isAuthenticated = await _authService.isAuthenticated();
    if (_isAuthenticated) {
      _currentUser = await _authService.getCurrentUser();
    }
    notifyListeners();
  }

  /// Abre la sesión con el usuario que devolvió el repositorio (login,
  /// Google o verificación de email; el token ya quedó guardado).
  void abrirSesion(Map<String, dynamic> usuario) {
    _isAuthenticated = true;
    _currentUser = usuario;
    _sesionExpiro = false;
    notifyListeners();
  }

  /// El servidor rechazó el token (#218): la sesión del teléfono ya se
  /// borró (ApiService), así que solo se cierra aquí, sin volver a llamar al
  /// servidor. Si varias peticiones fallan a la vez, se cierra una sola vez.
  void _cerrarPorExpiracion() {
    if (!_isAuthenticated) return;
    _isAuthenticated = false;
    _currentUser = null;
    _sesionExpiro = true;
    notifyListeners();
  }

  /// La vista ya mostró el aviso de sesión expirada.
  void avisoDeSesionMostrado() => _sesionExpiro = false;

  @override
  void dispose() {
    unawaited(_expiraciones.cancel());
    super.dispose();
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  // Actualizar datos del usuario en memoria después de editar perfil
  // No afecta el backend — solo refresca la UI sin necesidad de re-login
  void updateCurrentUser(Map<String, dynamic> updatedFields) {
    if (_currentUser == null) return;
    _currentUser = {
      ..._currentUser!,
      ...updatedFields,
    };
    notifyListeners();
  }
}
