// lib/presentation/screens/repartidor/entrega_detail_screen.dart
//
// Detalle de una entrega: cliente, dirección y resumen de cobro. Las acciones
// respetan el flujo del backend: asignada -> "Salir en camino" (en_camino) ->
// "Marcar entregado" (entregada). "Reportar" (fallida) está disponible en ambos.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/entrega_model.dart';
import '../../../data/providers/entregas_provider.dart';
import 'confirmar_entrega_screen.dart';
import 'reportar_fallo_sheet.dart';
import 'widgets/repartidor_ui.dart';

class EntregaDetailScreen extends StatefulWidget {
  final EntregaRepartidor entrega;
  const EntregaDetailScreen({super.key, required this.entrega});

  @override
  State<EntregaDetailScreen> createState() => _EntregaDetailScreenState();
}

class _EntregaDetailScreenState extends State<EntregaDetailScreen> {
  // Estado local: puede avanzar (asignada -> en_camino) sin salir de la pantalla.
  late EstadoEntrega _estado = widget.entrega.estado;
  bool _saliendo = false;

  EntregaRepartidor get entrega => widget.entrega;
  bool get _puedeAccionar =>
      _estado == EstadoEntrega.asignada || _estado == EstadoEntrega.enCamino;

  Future<void> _llamar(BuildContext context) async {
    final tel = entrega.direccion.telefonoContacto ?? entrega.clienteTelefono;
    if (tel == null) return;
    final uri = Uri.parse('tel:${tel.replaceAll(' ', '')}');
    if (!await launchUrl(uri) && context.mounted) {
      _snack(context, 'No se pudo abrir el marcador');
    }
  }

  Future<void> _whatsapp(BuildContext context) async {
    final tel = entrega.direccion.telefonoContacto ?? entrega.clienteTelefono;
    if (tel == null) return;
    final digits = tel.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      _snack(context, 'No se pudo abrir WhatsApp');
    }
  }

  void _snack(BuildContext context, String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.pierVerde : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // asignada -> en_camino. Se queda en la pantalla y actualiza el botón.
  Future<void> _salirEnCamino() async {
    setState(() => _saliendo = true);
    final res = await context
        .read<EntregasProvider>()
        .cambiarEstado(entrega.id, EstadoEntrega.enCamino);
    if (!mounted) return;
    setState(() => _saliendo = false);
    if (res['success'] == true) {
      setState(() => _estado = EstadoEntrega.enCamino);
      _snack(context, 'Vas en camino. Confirma cuando entregues.', ok: true);
    } else {
      _snack(context, res['message']?.toString() ?? 'No se pudo actualizar');
    }
  }

  Future<void> _marcarEntregado(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmarEntregaScreen(entrega: entrega),
      ),
    );
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _reportarProblema(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportarFalloSheet(entrega: entrega),
    );
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tieneTelefono =
        (entrega.direccion.telefonoContacto ?? entrega.clienteTelefono) != null;

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(title: Text(entrega.numero)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _clienteCard(),
            const SizedBox(height: 16),
            _direccionCard(context, tieneTelefono),
            const SizedBox(height: 16),
            _resumenCard(),
          ],
        ),
      ),
      bottomNavigationBar: _puedeAccionar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saliendo
                            ? null
                            : () => _reportarProblema(context),
                        icon: const Icon(LucideIcons.triangleAlert, size: 18),
                        label: const Text('Reportar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _estado == EstadoEntrega.asignada
                          ? ElevatedButton.icon(
                              onPressed:
                                  _saliendo ? null : () => _salirEnCamino(),
                              icon: _saliendo
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(LucideIcons.truck,
                                      size: 18),
                              label: Text(
                                  _saliendo ? 'Actualizando…' : 'Salir en camino'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.estadoEnCamino,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _marcarEntregado(context),
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 18),
                              label: const Text('Marcar entregado'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _card({required Widget child}) => Container(
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

  Widget _clienteCard() => _card(
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
                EstadoEntregaChip(estado: _estado),
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

  Widget _direccionCard(BuildContext context, bool tieneTelefono) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(LucideIcons.mapPin, color: AppColors.pierVerde, size: 22),
                SizedBox(width: 8),
                Text(
                  'Dirección de entrega',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (entrega.direccion.isEmpty)
              const Text(
                'Sin dirección registrada',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              )
            else ...[
              if (entrega.direccion.alias != null)
                Text(
                  entrega.direccion.alias!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              if (entrega.direccion.calleNumero != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entrega.direccion.calleNumero!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              if (entrega.direccion.colonia != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    entrega.direccion.colonia!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (entrega.direccion.referencias != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Ref: ${entrega.direccion.referencias!}',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
            ],
            if (tieneTelefono) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _llamar(context),
                      icon: const Icon(LucideIcons.phone, size: 18),
                      label: const Text('Llamar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _whatsapp(context),
                      icon: const Icon(LucideIcons.messageCircle, size: 18),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _resumenCard() {
    final subtotal = entrega.total - entrega.costoEnvio;
    return _card(
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
          _fila('Subtotal', formatMoneyMxn(subtotal)),
          const SizedBox(height: 8),
          _fila('Costo de envío', formatMoneyMxn(entrega.costoEnvio),
              muted: true),
          const Divider(height: 24),
          _fila(
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
              color: (entrega.esEfectivo
                      ? AppColors.pierDorado
                      : AppColors.pierVerde)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  entrega.esEfectivo
                      ? LucideIcons.banknote
                      : LucideIcons.creditCard,
                  size: 22,
                  color: entrega.esEfectivo
                      ? AppColors.pierDoradoOscuro
                      : AppColors.pierVerde,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Método: ${entrega.esEfectivo ? 'Efectivo' : 'Tarjeta'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        entrega.esEfectivo
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

  Widget _fila(String label, String value,
      {bool bold = false, bool muted = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: muted ? AppColors.textSecondary : AppColors.textPrimary,
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
