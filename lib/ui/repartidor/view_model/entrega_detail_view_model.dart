// lib/ui/repartidor/view_model/entrega_detail_view_model.dart
//
// Estado del detalle de una entrega (MVVM, Fase 5). Respeta el flujo del
// backend: asignada -> «Salir en camino» (en_camino) -> «Marcar entregado».
// También permite entregar DIRECTO desde asignada (repartidor que ya está en
// la zona) y, en camino, «Avisar que llegué» (notifica al cliente sin cambiar
// el estado). Arma además los enlaces para llamar, escribir y navegar.
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/accion_entrega_view_model.dart';

class EntregaDetailViewModel extends AccionEntregaViewModel {
  EntregaDetailViewModel({
    required super.repo,
    required super.entrega,
    super.alCambiar,
  }) : _estado = entrega.estado;

  /// Mensaje al salir en camino.
  static const String mensajeEnCamino =
      'Vas en camino. Confirma cuando entregues.';

  // Puede avanzar (asignada -> en_camino) sin salir de la pantalla.
  EstadoEntrega _estado;
  bool _saliendo = false;
  bool _avisandoLlegada = false;

  EstadoEntrega get estado => _estado;
  bool get saliendo => _saliendo;
  bool get avisandoLlegada => _avisandoLlegada;

  /// Asignada o en camino: todavía hay botones de acción.
  bool get puedeAccionar =>
      _estado == EstadoEntrega.asignada || _estado == EstadoEntrega.enCamino;

  /// asignada -> en_camino. La pantalla se queda y cambia sus botones.
  Future<ResultadoEntrega> salirEnCamino() =>
      correr((v) => _saliendo = v, () async {
        await cambiarEstado(EstadoEntrega.enCamino);
        _estado = EstadoEntrega.enCamino;
        return mensajeEnCamino;
      });

  /// Aviso al cliente «tu repartidor llegó» (solo en camino; no cambia el
  /// estado).
  Future<ResultadoEntrega> avisarLlegada() => correr(
        (v) => _avisandoLlegada = v,
        () => repo.avisarLlegada(entrega.id),
      );

  /// Teléfono para contactar: el de la dirección; si no, el del cliente.
  String? get telefono =>
      entrega.direccion.telefonoContacto ?? entrega.clienteTelefono;

  /// Marcador del teléfono (null sin teléfono).
  Uri? get uriLlamada {
    final tel = telefono;
    return tel == null ? null : Uri.parse('tel:${tel.replaceAll(' ', '')}');
  }

  /// Chat de WhatsApp. wa.me pide el número internacional: a un número
  /// mexicano de 10 dígitos se le antepone la lada 52.
  Uri? get uriWhatsapp {
    final tel = telefono;
    if (tel == null) return null;
    final digitos = tel.replaceAll(RegExp('[^0-9]'), '');
    final numero = digitos.length == 10 ? '52$digitos' : digitos;
    return Uri.parse('https://wa.me/$numero');
  }

  /// Ruta en Google Maps: coordenadas exactas si la dirección las tiene
  /// (migración 004); si no, búsqueda por texto de la dirección.
  Uri get uriComoLlegar {
    final destino = Uri.encodeComponent(entrega.direccion.destinoMaps);
    return Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=$destino&travelmode=driving');
  }
}
