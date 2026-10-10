// lib/ui/auth/view_model/forgot_password_view_model.dart
//
// Estado de «¿Olvidaste tu contraseña?» (MVVM, Fase 5): pedir el código de
// restablecimiento para un correo.
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/ui/auth/view_model/auth_base_view_model.dart';

class ForgotPasswordViewModel extends AuthBaseViewModel {
  ForgotPasswordViewModel({required AuthRepository repo}) : _repo = repo;

  static const correoInvalido = 'Ingresa un correo electrónico válido';

  final AuthRepository _repo;
  bool _enviando = false;

  bool get enviando => _enviando;

  /// true si el backend mandó el código a [email] (ya recortado); si el
  /// correo no es válido o falló, el motivo queda en [error].
  Future<bool> enviar(String email) async {
    if (_enviando) return false;
    if (email.isEmpty || !email.contains('@')) {
      fallar(correoInvalido);
      return false;
    }
    final ok = await correr(() async {
      await _repo.solicitarRestablecimiento(email);
      return true;
    }, (v) => _enviando = v);
    return ok ?? false;
  }
}
