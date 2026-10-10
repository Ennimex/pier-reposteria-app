// lib/ui/auth/view_model/login_view_model.dart
//
// Estado de «Iniciar sesión» (MVVM, Fase 5): entrar con correo y contraseña o
// con Google. Devuelve el usuario para que la vista abra la sesión en
// AuthProvider y navegue según el rol.
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/ui/auth/view_model/auth_base_view_model.dart';

class LoginViewModel extends AuthBaseViewModel with VisibilidadPasswords {
  LoginViewModel({required AuthRepository repo}) : _repo = repo;

  final AuthRepository _repo;
  bool _ingresando = false;
  bool _ingresandoConGoogle = false;

  bool get ingresando => _ingresando;
  bool get ingresandoConGoogle => _ingresandoConGoogle;

  /// Usuario de la sesión abierta, o null si falló (motivo en [error]).
  Future<Map<String, dynamic>?> iniciarSesion(
    String email,
    String password,
  ) async {
    if (_ingresando) return null;
    return correr(
      () => _repo.iniciarSesion(email: email, password: password),
      (v) => _ingresando = v,
    );
  }

  /// Usuario de la sesión abierta, o null si falló (motivo en [error]) o si
  /// el usuario cerró el selector de cuentas (sin error).
  Future<Map<String, dynamic>?> iniciarSesionConGoogle() async {
    if (_ingresandoConGoogle) return null;
    return correr<Map<String, dynamic>?>(
      _repo.iniciarSesionConGoogle,
      (v) => _ingresandoConGoogle = v,
    );
  }
}
