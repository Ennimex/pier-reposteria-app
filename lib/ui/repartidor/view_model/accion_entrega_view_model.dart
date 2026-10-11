// lib/ui/repartidor/view_model/accion_entrega_view_model.dart
//
// Base de los ViewModels que actúan sobre UNA entrega (MVVM, Fase 5): el
// detalle, la confirmación y el reporte de fallo. Corre la llamada con su
// bandera de «trabajando», convierte la ApiException en el mensaje para el
// repartidor, avisa al panel ([alCambiar]) cuando la entrega cambió de
// estado y no notifica a la vista si ya se cerró.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';

/// Cómo terminó una acción del repartidor y qué decirle.
typedef ResultadoEntrega = ({bool ok, String mensaje});

abstract class AccionEntregaViewModel extends ChangeNotifier {
  AccionEntregaViewModel({
    required EntregasRepository repo,
    required this.entrega,
    AsyncCallback? alCambiar,
  })  : _repo = repo,
        _alCambiar = alCambiar;

  final EntregasRepository _repo;
  final AsyncCallback? _alCambiar;
  final EntregaRepartidor entrega;
  bool _cerrado = false;

  @protected
  EntregasRepository get repo => _repo;

  /// Corre [accion] con [marcar] en true mientras dura. [accion] devuelve el
  /// mensaje de éxito; si lanza ApiException, su mensaje queda como fallo.
  @protected
  Future<ResultadoEntrega> correr(
    ValueSetter<bool> marcar,
    Future<String> Function() accion,
  ) async {
    marcar(true);
    notifyListeners();
    ResultadoEntrega resultado;
    try {
      resultado = (ok: true, mensaje: await accion());
    } on ApiException catch (e) {
      resultado = (ok: false, mensaje: e.message);
    }
    marcar(false);
    notifyListeners();
    return resultado;
  }

  /// Pasa la entrega a [nuevo] y espera a que el panel se ponga al día.
  @protected
  Future<void> cambiarEstado(
    EstadoEntrega nuevo, {
    String? evidenciaUrl,
    String? recibioNombre,
    String? motivoFallo,
  }) async {
    await _repo.cambiarEstado(
      entrega.id,
      nuevo,
      evidenciaUrl: evidenciaUrl,
      recibioNombre: recibioNombre,
      motivoFallo: motivoFallo,
    );
    await _alCambiar?.call();
  }

  @override
  void notifyListeners() {
    if (!_cerrado) super.notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
