// lib/ui/orders/view_model/order_detail_view_model.dart
//
// Estado del detalle de un pedido (MVVM, Fase 5): arranca con el pedido que
// ya traía la lista (sin pantalla en blanco), lo refresca en silencio desde
// GET /pedidos/:id, arma los pasos de la línea de tiempo y cancela.
//
// Al cancelar siempre se vuelve a leer el pedido: el backend puede fallar
// DESPUÉS de aplicar la cancelación (p. ej. al mandar el correo) y en ese
// caso el pedido sí quedó cancelado.
//
// Si al releerlo cambió de estado se avisa a quien abrió el detalle (la
// lista de pedidos, el banner de inicio) para que se ponga al día sin
// recargar todo; si no cambió, no se avisa.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';

/// Un paso de la línea de tiempo del pedido.
typedef PasoPedido = ({OrderStatus estado, String etiqueta});

/// Cómo terminó «Cancelar pedido»: si quedó cancelado y lo que hay que
/// decirle al cliente.
typedef ResultadoCancelacion = ({bool cancelado, String mensaje});

class OrderDetailViewModel extends ChangeNotifier {
  OrderDetailViewModel({
    required PedidosRepository repo,
    required Order pedido,
    ValueChanged<Order>? alCambiarEstado,
  })  : _repo = repo,
        _pedido = pedido,
        _alCambiarEstado = alCambiarEstado;

  /// Mensaje si el backend falló después de cancelar.
  static const String mensajeCancelado =
      'Pedido cancelado; tu reembolso ya está en proceso';

  final PedidosRepository _repo;
  final ValueChanged<Order>? _alCambiarEstado;
  bool _cerrado = false;

  Order _pedido;
  bool _actualizando = false;
  bool _cancelando = false;

  Order get pedido => _pedido;
  bool get actualizando => _actualizando;
  bool get cancelando => _cancelando;

  /// Vuelve a leer el pedido. Si falla se queda el que había.
  Future<void> actualizar() async {
    if (_actualizando) return;
    _actualizando = true;
    notifyListeners();
    await _leerPedido();
    if (_cerrado) return;
    _actualizando = false;
    notifyListeners();
  }

  /// Cancela el pedido y lo vuelve a leer para mostrar su estado real.
  Future<ResultadoCancelacion> cancelar() async {
    _cancelando = true;
    notifyListeners();
    String mensaje;
    var aceptada = true;
    try {
      mensaje = await _repo.cancelarPedido(_pedido.id);
    } on ApiException catch (e) {
      mensaje = e.message;
      aceptada = false;
    }
    await _leerPedido();
    final cancelado = aceptada || _pedido.status == OrderStatus.cancelled;
    if (!aceptada && cancelado) mensaje = mensajeCancelado;
    if (!_cerrado) {
      _cancelando = false;
      notifyListeners();
    }
    return (cancelado: cancelado, mensaje: mensaje);
  }

  Future<void> _leerPedido() async {
    try {
      final fresco = await _repo.obtenerPedido(_pedido.id);
      final cambio = fresco.status != _pedido.status ||
          fresco.porConfirmar != _pedido.porConfirmar;
      if (!_cerrado) _pedido = fresco;
      // Aunque el detalle ya se haya cerrado: quien lo abrió sigue vivo.
      if (cambio) _alCambiarEstado?.call(fresco);
    } on ApiException {
      // Se queda el pedido que había.
    }
  }

  /// Pasos de la línea de tiempo. Todo pedido pagado nace «Listo» (la
  /// repostería ya está hecha); «Pendiente» quedó solo para los programados
  /// por confirmar, así que el primer paso del pickup refleja eso.
  List<PasoPedido> get pasos => _pedido.esDomicilio
      ? const [
          (estado: OrderStatus.ready, etiqueta: 'Listo'),
          (estado: OrderStatus.assigned, etiqueta: 'Asignado'),
          (estado: OrderStatus.onTheWay, etiqueta: 'En camino'),
          (estado: OrderStatus.delivered, etiqueta: 'Entregado'),
        ]
      : [
          (
            estado: OrderStatus.pending,
            etiqueta: _pedido.porConfirmar ? 'Por confirmar' : 'Recibido',
          ),
          (estado: OrderStatus.ready, etiqueta: 'Listo'),
          (estado: OrderStatus.completed, etiqueta: 'Entregado'),
        ];

  /// Índice del paso actual (-1 si el estado no está en la línea). Un pedido
  /// viejo aún «en preparación» se ubica tras Recibido.
  int get pasoActual {
    final i = pasos.indexWhere((p) => p.estado == _pedido.status);
    if (i == -1 && _pedido.status == OrderStatus.preparing) return 0;
    return i;
  }

  /// Cancelado o con entrega fallida: en lugar de la línea va un aviso.
  bool get terminoMal =>
      _pedido.status == OrderStatus.cancelled ||
      _pedido.status == OrderStatus.deliveryFailed;

  /// Muestra la animación del repartidor (domicilio en camino).
  bool get vaEnCamino =>
      _pedido.esDomicilio && _pedido.status == OrderStatus.onTheWay;

  /// Explicación del estado para el cliente.
  String get mensajeEstado {
    switch (_pedido.status) {
      case OrderStatus.pending:
        return _pedido.porConfirmar
            ? 'Tu pedido es para otra fecha: estamos confirmando la '
                'disponibilidad de tus productos. Te avisamos muy pronto'
            : 'Tu pedido fue recibido y está en cola';
      case OrderStatus.preparing:
        return 'Estamos preparando tu pedido con mucho cariño';
      case OrderStatus.ready:
        return _pedido.esDomicilio
            ? 'Tu pedido está listo y en espera de un repartidor'
            : 'Tu pedido está listo. Pasa a recogerlo';
      case OrderStatus.completed:
      case OrderStatus.delivered:
        return 'Pedido entregado. Gracias por tu compra';
      case OrderStatus.cancelled:
        return 'Este pedido fue cancelado';
      case OrderStatus.assigned:
        return 'Un repartidor tomó tu pedido y saldrá pronto';
      case OrderStatus.onTheWay:
        return 'Tu pedido va en camino a tu domicilio';
      case OrderStatus.deliveryFailed:
        return 'No pudimos entregar tu pedido. Nos pondremos en contacto contigo';
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
