// lib/ui/auth/view_model/login_view_model.dart
//
// Estado de «Iniciar sesión» (MVVM, Fase 5): entrar con correo y contraseña o
// con Google. Devuelve el usuario para que la vista abra la sesión en
// AuthProvider y navegue según el rol. Con Google la cuenta puede crearse en
// ese momento, así que antes hay que aceptar el aviso de privacidad (#220).
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/ui/auth/view_model/auth_base_view_model.dart';

class LoginViewModel extends AuthBaseViewModel with VisibilidadPasswords {
  LoginViewModel({required AuthRepository repo}) : _repo = repo;

  static const faltaAviso =
      'Para continuar con Google acepta el Aviso de Privacidad';

  final AuthRepository _repo;
  bool _ingresando = false;
  bool _ingresandoConGoogle = false;
  bool _aceptaAviso = false;

  bool get ingresando => _ingresando;
  bool get ingresandoConGoogle => _ingresandoConGoogle;

  /// La casilla del aviso de privacidad junto a Google; empieza sin marcar.
  bool get aceptaAviso => _aceptaAviso;

  set aceptaAviso(bool acepta) {
    _aceptaAviso = acepta;
    notifyListeners();
  }

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
  /// Sin aceptar el aviso no abre Google: deja [faltaAviso] como error.
  Future<Map<String, dynamic>?> iniciarSesionConGoogle() async {
    if (_ingresandoConGoogle) return null;
    if (!_aceptaAviso) {
      fallar(faltaAviso);
      return null;
    }
    final usuario = await correr<Map<String, dynamic>?>(
      _repo.iniciarSesionConGoogle,
      (v) => _ingresandoConGoogle = v,
    );
    if (usuario != null) await _repo.aceptarAvisoDePrivacidad(via: 'google');
    return usuario;
  }
}
