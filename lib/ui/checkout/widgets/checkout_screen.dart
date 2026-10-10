// lib/ui/checkout/widgets/checkout_screen.dart
//
// Checkout (MVVM, Fase 4): la vista pinta lo que expone CheckoutViewModel y
// reacciona al Command del pago. Aquí solo quedan los diálogos (calendario,
// borrar dirección, pedido "por confirmar"), la hoja de dirección, los
// avisos y la navegación al pedido confirmado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_entrega.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_resumen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/direccion_form_sheet.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.viewModel});

  /// Para pruebas; si es null la pantalla crea el suyo.
  final CheckoutViewModel? viewModel;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final CheckoutViewModel _vm = widget.viewModel ??
      CheckoutViewModel(
        configRepo: context.read(),
        direccionesRepo: context.read(),
        pagosRepo: context.read(),
        pasarela: context.read(),
        totalCarrito: () => context.read<CartProvider>().totalAmount,
        confirmarPorConfirmar: _avisarPedidoPorConfirmar,
      );

  @override
  void initState() {
    super.initState();
    _vm.pagar.addListener(_alTerminarPago);
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.pagar.removeListener(_alTerminarPago);
    _vm.dispose();
    super.dispose();
  }

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? AppColors.error : AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Reacciona al resultado del Command de pago.
  void _alTerminarPago() {
    final pagar = _vm.pagar;
    if (pagar.corriendo || !mounted) return;
    final error = pagar.error;
    final resultado = pagar.resultado;
    if (error == null && resultado == null) return;
    pagar.limpiar();
    if (error != null) {
      _aviso('Error inesperado: $error', error: true);
      return;
    }
    switch (resultado!) {
      case PagoInterrumpido(:final aviso):
        if (aviso != null) _aviso(aviso, error: true);
      case PagoExitoso(:final pedido, :final total):
        unawaited(context.read<CartProvider>().clearCart());
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => OrderSuccessScreen(
              orderId: pedido.numero,
              pickupDate: DateFormat('dd/MM/yyyy').format(_vm.fecha!),
              pickupTime: _vm.hora!,
              total: total,
              esDomicilio: _vm.esDomicilio,
              direccionResumen: _vm.direccion?.lineaResumen,
              porConfirmar: pedido.porConfirmar,
            ),
          ),
        );
    }
  }

  Future<void> _elegirFecha() async {
    final now = DateTime.now();
    final initial = now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial,
      lastDate: now.add(const Duration(days: 30)),
      locale: const Locale('es'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.pierVerde,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) _vm.elegirFecha(picked);
  }

  Future<void> _abrirFormulario([DireccionCliente? editar]) async {
    final guardada = await mostrarFormularioDireccion(context, editar: editar);
    if (guardada != null && mounted) await _vm.alGuardarDireccion(guardada);
  }

  Future<void> _eliminarDireccion(DireccionCliente d) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${d.alias}"? Esta acción no se puede deshacer.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, elevation: 0),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final error = await _vm.eliminarDireccion(d);
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Aviso previo al cobro de un pedido programado "por confirmar": incluye
  /// productos sin existencias hoy y el personal debe aprobar la fecha.
  /// Devuelve true si el cliente decide continuar con el pago.
  Future<bool> _avisarPedidoPorConfirmar(List<String> faltantes) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.clock, color: AppColors.pierDoradoOscuro),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Pedido sujeto a confirmación',
                  style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
        content: Text(
          'Tu pedido es para otra fecha y hoy no hay existencias de: '
          '${faltantes.join(', ')}.\n\n'
          'Nuestro personal confirmará si podrá prepararlo para ese día. '
          'Si no fuera posible, tu pago se reembolsa completo.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.pierVerde),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar y pagar'),
          ),
        ],
      ),
    );
    return continuar == true;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // El total del botón cambia si cambia el carrito.
    context.select<CartProvider, double>((c) => c.totalAmount);

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(
        // Esta AppBar es blanca: título e iconos oscuros (el iconTheme del
        // tema gana sobre foregroundColor y dejaría invisible la flecha).
        title: const Text('Finalizar Pedido',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_vm, _vm.pagar]),
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_vm.abierto) const AvisoFueraDeServicio(),
              const TituloSeccion('Resumen del pedido'),
              CheckoutResumen(viewModel: _vm),
              const SizedBox(height: 24),
              const TituloSeccion('¿Cómo lo quieres?'),
              CheckoutModalidad(viewModel: _vm),
              const SizedBox(height: 24),
              if (_vm.esDomicilio)
                CheckoutDomicilio(
                  viewModel: _vm,
                  onElegirFecha: _elegirFecha,
                  onAgregar: _abrirFormulario,
                  onEditar: _abrirFormulario,
                  onEliminar: _eliminarDireccion,
                )
              else
                CheckoutRecoger(viewModel: _vm, onElegirFecha: _elegirFecha),
              const SizedBox(height: 24),
              const TituloSeccion('Método de pago'),
              const CheckoutMetodoPago(),
              if (_vm.errorPago != null) ...[
                const SizedBox(height: 12),
                AvisoErrorPago(_vm.errorPago!),
              ],
              const SizedBox(height: 24),
              NotaPedidosEspeciales(esDomicilio: _vm.esDomicilio),
              const SizedBox(height: 24),
              _botonPagar(),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.lock,
                        size: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    const Text('Pago cifrado y seguro con Stripe',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonPagar() {
    final corriendo = _vm.pagar.corriendo;
    final abierto = _vm.abierto;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        // Fuera de horario no se pueden crear pedidos.
        onPressed: (corriendo || !abierto) ? null : _vm.pagar.execute,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pierVerde,
          disabledBackgroundColor: AppColors.pierVerde.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: corriendo
            ? const SizedBox(
                height: 24, width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                abierto
                    ? 'Pagar  \$${_vm.totalConEnvio.toStringAsFixed(0)} MXN'
                    : 'Fuera de servicio',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }
}
