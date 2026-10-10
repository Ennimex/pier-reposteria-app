// lib/ui/more/view_model/vincular_alexa_view_model.dart
//
// Estado de la pantalla «Vincular con Alexa» (MVVM, Fase 3): pide el código
// de un solo uso al repositorio y lleva la cuenta regresiva hasta que expira.
// La vista solo pinta lo que expone y llama a generar() / marcarCopiado().
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';

class VincularAlexaViewModel extends ChangeNotifier {
  VincularAlexaViewModel({required CuentaRepository repo}) : _repo = repo;

  final CuentaRepository _repo;

  String? _codigo;
  int _segundos = 0;
  bool _generando = false;
  bool _copiado = false;
  String _error = '';
  Timer? _cuentaRegresiva;
  Timer? _quitarCopiado;
  bool _cerrado = false;

  /// Código vigente; null si aún no se genera o ya expiró.
  String? get codigo => _codigo;

  /// Segundos que le quedan al código vigente.
  int get segundos => _segundos;
  bool get generando => _generando;

  /// true durante 2 s después de copiar el código.
  bool get copiado => _copiado;

  /// Mensaje del último intento fallido; vacío si no hay error.
  String get error => _error;

  /// Tiempo restante como m:ss (4:05).
  String get tiempoRestante =>
      '${_segundos ~/ 60}:${(_segundos % 60).toString().padLeft(2, '0')}';

  Future<void> generar() async {
    _generando = true;
    _error = '';
    _copiado = false;
    notifyListeners();

    try {
      final nuevo = await _repo.generarCodigoAlexa();
      if (_cerrado) return;
      _cuentaRegresiva?.cancel();
      _codigo = nuevo.codigo;
      _segundos = nuevo.expiraEnSegundos;
      _cuentaRegresiva =
          Timer.periodic(const Duration(seconds: 1), (_) => _avanzarSegundo());
    } on ApiException catch (e) {
      if (_cerrado) return;
      _error = e.message;
    }
    _generando = false;
    notifyListeners();
  }

  void _avanzarSegundo() {
    if (_segundos <= 1) {
      _codigo = null;
      _segundos = 0;
      _cuentaRegresiva?.cancel();
    } else {
      _segundos--;
    }
    notifyListeners();
  }

  /// La vista ya copió el código al portapapeles: muestra la palomita 2 s.
  void marcarCopiado() {
    _copiado = true;
    notifyListeners();
    _quitarCopiado?.cancel();
    _quitarCopiado = Timer(const Duration(seconds: 2), () {
      _copiado = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _cerrado = true;
    _cuentaRegresiva?.cancel();
    _quitarCopiado?.cancel();
    super.dispose();
  }
}
