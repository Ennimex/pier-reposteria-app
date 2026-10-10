// lib/ui/auth/view_model/reset_password_view_model.dart
//
// Estado de «Nueva contraseña» (MVVM, Fase 5): validar el código y la nueva
// contraseña (mismas reglas que el backend: mín. 6, 1 letra y 1 número) y
// restablecerla.
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/ui/auth/view_model/auth_base_view_model.dart';
import 'package:pier_pasteleria/ui/auth/view_model/verify_email_view_model.dart';

class ResetPasswordViewModel extends AuthBaseViewModel
    with VisibilidadPasswords {
  ResetPasswordViewModel({required AuthRepository repo, required this.email})
      : _repo = repo;

  final AuthRepository _repo;
  final String email;
  bool _restableciendo = false;

  bool get restableciendo => _restableciendo;

  /// Primer problema de lo capturado, o null si se puede enviar.
  static String? validar(String codigo, String password, String confirmacion) {
    if (codigo.length < 6) return VerifyEmailViewModel.codigoIncompleto;
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (!RegExp('[a-zA-Z]').hasMatch(password)) {
      return 'La contraseña debe contener al menos 1 letra';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'La contraseña debe contener al menos 1 número';
    }
    if (password != confirmacion) return 'Las contraseñas no coinciden';
    return null;
  }

  /// true si se restableció; si no pasó la validación o el backend rechazó
  /// el código, el motivo queda en [error]. Contraseñas ya recortadas.
  Future<bool> restablecer(
    String codigo,
    String password,
    String confirmacion,
  ) async {
    if (_restableciendo) return false;
    final problema = validar(codigo, password, confirmacion);
    if (problema != null) {
      fallar(problema);
      return false;
    }
    final ok = await correr(() async {
      await _repo.restablecerPassword(
        email: email,
        codigo: codigo,
        nuevaPassword: password,
      );
      return true;
    }, (v) => _restableciendo = v);
    return ok ?? false;
  }
}
