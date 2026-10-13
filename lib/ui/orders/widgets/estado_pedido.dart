// lib/ui/orders/widgets/estado_pedido.dart
//
// Estado de un pedido como lo pintan «Mis Pedidos» y el detalle: el chip con
// la etiqueta corta y el color del estado, y el ícono de cada estado. Cuando
// el estado cambia con la pantalla abierta (refresco, cancelación), el chip
// cambia de tinte, ajusta su ancho y la etiqueta rueda en lugar de saltar;
// al abrir un pedido desde la lista, el chip vuela de la tarjeta al
// encabezado del detalle.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/orders/widgets/movimiento_pedidos.dart';

/// Chip redondeado con el estado del pedido («Listo», «En camino»…).
class EstadoPedidoChip extends StatelessWidget {
  const EstadoPedidoChip({required this.pedido, super.key});

  final Order pedido;

  @override
  Widget build(BuildContext context) {
    final color = pedido.statusColor;
    return AnimatedContainer(
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEstandar,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      // El chip vive al final de su fila: crece o se encoge hacia el inicio
      // y la etiqueta nueva sube mientras la anterior se va.
      child: TamanoSuave(
        alineacion: AlignmentDirectional.centerEnd,
        child: TextoRodante(
          pedido.estadoCorto,
          alineacion: AlignmentDirectional.centerEnd,
          estilo: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// El chip de estado que vuela de la tarjeta de «Mis Pedidos» al encabezado
/// del detalle (y de regreso, también con el gesto de regresar de iOS): la
/// misma etiqueta `pedido-estado-<id>` en los dos extremos. Si el otro
/// extremo no existe (el detalle abierto desde el inicio, o el pedido ya se
/// movió de pestaña) simplemente no vuela. Con movimiento reducido, nunca.
class EstadoPedidoHero extends StatelessWidget {
  const EstadoPedidoHero({required this.pedido, super.key});

  final Order pedido;

  static String etiqueta(String pedidoId) => 'pedido-estado-$pedidoId';

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: !AppMovimiento.reducido(context),
      child: Hero(
        tag: etiqueta(pedido.id),
        // La misma curva del push: el chip aterriza junto con la página.
        curve: AppMovimiento.curvaPagina,
        transitionOnUserGestures: true,
        flightShuttleBuilder: _vuelo,
        child: EstadoPedidoChip(pedido: pedido),
      ),
    );
  }

  // En el aire el chip no tiene un Material arriba: sin este, su texto se
  // pintaría con el estilo de depuración (subrayado amarillo).
  static Widget _vuelo(
    BuildContext contextoVuelo,
    Animation<double> animacion,
    HeroFlightDirection direccion,
    BuildContext desde,
    BuildContext hacia,
  ) {
    final destino = hacia.widget;
    return Material(
      type: MaterialType.transparency,
      child: destino is Hero ? destino.child : const SizedBox.shrink(),
    );
  }
}

/// Ícono de cada estado (cabecera del detalle y pasos de la línea de tiempo).
IconData iconoEstadoPedido(OrderStatus estado) => switch (estado) {
      OrderStatus.pending => LucideIcons.inbox,
      OrderStatus.preparing => LucideIcons.cookingPot,
      OrderStatus.ready => Icons.check_circle_outline,
      OrderStatus.completed || OrderStatus.delivered => LucideIcons.checkCheck,
      OrderStatus.cancelled => LucideIcons.circleX,
      OrderStatus.assigned => LucideIcons.userRound,
      OrderStatus.onTheWay => LucideIcons.truck,
      OrderStatus.deliveryFailed => LucideIcons.circleAlert,
    };
