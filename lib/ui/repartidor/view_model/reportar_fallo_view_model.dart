// lib/ui/repartidor/view_model/reportar_fallo_view_model.dart
//
// Estado de la hoja «Reportar entrega fallida» (MVVM, Fase 5): la categoría
// elegida y el envío. El motivo que llega al backend combina la categoría
// (si hay y no es «Otro») con el detalle obligatorio.
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/accion_entrega_view_model.dart';

class ReportarFalloViewModel extends AccionEntregaViewModel {
  ReportarFalloViewModel({
    required super.repo,
    required super.entrega,
    super.alCambiar,
  });

  static const List<String> motivos = [
    'Cliente ausente',
    'Dirección incorrecta',
    'No contestó',
    'Otro',
  ];

  static const String faltaDetalle = 'Describe brevemente el motivo del fallo';

  String? _motivo;
  bool _enviando = false;

  /// Categoría elegida (una de [motivos]) o null.
  String? get motivo => _motivo;
  bool get enviando => _enviando;

  void elegirMotivo(String motivo) {
    _motivo = motivo;
    notifyListeners();
  }

  /// Motivo que se manda al backend para [detalle].
  String motivoCompleto(String detalle) =>
      _motivo != null && _motivo != 'Otro' ? '$_motivo: $detalle' : detalle;

  /// Marca la entrega como fallida. [detalle] es obligatorio.
  Future<ResultadoEntrega> reportar(String detalle) async {
    final texto = detalle.trim();
    if (texto.isEmpty) return (ok: false, mensaje: faltaDetalle);
    return correr((v) => _enviando = v, () async {
      await cambiarEstado(
        EstadoEntrega.fallida,
        motivoFallo: motivoCompleto(texto),
      );
      return 'Entrega reportada';
    });
  }
}
