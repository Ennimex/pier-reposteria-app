// lib/ui/auth/view_model/register_view_model.dart
//
// Estado de «Crea tu cuenta» (MVVM, Fase 5): aceptar los términos y registrar.
// Registrarse no abre sesión: la vista pasa a verificar el correo.
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/ui/auth/view_model/auth_base_view_model.dart';

class RegisterViewModel extends AuthBaseViewModel with VisibilidadPasswords {
  RegisterViewModel({required AuthRepository repo}) : _repo = repo;

  static const faltanTerminos = 'Debes aceptar los términos y condiciones';

  final AuthRepository _repo;
  bool _aceptaTerminos = false;
  bool _registrando = false;

  bool get aceptaTerminos => _aceptaTerminos;
  bool get registrando => _registrando;

  set aceptaTerminos(bool acepta) {
    _aceptaTerminos = acepta;
    notifyListeners();
  }

  /// true si el backend creó la cuenta; si falló, el motivo queda en [error].
  Future<bool> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
  }) async {
    if (_registrando) return false;
    final ok = await correr(() async {
      await _repo.registrar(
        nombre: nombre,
        apellido: apellido,
        email: email,
        telefono: telefono,
        password: password,
      );
      return true;
    }, (v) => _registrando = v);
    return ok ?? false;
  }
}
