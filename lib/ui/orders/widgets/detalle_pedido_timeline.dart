// lib/ui/orders/widgets/detalle_pedido_timeline.dart
//
// Línea de tiempo del detalle de un pedido: un círculo por paso y líneas
// entre ellos; lo completado se pinta en verde con una entrada escalonada.
// Si el pedido se canceló o no se pudo entregar, va un aviso en su lugar.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/orders/view_model/order_detail_view_model.dart';
import 'package:pier_pasteleria/ui/orders/widgets/estado_pedido.dart';

class DetallePedidoTimeline extends StatelessWidget {
  const DetallePedidoTimeline({required this.viewModel, super.key});

  final OrderDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.terminoMal) return _aviso();
    final pasos = viewModel.pasos;
    final actual = viewModel.pasoActual;
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
      child: Row(
        children: [
          for (var i = 0; i < pasos.length; i++)
            Expanded(
              child: _Paso(
                paso: pasos[i],
                indice: i,
                actual: actual,
                ultimo: i == pasos.length - 1,
              ),
            ),
        ],
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
/// Secuencia: el círculo [indice] entra a indice×300 ms y la línea hacia el
/// siguiente crece a indice×300+150 ms. Solo se anima lo completado.
class _Paso extends StatelessWidget {
  const _Paso({
    required this.paso,
    required this.indice,
    required this.actual,
    required this.ultimo,
  });

  final PasoPedido paso;
  final int indice;
  final int actual;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final hecho = indice <= actual;
    final esActual = indice == actual;

    Widget circulo = Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: hecho ? AppColors.pierVerde : Colors.grey[200],
        shape: BoxShape.circle,
        border: esActual
            ? Border.all(color: AppColors.pierVerde, width: 2.5)
            : null,
      ),
      child: hecho
          ? Icon(iconoEstadoPedido(paso.estado), size: 14, color: Colors.white)
          : null,
    );
    if (hecho) {
      circulo = circulo.animate().scale(
          begin: Offset.zero,
          end: const Offset(1, 1),
          delay: (indice * 300).ms,
          duration: 300.ms,
          curve: Curves.easeOutBack);
    }

    Widget etiqueta = Text(paso.etiqueta,
        style: TextStyle(
            fontSize: 9,
            fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
            color: hecho ? AppColors.pierVerde : Colors.grey[400]),
        textAlign: TextAlign.center);
    if (hecho) {
      etiqueta = etiqueta
          .animate()
          .fadeIn(delay: (indice * 300 + 120).ms, duration: 250.ms);
    }

    return Column(children: [
      Row(children: [
        if (indice > 0)
          Expanded(
            child: _segmento(
                verde: indice <= actual, delayMs: (indice - 1) * 300 + 150),
          ),
        circulo,
        if (!ultimo)
          Expanded(
            child: _segmento(
                verde: indice < actual, delayMs: indice * 300 + 150),
          ),
      ]),
      const SizedBox(height: 6),
      etiqueta,
    ]);
  }

  Widget _segmento({required bool verde, required int delayMs}) {
    final linea = Container(
      height: 2,
      color: verde ? AppColors.pierVerde : Colors.grey[200],
    );
    if (!verde) return linea;
    return linea.animate().scaleX(
        begin: 0,
        end: 1,
        alignment: Alignment.centerLeft,
        delay: delayMs.ms,
        duration: 200.ms,
        curve: Curves.easeOut);
  }
}
