// lib/ui/repartidor/widgets/entregas_tarjetas.dart
//
// Tarjetas de la pestaña «Mis entregas»: título de sección con contador,
// entrega en curso (abre el detalle) y pedido del pool con «Tomar entrega».
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';

/// Abre el detalle de [entrega]; lo que cambie ahí recarga el panel.
Future<bool?> abrirEntrega(
  BuildContext context,
  EntregaRepartidor entrega,
  RepartidorViewModel viewModel,
) =>
    Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => EntregaDetailScreen(
          entrega: entrega,
          alCambiar: viewModel.recargar,
        ),
      ),
    );

/// Número de pedido en Playfair (tarjetas del panel).
class NumeroPedido extends StatelessWidget {
  const NumeroPedido(this.numero, {super.key, this.tamano = 18});

  final String numero;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Text(
      numero,
      style: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: tamano,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Monto en verde y negritas.
class MontoVerde extends StatelessWidget {
  const MontoVerde(this.monto, {super.key});

  final double monto;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatMoneyMxn(monto),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.pierVerde,
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.title, {required this.count, super.key});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.pierVerde,
              ),
            ),
          ),
      ],
    );
  }
}

/// Entrega en curso; al tocarla abre su detalle.
class EntregaCard extends StatelessWidget {
  const EntregaCard({
    required this.entrega,
    required this.viewModel,
    super.key,
  });

  final EntregaRepartidor entrega;
  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => abrirEntrega(context, entrega, viewModel),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pierDorado.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: NumeroPedido(entrega.numero)),
                EstadoEntregaChip(estado: entrega.estado),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              entrega.clienteNombreCompleto,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entrega.direccion.colonia ?? 'Sin colonia',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: IconoTexto(
                    icono: LucideIcons.clock,
                    texto: formatHorarioEntrega(entrega.horarioEntrega),
                    tamanoIcono: 18,
                    separacion: 6,
                    unaLinea: true,
                  ),
                ),
                const SizedBox(width: 8),
                if (entrega.metodoPago != null) ...[
                  _MetodoPago(efectivo: entrega.esEfectivo),
                  const SizedBox(width: 10),
                ],
                MontoVerde(entrega.total),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetodoPago extends StatelessWidget {
  const _MetodoPago({required this.efectivo});

  final bool efectivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        efectivo ? 'Efectivo' : 'Tarjeta',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Pedido del pool con botón para tomarlo.
class DisponibleCard extends StatelessWidget {
  const DisponibleCard({
    required this.pedido,
    required this.viewModel,
    super.key,
  });

  final PedidoDisponible pedido;
  final RepartidorViewModel viewModel;

  Future<void> _aceptar(BuildContext context) async {
    final resultado = await viewModel.aceptar(pedido);
    if (!context.mounted) return;
    mostrarAviso(context, resultado.mensaje, ok: resultado.ok);
  }

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final aceptando = viewModel.aceptando(p);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pierVerde.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: NumeroPedido(p.numero)),
              MontoVerde(p.total),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.clienteNombreCompleto,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          IconoTexto(
            icono: LucideIcons.mapPin,
            texto: p.direccion.colonia ?? 'Sin colonia',
            tamanoTexto: 15,
          ),
          if (p.horarioEntrega != null) ...[
            const SizedBox(height: 4),
            IconoTexto(
              icono: LucideIcons.clock,
              texto: formatHorarioEntrega(p.horarioEntrega),
              unaLinea: true,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: aceptando ? null : () => _aceptar(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: IconoCargando(
                icono: LucideIcons.check,
                cargando: aceptando,
                tamano: 20,
                color: Colors.white,
              ),
              label: Text(aceptando ? 'Tomando…' : 'Tomar entrega'),
            ),
          ),
        ],
      ),
    );
  }
}
