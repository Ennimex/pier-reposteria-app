// lib/ui/comandas/view_model/detalle_comanda_view_model.dart
//
// Estado del detalle de una comanda (#128): la comanda completa y el
// «Enterado» de producción. Si la comanda cambió mientras se leía (409
// VERSION_DESACTUALIZADA), recarga y deja en [cambio] exactamente qué cambió,
// como la web (src/comandas/DetalleComanda.tsx); si otra persona del área ya
// la confirmó (409 YA_CONFIRMADA), recarga para mostrar su firma. Lo crea
// DetalleComandaScreen.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/utils/command.dart';

/// Lo que cambió entre la versión que se estaba leyendo (desde) y la que
/// hay ahora (hasta).
typedef CambioEnVivo = ({int desde, int hasta, List<CambioCampo> cambios});

class DetalleComandaViewModel extends ChangeNotifier {
  DetalleComandaViewModel({
    required ComandasRepository repo,
    required this.id,
  }) : _repo = repo {
    enterado = Command0<String>(_confirmar);
  }

  final ComandasRepository _repo;
  final int id;

  /// «Enterado» de mi área sobre la versión que estoy viendo. Su resultado
  /// es el mensaje del backend; su error, la ApiException (incluido el
  /// conflicto de versión).
  late final Command0<String> enterado;

  DetalleComanda? _detalle;
  bool _cargando = false;
  String? _error;
  bool _sesionInvalida = false;
  CambioEnVivo? _cambio;
  bool _cerrado = false;

  DetalleComanda? get detalle => _detalle;
  bool get cargando => _cargando;

  /// Por qué no se pudo traer la comanda (se conserva la que había).
  String? get error => _error;

  /// El backend rechazó la sesión: la vista debe cerrarla ([error] trae el
  /// mensaje para la persona).
  bool get sesionInvalida => _sesionInvalida;

  /// Cambios vistos en vivo (al intentar confirmar una versión vieja).
  CambioEnVivo? get cambio => _cambio;

  /// Primera carga, con indicador.
  Future<void> cargar() {
    _cargando = true;
    notifyListeners();
    return recargar();
  }

  /// Vuelve a traer la comanda sin indicador (jalar o volver a la app).
  Future<void> recargar() async {
    try {
      _detalle = await _repo.detalle(id);
      _error = null;
    } on SesionInvalidaException catch (e) {
      _sesionInvalida = true;
      _error = e.message;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _cargando = false;
    _avisar();
  }

  /// Oculta la caja de «Esta comanda cambió mientras la veías».
  void descartarCambio() {
    _cambio = null;
    notifyListeners();
  }

  Future<String> _confirmar() async {
    final leida = _detalle;
    if (leida == null) {
      throw const ApiException('La comanda aún no se ha cargado');
    }
    try {
      final mensaje = await _repo.confirmar(id, version: leida.version);
      _cambio = null;
      await recargar();
      return mensaje;
    } on ConflictoComandaException catch (e) {
      await recargar();
      final actual = _detalle;
      if (e.cambio && actual != null && actual.version > leida.version) {
        final desde = min(_cambio?.desde ?? leida.version, leida.version);
        _cambio = (
          desde: desde,
          hasta: actual.version,
          cambios: actual.cambiosDesde(desde),
        );
        _avisar();
      }
      rethrow;
    } on SesionInvalidaException catch (e) {
      _sesionInvalida = true;
      _error = e.message;
      _avisar();
      rethrow;
    }
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    enterado.dispose();
    super.dispose();
  }
}
