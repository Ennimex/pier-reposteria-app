// lib/utils/command.dart
//
// Command (recomendación de la guía oficial de arquitectura de Flutter): una
// acción asíncrona del usuario con su propio estado (corriendo, resultado,
// error). La vista deshabilita el botón mientras corre y reacciona al
// resultado; un segundo toque mientras corre se ignora.
import 'package:flutter/foundation.dart';

/// Estado común de los comandos; [Command0] y [Command1] solo cambian en
/// los argumentos de la acción.
abstract class Command<T> extends ChangeNotifier {
  bool _corriendo = false;
  T? _resultado;
  Object? _error;

  bool get corriendo => _corriendo;

  /// Lo que devolvió la última ejecución (null si falló o no ha corrido).
  T? get resultado => _resultado;

  /// La excepción de la última ejecución, si la hubo.
  Object? get error => _error;

  /// Corre [accion]; si ya está corriendo no hace nada.
  Future<void> _correr(Future<T> Function() accion) async {
    if (_corriendo) return;
    _corriendo = true;
    _resultado = null;
    _error = null;
    notifyListeners();
    try {
      _resultado = await accion();
    } on Object catch (e) {
      _error = e;
    } finally {
      _corriendo = false;
      notifyListeners();
    }
  }

  /// Olvida el resultado y el error (cuando la vista ya los atendió).
  void limpiar() {
    _resultado = null;
    _error = null;
    notifyListeners();
  }
}

/// Acción sin argumentos que produce un [T].
class Command0<T> extends Command<T> {
  Command0(this._accion);

  final Future<T> Function() _accion;

  /// Ejecuta la acción; si ya está corriendo no hace nada.
  Future<void> execute() => _correr(_accion);
}

/// Acción con un argumento [A] que produce un [T] (p. ej. entregar una
/// comanda con el saldo cobrado).
class Command1<T, A> extends Command<T> {
  Command1(this._accion);

  final Future<T> Function(A) _accion;

  /// Ejecuta la acción con [argumento]; si ya está corriendo no hace nada.
  Future<void> execute(A argumento) => _correr(() => _accion(argumento));
}
