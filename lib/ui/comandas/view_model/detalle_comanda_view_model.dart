// lib/ui/comandas/view_model/detalle_comanda_view_model.dart
//
// Estado del detalle de una comanda (#128, #129): la comanda completa, el
// «Enterado» de producción y, para quien cobra, entregar y cancelar. Si la comanda cambió mientras se leía (409
// VERSION_DESACTUALIZADA), recarga y deja en [cambio] exactamente qué cambió,
// como la web (src/comandas/DetalleComanda.tsx); si otra persona del área ya
// la confirmó (409 YA_CONFIRMADA), recarga para mostrar su firma. Lo crea
// DetalleComandaScreen.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository.dart';
import 'package:pier_reposteria/domain/models/comanda.dart';
import 'package:pier_reposteria/utils/command.dart';

/// Lo que cambió entre la versión que se estaba leyendo (desde) y la que
/// hay ahora (hasta).
typedef CambioEnVivo = ({int desde, int hasta, List<CambioCampo> cambios});

class DetalleComandaViewModel extends ChangeNotifier {
  DetalleComandaViewModel({
    required ComandasRepository repo,
    required this.id,
  }) : _repo = repo {
    enterado = Command0<String>(_confirmar);
    entregar = Command1<EntregaComanda, double>(
      (saldo) => _yRecargar(_repo.entregar(id, saldoCobrado: saldo)),
    );
    cancelar = Command1<String, String>(
      (motivo) => _yRecargar(_repo.cancelar(id, motivo: motivo)),
    );
  }

  final ComandasRepository _repo;
  final int id;

  /// «Enterado» de mi área sobre la versión que estoy viendo. Su resultado
  /// es el mensaje del backend; su error, la ApiException (incluido el
  /// conflicto de versión).
  late final Command0<String> enterado;

  /// Marca la comanda entregada con el saldo cobrado.
  late final Command1<EntregaComanda, double> entregar;

  /// Cancela la comanda con el motivo; su resultado es el mensaje.
  late final Command1<String, String> cancelar;

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

  /// Corre [llamada] y, si salió bien, recarga la comanda.
  Future<T> _yRecargar<T>(Future<T> llamada) async {
    try {
      final r = await llamada;
      await recargar();
      return r;
    } on SesionInvalidaException catch (e) {
      _marcarSesionInvalida(e);
      rethrow;
    }
  }

  void _marcarSesionInvalida(SesionInvalidaException e) {
    _sesionInvalida = true;
    _error = e.message;
    _avisar();
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
      _marcarSesionInvalida(e);
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
    entregar.dispose();
    cancelar.dispose();
    super.dispose();
  }
}
