// lib/ui/checkout/widgets/checkout_screen.dart
//
// Checkout (MVVM, Fase 4): la vista pinta lo que expone CheckoutViewModel y
// reacciona al Command del pago. Aquí solo quedan los diálogos (calendario,
// borrar dirección, pedido "por confirmar"), la hoja de dirección, los
// avisos y la navegación al pedido confirmado.
//
// Movimiento: al llegar, los bloques suben en cascada mientras la página
// termina de deslizarse; recoger ↔ domicilio es un eje compartido (cada
// sección entra desde el lado de su tarjeta) y el alto se acomoda sin
// saltos; los totales cuentan, los avisos abren su espacio, la sección a la
// que le falta un dato se sacude junto con el aviso y el pedido pagado
// florece en su propia ruta de celebración.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/direccion_model.dart';
import 'package:pier_reposteria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_reposteria/ui/checkout/widgets/checkout_entrega.dart';
import 'package:pier_reposteria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_reposteria/ui/checkout/widgets/checkout_resumen.dart';
import 'package:pier_reposteria/ui/checkout/widgets/direccion_form_sheet.dart';
import 'package:pier_reposteria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_reposteria/ui/checkout/widgets/tamano_animado.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
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

  // Contadores que sacuden la sección a la que le falta un dato al pagar
  // (o el recuadro del error, si el mismo error se repite).
  int _sacudidaFecha = 0;
  int _sacudidaDireccion = 0;
  int _sacudidaError = 0;

  // El recuadro del error conserva su mensaje mientras se cierra (y con él
  // se sabe si el error que llega es el mismo de la vez anterior).
  String _ultimoErrorPago = '';

  // Tras un pago exitoso el carrito se vacía ANTES de navegar: el checkout
  // que la ruta de celebración tapa se queda con lo que se pagó.
  bool _congelado = false;
  double _totalCongelado = 0;

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
        if (aviso != null) {
          _sacudirSeccion();
          _aviso(aviso, error: true);
        }
      case PagoExitoso(:final pedido, :final total):
        // Se congela antes de vaciar el carrito (mismo orden de siempre:
        // vaciar y luego navegar).
        _congelado = true;
        _totalCongelado = _vm.totalConEnvio;
        unawaited(context.read<CartProvider>().clearCart());
        // La página de éxito florece sobre un fondo blanco que tapa el
        // checkout desde el primer cuadro.
        Navigator.pushReplacement(
          context,
          RutaCelebracion<void>(
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
        ).ignore();
    }
  }

  /// Si el pago se detuvo porque falta un dato, sacude la sección que lo
  /// pide (se deduce de lo que el ViewModel ya expone, en el mismo orden en
  /// que valida). Si el mismo error del pago se repite, sacude su recuadro.
  void _sacudirSeccion() {
    final direccion = _vm.direccion;
    final errorPago = _vm.errorPago;
    if (_vm.esDomicilio && (direccion == null || !direccion.tieneCobertura)) {
      setState(() => _sacudidaDireccion++);
    } else if (_vm.fecha == null || _vm.hora == null) {
      setState(() => _sacudidaFecha++);
    } else if (errorPago != null && errorPago == _ultimoErrorPago) {
      // Se compara con el último mensaje pintado y no con «el recuadro está
      // a la vista»: al reintentar, el ViewModel borra el error y el
      // recuadro se cierra mientras el backend contesta.
      setState(() => _sacudidaError++);
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
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) => EntradaDialogo(
        child: AlertDialog(
          title: const Text('Eliminar dirección'),
          content:
              Text('¿Eliminar "${d.alias}"? Esta acción no se puede deshacer.'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) => EntradaDialogo(
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.pierVerde),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar y pagar'),
            ),
          ],
        ),
      ),
    );
    return continuar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada (repinta la pantalla si cambia la paleta)
    // y el total del carrito (el del botón cambia si cambia el carrito).
    context
      ..watch<TemaProvider>()
      ..select<CartProvider, double>((c) => c.totalAmount);

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
        builder: (context, _) {
          final errorPago = _vm.errorPago;
          if (errorPago != null) _ultimoErrorPago = errorPago;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bloque(
                  0,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fuera de horario el aviso abre su espacio arriba.
                      Aparicion(
                        visible: !_vm.abierto,
                        child: const AvisoFueraDeServicio(),
                      ),
                      const TituloSeccion('Resumen del pedido'),
                      CheckoutResumen(viewModel: _vm, congelado: _congelado),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _bloque(
                  1,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloSeccion('¿Cómo lo quieres?'),
                      CheckoutModalidad(viewModel: _vm),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _bloque(2, _entrega()),
                const SizedBox(height: 24),
                _bloque(
                  3,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloSeccion('Método de pago'),
                      const CheckoutMetodoPago(),
                      // Un solo recuadro: abre su espacio al fallar el pago y
                      // lo cierra al reintentar. La sacudida va por fuera:
                      // el recuadro sale del árbol mientras se reintenta y
                      // el mismo error lo trae de vuelta sacudiéndose.
                      Sacudida(
                        disparo: _sacudidaError,
                        child: Aparicion(
                          visible: errorPago != null,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: AvisoErrorPago(_ultimoErrorPago),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _bloque(4, NotaPedidosEspeciales(esDomicilio: _vm.esDomicilio)),
                const SizedBox(height: 24),
                _bloque(
                  5,
                  Column(
                    children: [
                      _botonPagar(),
                      const SizedBox(height: 12),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.lock,
                                size: 13,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            const Text('Pago cifrado y seguro con Stripe',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Un bloque de la cascada de llegada: sube un poco y aparece una sola
  /// vez, cuando la página ya casi terminó de deslizarse.
  Widget _bloque(int orden, Widget hijo) => EntradaSuave(
        key: ValueKey('bloque-$orden'),
        orden: orden,
        retraso: AppMovimiento.trasEmpuje,
        child: hijo,
      );

  /// Recoger ↔ domicilio: eje compartido horizontal (domicilio llega desde
  /// la derecha, como su tarjeta; recoger desde la izquierda). El alto se
  /// acomoda sin empujar de golpe lo de abajo; la holgura deja ver las
  /// sombras y el deslizamiento lateral.
  Widget _entrega() {
    final domicilio = _vm.esDomicilio;
    return TamanoAnimado(
      duracion: AppMovimiento.media,
      holgura: AppMovimiento.distanciaLarga,
      child: CambioAnimado(
        tipo: TipoCambio.ejeX,
        direccion: domicilio ? 1 : -1,
        duracion: AppMovimiento.media,
        alineacion: AlignmentDirectional.topStart,
        child: KeyedSubtree(
          key: ValueKey(domicilio),
          child: domicilio
              ? CheckoutDomicilio(
                  viewModel: _vm,
                  onElegirFecha: _elegirFecha,
                  onAgregar: _abrirFormulario,
                  onEditar: _abrirFormulario,
                  onEliminar: _eliminarDireccion,
                  sacudidaFecha: _sacudidaFecha,
                  sacudidaDireccion: _sacudidaDireccion,
                )
              : CheckoutRecoger(
                  viewModel: _vm,
                  onElegirFecha: _elegirFecha,
                  sacudidaFecha: _sacudidaFecha,
                ),
        ),
      ),
    );
  }

  Widget _botonPagar() {
    final corriendo = _vm.pagar.corriendo;
    final total = _congelado ? _totalCongelado : _vm.totalConEnvio;
    const estilo = TextStyle(
        fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white);
    final Widget contenido;
    if (corriendo) {
      contenido = const SizedBox(
          key: ValueKey('pagando'),
          height: 24,
          width: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    } else {
      // El monto cuenta cuando cambia (p. ej. al sumar el envío); el texto
      // final es el de siempre, con sus dos espacios. Con la tienda cerrada
      // también se paga: el pedido es para otro día (#188).
      contenido = MontoAnimado(
        key: const ValueKey('pagar'),
        valor: total,
        formato: (v) => 'Pagar  \$${v.toStringAsFixed(0)} MXN',
        estilo: estilo,
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: corriendo ? null : _vm.pagar.execute,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pierVerde,
          disabledBackgroundColor: AppColors.pierVerde.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        // Etiqueta ↔ indicador dentro del MISMO botón: se cruzan con un pop.
        child: CambioAnimado(
          tipo: TipoCambio.escalar,
          alineacion: Alignment.center,
          child: contenido,
        ),
      ),
    );
  }
}
