// lib/ui/auth/view_model/auth_base_view_model.dart
//
// Base de los ViewModels de auth (MVVM, Fase 5): corre una llamada al
// AuthRepository con su bandera de «trabajando», guarda el mensaje de error
// (ApiException) y no avisa a la vista si ya se cerró. Los TextEditingController
// y la validación de los formularios se quedan en las vistas.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';

abstract class AuthBaseViewModel extends ChangeNotifier {
  bool _cerrado = false;
  String? _error;

  /// Mensaje del último intento fallido (null si no hubo).
  String? get error => _error;

  /// Deja [mensaje] como error sin llamar al backend (validación previa).
  @protected
  void fallar(String mensaje) {
    _error = mensaje;
    notifyListeners();
  }

  /// Corre [llamada] con [marcar] en true mientras dura. Devuelve lo que
  /// produjo, o null si lanzó ApiException (el motivo queda en [error]).
  @protected
  Future<T?> correr<T>(
    Future<T> Function() llamada,
    ValueSetter<bool> marcar,
  ) async {
    marcar(true);
    _error = null;
    notifyListeners();
    try {
      return await llamada();
    } on ApiException catch (e) {
      if (!_cerrado) _error = e.message;
      return null;
    } finally {
      if (!_cerrado) {
        marcar(false);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}

/// Ojitos de «mostrar contraseña» de los formularios con contraseña.
mixin VisibilidadPasswords on ChangeNotifier {
  bool _verPassword = false;
  bool _verConfirmacion = false;

  bool get verPassword => _verPassword;
  bool get verConfirmacion => _verConfirmacion;

  void alternarPassword() {
    _verPassword = !_verPassword;
    notifyListeners();
  }

  void alternarConfirmacion() {
    _verConfirmacion = !_verConfirmacion;
    notifyListeners();
  }
}
