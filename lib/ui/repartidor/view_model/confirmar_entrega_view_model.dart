// lib/ui/repartidor/view_model/confirmar_entrega_view_model.dart
//
// Estado de «Confirmar entrega» (MVVM, Fase 5): la foto de evidencia
// opcional y el envío. Si la foto no sube no se bloquea la entrega: se
// confirma sin evidencia y la vista lo avisa ([fotoSinSubir]).
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/domain/models/entrega_model.dart';
import 'package:pier_reposteria/ui/repartidor/view_model/accion_entrega_view_model.dart';

class ConfirmarEntregaViewModel extends AccionEntregaViewModel {
  ConfirmarEntregaViewModel({
    required super.repo,
    required super.entrega,
    super.alCambiar,
  });

  static const String faltaQuienRecibio = 'Indica quién recibió el pedido';
  static const String mensajeConfirmada = 'Entrega confirmada';

  String? _evidencia;
  bool _enviando = false;
  bool _fotoSinSubir = false;

  /// Ruta local de la foto elegida (null si no hay).
  String? get evidencia => _evidencia;
  bool get enviando => _enviando;

  /// En el último envío la foto no se pudo subir y se confirmó sin ella.
  bool get fotoSinSubir => _fotoSinSubir;

  void elegirEvidencia(String ruta) {
    _evidencia = ruta;
    notifyListeners();
  }

  void quitarEvidencia() {
    _evidencia = null;
    notifyListeners();
  }

  /// Sube la evidencia (si hay) y marca la entrega como entregada a nombre
  /// de [recibio], que es obligatorio.
  ///
  /// Si ya estaba entregada (#270) termina bien: es lo que el repartidor
  /// buscaba. Se le dice con claridad y el panel se pone al día para que la
  /// entrega pase al historial; la vista se cierra como al confirmar.
  Future<ResultadoEntrega> confirmar(String recibio) async {
    _fotoSinSubir = false;
    final nombre = recibio.trim();
    if (nombre.isEmpty) return (ok: false, mensaje: faltaQuienRecibio);
    return correr((v) => _enviando = v, () async {
      try {
        await cambiarEstado(
          EstadoEntrega.entregada,
          recibioNombre: nombre,
          evidenciaUrl: await _subirEvidencia(),
        );
      } on EntregaYaConfirmadaException catch (e) {
        await avisarCambio();
        return e.message;
      }
      return mensajeConfirmada;
    });
  }

  Future<String?> _subirEvidencia() async {
    final ruta = _evidencia;
    if (ruta == null) return null;
    try {
      return await repo.subirEvidencia(ruta);
    } on ApiException {
      _fotoSinSubir = true;
      return null;
    }
  }
}
