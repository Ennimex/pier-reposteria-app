// lib/ui/repartidor/widgets/entrega_detail_partes.dart
//
// Tarjetas del detalle de una entrega: cliente (con el estado actual),
// dirección con «Cómo llegar», «Llamar» y «WhatsApp», y resumen de cobro.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';

/// Tarjeta blanca con sombra suave.
class TarjetaDetalle extends StatelessWidget {
  const TarjetaDetalle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Número, estado y datos del cliente.
class ClienteCard extends StatelessWidget {
  const ClienteCard({required this.entrega, required this.estado, super.key});

  final EntregaRepartidor entrega;

  /// Estado actual (puede haber avanzado desde que se abrió el detalle).
  final EstadoEntrega estado;

  @override
  Widget build(BuildContext context) {
    return TarjetaDetalle(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entrega.numero,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              EstadoEntregaChip(estado: estado),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              InicialesAvatar(
                iniciales: entrega.iniciales,
                size: 52,
                background: AppColors.pierDorado.withValues(alpha: 0.25),
                foreground: AppColors.pierDoradoOscuro,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entrega.clienteNombreCompleto,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (entrega.clienteTelefono != null)
                      Text(
                        entrega.clienteTelefono!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dirección de entrega con sus botones de navegación y contacto.
class DireccionCard extends StatelessWidget {
  const DireccionCard({
    required this.direccion,
    required this.onComoLlegar,
    super.key,
    this.onLlamar,
    this.onWhatsapp,
  });

  final DireccionEntrega direccion;
  final VoidCallback onComoLlegar;

  /// Null si no hay teléfono: no se muestran «Llamar» ni «WhatsApp».
  final VoidCallback? onLlamar;
  final VoidCallback? onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final d = direccion;
    return TarjetaDetalle(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, color: AppColors.pierVerde, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dirección de entrega',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (d.isEmpty)
            const Text(
              'Sin dirección registrada',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            )
          else ...[
            if (d.alias != null)
              Text(
                d.alias!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            if (d.calleNumero != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  d.calleNumero!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            if (d.colonia != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  d.colonia!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (d.referencias != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ref: ${d.referencias!}',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onComoLlegar,
                icon: const Icon(LucideIcons.navigation,
                    color: Colors.white, size: 18),
                label: Text(
                    d.tieneCoordenadas ? 'Cómo llegar (GPS)' : 'Cómo llegar',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.estadoEnCamino,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          if (onLlamar != null && onWhatsapp != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BotonContacto(
                    icono: LucideIcons.phone,
                    texto: 'Llamar',
                    onPressed: onLlamar!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BotonContacto(
                    icono: LucideIcons.messageCircle,
                    texto: 'WhatsApp',
                    onPressed: onWhatsapp!,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BotonContacto extends StatelessWidget {
  const _BotonContacto({
    required this.icono,
    required this.texto,
    required this.onPressed,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(
          color: AppColors.textSecondary.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// Subtotal, envío, total a cobrar, notas del cliente y método de pago.
class ResumenCard extends StatelessWidget {
  const ResumenCard({required this.entrega, super.key});

  final EntregaRepartidor entrega;

  @override
  Widget build(BuildContext context) {
    final subtotal = entrega.total - entrega.costoEnvio;
    final efectivo = entrega.esEfectivo;
    return TarjetaDetalle(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del pedido',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _Fila('Subtotal', formatMoneyMxn(subtotal)),
          const SizedBox(height: 8),
          _Fila('Costo de envío', formatMoneyMxn(entrega.costoEnvio),
              muted: true),
          const Divider(height: 24),
          _Fila(
            'Total a cobrar',
            formatMoneyMxn(entrega.total),
            bold: true,
            valueColor: AppColors.pierVerde,
          ),
          if (entrega.notas != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.pierArena,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notas del cliente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entrega.notas!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (efectivo ? AppColors.pierDorado : AppColors.pierVerde)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  efectivo ? LucideIcons.banknote : LucideIcons.creditCard,
                  size: 22,
                  color: efectivo
                      ? AppColors.pierDoradoOscuro
                      : AppColors.pierVerde,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Método: ${efectivo ? 'Efectivo' : 'Tarjeta'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        efectivo
                            ? 'Cobra en efectivo al entregar'
                            : 'Pagado en la app',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(
    this.label,
    this.value, {
    this.bold = false,
    this.muted = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ??
                (muted ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
