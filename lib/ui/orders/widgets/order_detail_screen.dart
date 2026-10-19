// lib/ui/orders/widgets/order_detail_screen.dart
//
// Detalle de un pedido (MVVM, Fase 5): cabecera con número, fecha y estado,
// el estado en grande, la línea de tiempo (detalle_pedido_timeline.dart), la
// información, los productos, el total y «Cancelar pedido» mientras nadie lo
// haya tomado. El estado vive en OrderDetailViewModel; jalar refresca.
//
// Movimiento: al llegar, los bloques se arman de arriba abajo después del
// push (el estado primero, luego la línea, que se llena, y el resto en
// cascada); si el estado cambia con la pantalla abierta (refresco o
// cancelación), el bloque de estado cambia de color, ícono y textos, la línea
// se vuelve aviso y «Cancelar pedido» se desvanece y cierra su espacio.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/orders/view_model/order_detail_view_model.dart';
import 'package:pier_reposteria/ui/orders/widgets/detalle_pedido_partes.dart';
import 'package:pier_reposteria/ui/orders/widgets/detalle_pedido_timeline.dart';
import 'package:pier_reposteria/ui/orders/widgets/estado_pedido.dart';
import 'package:pier_reposteria/ui/orders/widgets/movimiento_pedidos.dart';
import 'package:pier_reposteria/utils/formatters.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:provider/provider.dart';

class OrderDetailScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo
  /// con [order], el pedido que ya traía la lista.
  const OrderDetailScreen({
    required this.order,
    super.key,
    this.alCambiar,
    this.viewModel,
  });

  final Order order;

  /// Se llama con el pedido fresco si cambió de estado (p. ej. al
  /// cancelarlo), para que la pantalla que lo abrió se ponga al día.
  final ValueChanged<Order>? alCambiar;
  final OrderDetailViewModel? viewModel;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderDetailViewModel _vm = widget.viewModel ??
      OrderDetailViewModel(
        repo: context.read(),
        pedido: widget.order,
        alCambiarEstado: widget.alCambiar,
      );

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ OrderDetailScreen: ${widget.order.numero}');
    unawaited(_vm.actualizar()); // refresco silencioso al abrir
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _confirmarCancelacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) => EntradaDialogo(
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('¿Cancelar pedido?',
              style: TextStyle(
                  fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
          content: const Text(
              'Se cancelará tu pedido y generaremos tu solicitud de '
              'reembolso; te avisaremos cuando se procese.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Conservar pedido',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sí, cancelar',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true || !mounted) return;
    final resultado = await _vm.cancelar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultado.mensaje),
      backgroundColor:
          resultado.cancelado ? AppColors.pierVerde : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final pedido = _vm.pedido;
        return Scaffold(
          backgroundColor: AppColors.pierArena,
          body: SafeArea(
            child: Column(
              children: [
                _cabecera(context, pedido),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _vm.actualizar,
                    color: AppColors.pierVerde,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: _contenido(pedido, esperaDeLlegada(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cabecera(BuildContext context, Order pedido) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          PresionEscala(
            escala: AppMovimiento.escalaPresionChica,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(LucideIcons.chevronLeft,
                    size: 16, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.numero,
                    style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(fechaCorta(pedido.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          // Llega volando desde la tarjeta de «Mis Pedidos».
          EstadoPedidoHero(pedido: pedido),
        ],
      ),
    );
  }

  /// Los bloques entran de arriba abajo una sola vez, después de [espera]
  /// (a que la página aterrice). Cada bloque lleva su Key: la tarjeta «va en
  /// camino» puede aparecer o irse con un refresco y no debe mover el estado
  /// de los de abajo. Los escalones se calculan en cada build, pero cada
  /// bloque solo lee el suyo al montarse.
  Widget _contenido(Order pedido, Duration espera) {
    const espacio = SizedBox(height: 12);
    var orden = 2;
    final ordenEnCamino = orden;
    if (_vm.vaEnCamino) orden++;
    final ordenInfo = orden++;
    final ordenProductos = orden++;
    final ordenResumen = orden++;
    final ordenCancelar = orden;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntradaSuave(
          key: const ValueKey('detalle-estado'),
          retraso: espera,
          escalaInicial: 0.96,
          child: _estadoEnGrande(pedido, espera),
        ),
        const SizedBox(height: 16),
        EntradaSuave(
          key: const ValueKey('detalle-linea'),
          orden: 1,
          retraso: espera,
          // La línea empieza a llenarse cuando su bloque ya se ve.
          child: DetallePedidoTimeline(
            viewModel: _vm,
            retraso: espera + AppMovimiento.rapida,
          ),
        ),
        // Si el pedido sale (o deja de ir) en camino con la pantalla
        // abierta, la tarjeta abre (o cierra) su espacio sin empujar de
        // golpe lo de abajo.
        EntradaSuave(
          key: const ValueKey('detalle-en-camino'),
          orden: ordenEnCamino,
          retraso: espera,
          child: Aparicion(
            visible: _vm.vaEnCamino,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _enCamino(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        EntradaSuave(
          key: const ValueKey('detalle-info'),
          orden: ordenInfo,
          retraso: espera,
          child: TarjetaDetalle(
            titulo: 'Información del pedido',
            child: Column(children: [
              FilaInfo(
                  icono: LucideIcons.tag, etiqueta: 'Número', valor: pedido.numero),
              const DivisorDetalle(),
              FilaInfo(
                  icono: LucideIcons.calendar,
                  etiqueta: 'Fecha',
                  valor: fechaConHora(pedido.createdAt)),
              if (pedido.horarioRecogida case final horario?) ...[
                const DivisorDetalle(),
                FilaInfo(
                    icono: LucideIcons.clock,
                    etiqueta: 'Horario de recogida',
                    valor: horario),
              ],
              const DivisorDetalle(),
              const FilaInfo(
                  icono: LucideIcons.store,
                  etiqueta: 'Sucursal',
                  valor: 'Principal — Huejutla de Reyes'),
              if (pedido.notas case final notas? when notas.isNotEmpty) ...[
                const DivisorDetalle(),
                FilaInfo(
                    icono: LucideIcons.stickyNote, etiqueta: 'Notas', valor: notas),
              ],
            ]),
          ),
        ),
        espacio,
        EntradaSuave(
          key: const ValueKey('detalle-productos'),
          orden: ordenProductos,
          retraso: espera,
          child: TarjetaDetalle(
            titulo: 'Productos (${pedido.items.length})',
            child: Column(children: [
              for (final (i, item) in pedido.items.indexed) ...[
                if (i > 0) const DivisorDetalle(),
                RenglonProducto(item: item),
              ],
            ]),
          ),
        ),
        espacio,
        EntradaSuave(
          key: const ValueKey('detalle-resumen'),
          orden: ordenResumen,
          retraso: espera,
          child: TarjetaDetalle(
            titulo: 'Resumen de pago',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(
                  '\$${pedido.total.toStringAsFixed(0)} MXN',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.pierVerde),
                ),
              ],
            ),
          ),
        ),
        EntradaSuave(
          key: const ValueKey('detalle-cancelar'),
          orden: ordenCancelar,
          retraso: espera,
          child: _cancelacion(pedido),
        ),
      ],
    );
  }

  /// «Cancelar pedido», solo mientras nadie haya tomado el pedido
  /// (pendiente/listo, regla del backend). Cuando deja de poderse (se
  /// canceló, o un repartidor lo tomó), el botón se desvanece tal como
  /// estaba (no regresa a «Cancelar pedido» al irse) y su espacio se cierra.
  Widget _cancelacion(Order pedido) {
    return TamanoSuave(
      child: CambioAnimado(
        child: pedido.esCancelablePorCliente
            ? KeyedSubtree(
                key: const ValueKey('cancelable'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: BotonCancelarPedido(
                    cancelando: _vm.cancelando,
                    onCancelar: () => unawaited(_confirmarCancelacion()),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('no-cancelable')),
      ),
    );
  }

  /// El estado en grande. Si cambia con la pantalla abierta, el fondo y el
  /// borde pasan al color nuevo, el ícono cambia con un rebote, los textos
  /// con un fundido y el bloque ajusta su alto. Al llegar, el ícono da un
  /// pequeño pop un instante después que su bloque.
  Widget _estadoEnGrande(Order pedido, Duration espera) {
    final color = pedido.statusColor;
    final mensaje = _vm.mensajeEstado;
    return AnimatedContainer(
      duration: AppMovimiento.duracion(context, AppMovimiento.media),
      curve: AppMovimiento.curvaEstandar,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: TamanoSuave(
        alineacion: Alignment.topCenter,
        child: Column(
          children: [
            EntradaSuave(
              orden: 1,
              retraso: espera,
              escalaInicial: 0.85,
              desplazamiento: Offset.zero,
              child: CambioAnimado(
                tipo: TipoCambio.escalar,
                alineacion: Alignment.center,
                child: Icon(iconoEstadoPedido(pedido.status),
                    key: ValueKey<OrderStatus>(pedido.status),
                    size: 52,
                    color: color),
              ),
            ),
            const SizedBox(height: 10),
            CambioAnimado(
              alineacion: Alignment.center,
              child: Text(pedido.statusText,
                  key: ValueKey<String>(pedido.statusText),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 6),
            CambioAnimado(
              alineacion: Alignment.center,
              child: Text(mensaje,
                  key: ValueKey<String>(mensaje),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  /// Repartidor en camino (solo domicilio + en camino). El Lottie se repite
  /// mientras la tarjeta está a la vista, en su propia capa para no repintar
  /// la tarjeta; con movimiento reducido queda quieto.
  Widget _enCamino() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        RepaintBoundary(
          child: Lottie.asset(
            'assets/lottie/delivery.json',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
            animate: !AppMovimiento.reducido(context),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
              '¡Tu pedido va en camino!\nEl repartidor está por llegar.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ]),
    );
  }
}
