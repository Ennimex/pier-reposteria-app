// lib/ui/orders/widgets/detalle_pedido_timeline.dart
//
// Línea de tiempo del detalle de un pedido: un círculo por paso y líneas
// entre ellos. Se llena como una manga pastelera: el verde corre de paso en
// paso hasta el actual, cada círculo se llena con un pequeño rebote cuando
// el verde lo alcanza y, al final, un halo late dos veces en el paso actual.
// Si el estado avanza con la pantalla abierta, el verde sigue desde donde
// iba. Si el pedido se canceló o no se pudo entregar, va un aviso en su
// lugar (cambia con un fundido a través).
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/orders/view_model/order_detail_view_model.dart';
import 'package:pier_reposteria/ui/orders/widgets/estado_pedido.dart';
import 'package:pier_reposteria/ui/orders/widgets/movimiento_pedidos.dart';

class DetallePedidoTimeline extends StatelessWidget {
  const DetallePedidoTimeline({
    required this.viewModel,
    this.retraso = Duration.zero,
    super.key,
  });

  final OrderDetailViewModel viewModel;

  /// Espera antes del primer llenado (a que la página y el bloque lleguen).
  final Duration retraso;

  /// Antes del primer círculo el relleno recorre este tramo en blanco: así
  /// el primer círculo también se llena (con rebote) en lugar de aparecer
  /// ya verde.
  static const double _entrada = 0.4;

  @override
  Widget build(BuildContext context) {
    // La línea y el aviso tienen distinto alto: el espacio se ajusta con
    // suavidad y lo de abajo sube sin saltar.
    return TamanoSuave(
      child: CambioAnimado(
        tipo: TipoCambio.atravesar,
        child: viewModel.terminoMal
            ? KeyedSubtree(key: const ValueKey('aviso'), child: _aviso())
            : KeyedSubtree(key: const ValueKey('linea'), child: _linea()),
      ),
    );
  }

