// lib/ui/auth/view_model/verify_email_view_model.dart
//
// Estado de «Verifica tu correo» (MVVM, Fase 5): validar el código de 6
// dígitos (abre sesión) y reenviarlo.
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/ui/auth/view_model/auth_base_view_model.dart';

class VerifyEmailViewModel extends AuthBaseViewModel {
  VerifyEmailViewModel({required AuthRepository repo, required this.email})
      : _repo = repo;

  static const codigoIncompleto = 'Ingresa el código completo de 6 dígitos';

  final AuthRepository _repo;
  final String email;
  bool _verificando = false;
  bool _reenviando = false;

  bool get verificando => _verificando;
  bool get reenviando => _reenviando;

  /// Usuario de la sesión abierta, o null si el código está incompleto o el
  /// backend lo rechazó (motivo en [error]).
  Future<Map<String, dynamic>?> verificar(String codigo) async {
    if (_verificando) return null;
    if (codigo.length < 6) {
      fallar(codigoIncompleto);
      return null;
    }
    return correr(
      () => _repo.verificarEmail(email: email, codigo: codigo),
      (v) => _verificando = v,
    );
  }

  /// Mensaje de éxito del backend, o null si falló (motivo en [error]).
  Future<String?> reenviar() async {
    if (_reenviando) return null;
    return correr(() => _repo.reenviarCodigo(email), (v) => _reenviando = v);
  }
}