  Widget _linea() {
    final pasos = viewModel.pasos;
    final actual = viewModel.pasoActual;
    // Hasta dónde llega el verde: el círculo del paso actual (nada si el
    // estado no está en la línea).
    final meta = actual < 0 ? 0.0 : actual + _entrada;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
      // El relleno repinta la fila en cada cuadro (hasta 1.1 s más los
      // rebotes): en su propia capa, para no repintar con ella toda la
      // página del detalle (tarjetas y sombras).
      child: RepaintBoundary(
        child: ProgresoAnimado(
          valor: meta,
          retraso: retraso,
          // 220 ms por paso, entre 220 ms y 1.1 s en total.
          duracion:
              Duration(milliseconds: (220 * (actual + 1)).clamp(220, 1100)),
          builder: (context, avance, _) {
            final cabeza = avance - _entrada;
            return Row(
              children: [
                for (var i = 0; i < pasos.length; i++)
                  Expanded(
                    child: _Paso(
                      paso: pasos[i],
                      indice: i,
                      actual: actual,
                      ultimo: i == pasos.length - 1,
                      cabeza: cabeza,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _aviso() {
    final esFallo = viewModel.pedido.status == OrderStatus.deliveryFailed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(esFallo ? LucideIcons.circleAlert : LucideIcons.circleX,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Text(esFallo ? 'No pudimos entregar el pedido' : 'Pedido cancelado',
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Un paso: círculo con su ícono, las líneas a los lados y la etiqueta.
/// [cabeza] es hasta dónde llegó el verde, en pasos (0 = el centro del
/// primer círculo, 1 = el del segundo…): la mitad de línea que entra a este
/// círculo se llena de cabeza = indice − ½ a indice, el círculo se llena al
/// alcanzarlo y la mitad que sale, de indice a indice + ½.
class _Paso extends StatelessWidget {
  const _Paso({
    required this.paso,
    required this.indice,
    required this.actual,
    required this.ultimo,
    required this.cabeza,
  });

  final PasoPedido paso;
  final int indice;
  final int actual;
  final bool ultimo;
  final double cabeza;

  // Cuánto de una mitad de línea está lleno (0 a 1). Al final del relleno
  // la cuenta en punto flotante deja restos como 0.9999999: se redondea
  // para que la línea quede exactamente llena.
  static double _tramo(double avance) {
    final lleno = clampDouble(avance, 0, 1);
    if (lleno > 0.999) return 1;
    return lleno < 0.001 ? 0 : lleno;
  }

  @override
  Widget build(BuildContext context) {
    final esActual = indice == actual;
    final alcanzado = cabeza >= indice - 0.001;
    // El círculo se llena con un rebote al alcanzarlo; si el verde
    // retrocede, se vacía sin rebote.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: alcanzado ? 1 : 0),
      duration: AppMovimiento.duracion(context, AppMovimiento.media),
      curve: alcanzado ? AppMovimiento.curvaRebote : AppMovimiento.curvaSalida,
      builder: (context, lleno, _) => Column(children: [
        Row(children: [
          if (indice > 0)
            Expanded(
              child: _Tramo(lleno: _tramo((cabeza - indice + 0.5) / 0.5)),
            ),
          _Circulo(
            icono: iconoEstadoPedido(paso.estado),
            lleno: lleno,
            esActual: esActual,
            conHalo: esActual && alcanzado,
          ),
          if (!ultimo)
            Expanded(
              child: _Tramo(lleno: _tramo((cabeza - indice) / 0.5)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(paso.etiqueta,
            style: TextStyle(
                fontSize: 9,
                fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
                color: Color.lerp(Colors.grey[400], AppColors.pierVerde,
                    clampDouble(lleno, 0, 1))),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Media línea entre dos círculos: gris de fondo y el verde que la recorre
/// desde el inicio según [lleno] (0 a 1).
class _Tramo extends StatelessWidget {
  const _Tramo({required this.lleno});

  final double lleno;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.grey.shade200),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: lleno,
            child: ColoredBox(color: AppColors.pierVerde),
          ),
        ],
      ),
    );
  }
}

/// Círculo de un paso: gris mientras el verde no llega; al alcanzarlo se
/// llena de verde desde el centro (con el rebote de [lleno], que pasa un
/// poco de 1) junto con su ícono. El del paso actual lleva el halo.
class _Circulo extends StatelessWidget {
  const _Circulo({
    required this.icono,
    required this.lleno,
    required this.esActual,
    required this.conHalo,
  });

  final IconData icono;
  final double lleno;
  final bool esActual;

  /// Si el halo ya puede latir (el verde llegó al paso actual).
  final bool conHalo;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (esActual) _HaloActual(activo: conHalo),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          if (lleno > 0)
            Transform.scale(
              scale: lleno,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.pierVerde,
                  shape: BoxShape.circle,
                  border: esActual
                      ? Border.all(color: AppColors.pierVerde, width: 2.5)
                      : null,
                ),
                child: Center(
                  child: Icon(icono, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «Aquí va tu pedido»: detrás del círculo del paso actual se abre un aro
/// que se apaga, dos veces, cuando el verde termina de llegar (y el círculo
/// su rebote). Pintado en su propia capa, sin cambiar el layout; termina
/// solo. Con movimiento reducido no late.
class _HaloActual extends StatefulWidget {
  const _HaloActual({required this.activo});

  /// Pasa a true cuando el verde alcanza el paso: entonces late.
  final bool activo;

  @override
  State<_HaloActual> createState() => _HaloActualState();
}

class _HaloActualState extends State<_HaloActual>
    with SingleTickerProviderStateMixin {
  // Primero termina el rebote del círculo (AppMovimiento.media, el mismo
  // de _Paso); luego, dos latidos con el ritmo de los rellenos.
  static const Duration _espera = AppMovimiento.media;
  static const Duration _latido = AppMovimiento.relleno;

  late final AnimationController _control;
  late final double _inicio;

  @override
  void initState() {
    super.initState();
    final total = _espera + _latido * 2;
    _inicio = _espera.inMicroseconds / total.inMicroseconds;
    _control = AnimationController(vsync: this, duration: total);
    if (widget.activo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _latir();
      });
    }
  }

  @override
  void didUpdateWidget(_HaloActual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activo && !oldWidget.activo) _latir();
  }

  void _latir() {
    if (AppMovimiento.reducido(context)) return;
    _control.forward(from: 0).ignore();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PintorHalo(
            avance: _control,
            inicio: _inicio,
            color: AppColors.pierVerde,
          ),
        ),
      ),
    );
  }
}

class _PintorHalo extends CustomPainter {
  _PintorHalo({
    required this.avance,
    required this.inicio,
    required this.color,
  }) : super(repaint: avance);

  final Animation<double> avance;

  /// Fracción de la animación que es espera (sin aro).
  final double inicio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final valor = avance.value;
    if (valor <= inicio || valor >= 1 || size.isEmpty) return;
    // Dos latidos seguidos: cada uno abre el aro de 1 a 1.8 veces el
    // círculo mientras se adelgaza y se apaga.
    final t = ((valor - inicio) / (1 - inicio) * 2) % 1;
    final abierto = AppMovimiento.curvaEntrada.transform(t);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 * (1 + 0.8 * abierto),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - t) + 0.5
        ..color = color.withValues(alpha: 0.35 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_PintorHalo oldDelegate) =>
      oldDelegate.inicio != inicio || oldDelegate.color != color;
}
