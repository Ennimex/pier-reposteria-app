// lib/ui/checkout/widgets/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/utils/config_format.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _configRepo = ConfiguracionRepository();
  final _direccionesRepo = DireccionesRepository();
  final _pagosRepo = PagosRepository();

  // pickup | domicilio
  String _tipoEntrega = 'pickup';

  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;
  String? _errorMsg;

  // Pago YA cobrado en Stripe cuya confirmación al backend falló: al volver
  // a presionar "Pagar" se reintenta SOLO la confirmación (nunca se vuelve a
  // cobrar). Evita el doble cobro si la red falla justo tras pagar.
  String? _pendingIntentId;
  double? _pendingTotal;

  // Domicilio
  List<DireccionCliente> _direcciones = [];
  DireccionCliente? _selectedDireccion;
  bool _loadingDirecciones = false;

  String _direccionSucursal = BusinessInfo.direccion;

  final List<String> _weekdaySlots = [
    '09:00 - 10:00', '10:00 - 11:00', '11:00 - 12:00',
    '12:00 - 13:00', '13:00 - 14:00', '14:00 - 15:00',
    '15:00 - 16:00', '16:00 - 17:00', '17:00 - 18:00', '18:00 - 19:00',
  ];

  final List<String> _weekendSlots = [
    '09:00 - 10:00', '10:00 - 11:00', '11:00 - 12:00',
    '12:00 - 13:00', '13:00 - 14:00', '14:00 - 15:00',
  ];

  List<String> get _currentTimeSlots {
    if (_selectedDate == null) return _weekdaySlots;
    final wd = _selectedDate!.weekday;
    return (wd == DateTime.saturday || wd == DateTime.sunday)
        ? _weekendSlots
        : _weekdaySlots;
  }

  bool get _esDomicilio => _tipoEntrega == 'domicilio';

  double get _costoEnvio =>
      _esDomicilio && _selectedDireccion?.tarifa != null
          ? _selectedDireccion!.tarifa!
          : 0.0;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    _cargarDirecciones();
  }

  Future<void> _cargarConfiguracion() async {
    final result =
        await _configRepo.seccion('contacto');
    if (!mounted) return;
    if (result['success'] == true) {
      final config = result['config'] as Map<String, dynamic>? ?? {};
      // El backend guarda la dirección como JSON (JSON.stringify); formatearla
      // para no mostrar el objeto crudo en "Sucursal Principal".
      final dir = formatearDireccion(config['direccion'],
          fallback: BusinessInfo.direccion);
      if (dir.isNotEmpty) {
        setState(() => _direccionSucursal = dir);
      }
    }
  }

  Future<void> _cargarDirecciones() async {
    setState(() => _loadingDirecciones = true);
    final result = await _direccionesRepo.listar();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['direcciones'] ?? [];
      final lista = (data as List)
          .map((j) => DireccionCliente.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() {
        _direcciones = lista;
        // Preseleccionar la primera con cobertura, si el usuario ya eligió domicilio.
        _selectedDireccion ??= lista.where((d) => d.tieneCobertura).isNotEmpty
            ? lista.firstWhere((d) => d.tieneCobertura)
            : null;
      });
    }
    if (mounted) setState(() => _loadingDirecciones = false);
  }

  Future<void> _abrirAgregarDireccion([DireccionCliente? editar]) async {
    final guardada = await showModalBottomSheet<DireccionCliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AgregarDireccionSheet(editar: editar),
    );
    if (guardada != null && mounted) {
      await _cargarDirecciones();
      if (mounted) {
        setState(() {
          _selectedDireccion = _direcciones.firstWhere(
            (d) => d.id == guardada.id,
            orElse: () => guardada,
          );
        });
      }
    }
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
            child: Text('Cancelar',
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
    );
    if (confirmar != true || !mounted) return;

    final result = await _direccionesRepo.eliminar(d.id);
    if (!mounted) return;
    if (result['success'] == true) {
      if (_selectedDireccion?.id == d.id) {
        // La preselección de _cargarDirecciones elegirá otra con cobertura.
        setState(() => _selectedDireccion = null);
      }
      await _cargarDirecciones();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(result['message']?.toString() ?? 'No se pudo eliminar'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _selectDate() async {
    if (!mounted) return;
    try {
      final now = DateTime.now();
      final initial = now.add(const Duration(days: 1));
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: initial,
        lastDate: now.add(const Duration(days: 30)),
        locale: const Locale('es', ''),
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
      if (picked != null && mounted) {
        setState(() {
          _selectedDate = picked;
          final wd = picked.weekday;
          final isWeekend =
              wd == DateTime.saturday || wd == DateTime.sunday;
          if (isWeekend &&
              _selectedTime != null &&
              !_weekendSlots.contains(_selectedTime)) {
            _selectedTime = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error al abrir el selector de fecha: $e');
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Aviso previo al cobro de un pedido programado "por confirmar": incluye
  /// productos sin existencias hoy y el personal debe aprobar la fecha.
  /// Devuelve true si el usuario decide continuar con el pago.
  Future<bool> _avisarPedidoPorConfirmar(List<String> faltantes) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.clock, color: AppColors.pierDoradoOscuro),
            SizedBox(width: 10),
            Expanded(
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
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.pierVerde),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar y pagar'),
          ),
        ],
      ),
    );
    return continuar == true;
  }

  Future<void> _processPayment() async {
    // Fuera de horario no se aceptan pedidos (defensa además del botón).
    if (!BusinessInfo.estaAbierto()) {
      _showSnack(
          'Estamos fuera de servicio. Horario: ${BusinessInfo.horario}',
          error: true);
      return;
    }
    // Validaciones según modalidad
    if (_esDomicilio) {
      if (_selectedDireccion == null) {
        _showSnack('Selecciona una dirección de entrega', error: true);
        return;
      }
      if (!_selectedDireccion!.tieneCobertura) {
        _showSnack(
            'Esa colonia no tiene cobertura de envío. Elige otra o recoge en sucursal.',
            error: true);
        return;
      }
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack(
          _esDomicilio
              ? 'Selecciona fecha y hora de entrega'
              : 'Selecciona fecha y hora de recolección',
          error: true);
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    // Horario elegido (se usa en crear-intent y en confirmar). Mandarlo en
    // crear-intent es clave: con fecha de recogida FUTURA el backend permite
    // pagar productos sin stock hoy (pedido "por confirmar").
    final horario =
        '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ${_selectedTime!.split(' - ').first}';

    try {
      String paymentIntentId;
      double totalBackend;

      if (_pendingIntentId != null) {
        // Ya hay un cobro hecho pendiente de confirmar: saltar directo a la
        // confirmación (no crear otro intent ni volver a abrir el sheet).
        paymentIntentId = _pendingIntentId!;
        totalBackend = _pendingTotal ?? cartTotalConEnvio();
      } else {
        // ── PASO 1: Crear Payment Intent (el backend calcula total + envío) ──
        final intentBody = <String, dynamic>{};
        if (_esDomicilio) {
          intentBody['tipo_entrega'] = 'domicilio';
          intentBody['direccion_id'] = _selectedDireccion!.id;
        } else {
          intentBody['horario_recogida'] = horario;
        }
        final intentResult =
            await _pagosRepo.crearIntent(intentBody);
        if (!mounted) return;

        if (intentResult['success'] != true) {
          setState(() =>
              _errorMsg = intentResult['message'] ?? 'Error al iniciar pago');
          _showSnack(_errorMsg!, error: true);
          return;
        }

        final clientSecret = intentResult['clientSecret']?.toString();
        final publishableKey = intentResult['publishableKey']?.toString();
        if (clientSecret == null || clientSecret.isEmpty ||
            publishableKey == null || publishableKey.isEmpty) {
          setState(() => _errorMsg =
              'Respuesta de pago incompleta. Intenta de nuevo.');
          _showSnack(_errorMsg!, error: true);
          return;
        }
        // Total autoritativo del backend (incluye envío)
        totalBackend =
            double.tryParse(intentResult['total']?.toString() ?? '') ??
                (cartTotalConEnvio());

        // Pedido programado con productos sin stock hoy: el backend lo acepta
        // pero queda sujeto a aprobación del personal. Avisar ANTES de cobrar.
        if (intentResult['por_confirmar'] == true) {
          final faltantes =
              (intentResult['productos_por_confirmar'] as List? ?? [])
                  .map((e) => e.toString())
                  .toList();
          final continuar = await _avisarPedidoPorConfirmar(faltantes);
          if (!mounted || !continuar) return;
        }

        // ── PASO 2: Inicializar Stripe ────────────────────────────────
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();

        // ── PASO 3: Sheet de pago ─────────────────────────────────────
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Pier Repostería',
            style: ThemeMode.light,
            appearance: PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: AppColors.pierVerde,
              ),
            ),
          ),
        );

        await Stripe.instance.presentPaymentSheet();

        // El cobro YA ocurrió: recordarlo por si la confirmación falla.
        paymentIntentId = clientSecret.split('_secret_').first;
        _pendingIntentId = paymentIntentId;
        _pendingTotal = totalBackend;
      }

      // ── PASO 4: Confirmar pedido en el backend (con reintentos) ────
      final confirmBody = <String, dynamic>{
        'payment_intent_id': paymentIntentId,
        'notas': '',
      };
      if (_esDomicilio) {
        confirmBody['horario_entrega'] = horario;
      } else {
        confirmBody['horario_recogida'] = horario;
      }

      // El backend limpia el carrito en la misma transacción que crea el
      // pedido, así que reintentar la confirmación NO puede duplicarlo.
      Map<String, dynamic> confirmResult = const {};
      for (var intento = 1; intento <= 3; intento++) {
        confirmResult =
            await _pagosRepo.confirmar(confirmBody);
        if (confirmResult['success'] == true) break;
        if (intento < 3) {
          await Future.delayed(Duration(seconds: 2 * intento));
        }
      }

      if (!mounted) return;

      if (confirmResult['success'] == true) {
        _pendingIntentId = null;
        _pendingTotal = null;
        final cart = Provider.of<CartProvider>(context, listen: false);
        final pedido =
            confirmResult['pedido'] as Map<String, dynamic>;
        cart.clearCart();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              orderId: pedido['numero']?.toString() ??
                  pedido['id']?.toString() ?? '',
              pickupDate:
                  DateFormat('dd/MM/yyyy').format(_selectedDate!),
              pickupTime: _selectedTime!,
              total: totalBackend,
              esDomicilio: _esDomicilio,
              direccionResumen: _selectedDireccion?.lineaResumen,
              porConfirmar: pedido['por_confirmar'] == true,
            ),
          ),
        );
      } else {
        // Si Stripe reporta que el pago NO se completó, liberar el pendiente
        // para que el siguiente intento empiece desde cero (nuevo cobro).
        final statusPago = confirmResult['status']?.toString();
        if (statusPago != null && statusPago != 'succeeded') {
          _pendingIntentId = null;
          _pendingTotal = null;
          setState(() => _errorMsg =
              confirmResult['message']?.toString() ??
                  'El pago no se completó. Intenta de nuevo.');
        } else {
          // El cobro sí ocurrió pero no pudimos registrar el pedido.
          setState(() => _errorMsg =
              'Tu pago fue procesado, pero no pudimos registrar el pedido '
              '(${confirmResult['message'] ?? 'sin conexión'}). NO pagues de '
              'nuevo: presiona "Pagar" otra vez y solo reintentaremos el registro.');
        }
        _showSnack(_errorMsg!, error: true);
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      final msg = e.error.localizedMessage ?? 'Pago cancelado';
      if (e.error.code != FailureCode.Canceled) {
        _showSnack(msg, error: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error inesperado: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double cartTotalConEnvio() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return cart.totalAmount + _costoEnvio;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final cart = Provider.of<CartProvider>(context);
    final totalConEnvio = cart.totalAmount + _costoEnvio;

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(
        // El titleTextStyle y el iconTheme del tema global son blancos
        // (AppBars verdes); esta AppBar es blanca, así que forzamos el color
        // oscuro en título Y iconos (el iconTheme del tema gana sobre
        // foregroundColor -> sin esto la flecha de regresar queda invisible).
        title: const Text('Finalizar Pedido',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── AVISO FUERA DE SERVICIO ───────────────────────────────
            if (!BusinessInfo.estaAbierto()) _buildFueraDeServicio(),

            // ── RESUMEN ───────────────────────────────────────────────
            _buildSectionTitle('Resumen del pedido'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  ...cart.items.values.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withValues(alpha: 0.06),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Text('${item.quantity}x',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pierVerde)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      item.tamano == 'grande'
                                          ? '${item.nombre} (Grande)'
                                          : item.nombre,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500)),
                                  if (item.tieneDescuento)
                                    Row(children: [
                                      Text(
                                        '\$${item.precio.toStringAsFixed(0)} c/u',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.pierVerde,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '\$${item.precioOriginal.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                                            decoration:
                                                TextDecoration.lineThrough),
                                      ),
                                    ]),
                                ],
                              ),
                            ),
                            Text(
                                '\$${item.subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  const Divider(height: 24),

                  if (cart.tieneDescuentos) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        Text(
                          '\$${cart.totalOriginal.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(LucideIcons.tag,
                              size: 14, color: AppColors.pierVerde),
                          const SizedBox(width: 6),
                          Text('Descuentos aplicados',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.pierVerde,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        Text(
                          '-\$${cart.totalAhorro.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    const SizedBox(height: 10),
                  ],

                  // ── Envío (solo domicilio) ──
                  if (_esDomicilio) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(LucideIcons.truck,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('Costo de envío',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        ]),
                        Text(
                          _selectedDireccion == null
                              ? '—'
                              : _selectedDireccion!.tieneCobertura
                                  ? '\$${_costoEnvio.toStringAsFixed(0)}'
                                  : 'Sin cobertura',
                          style: TextStyle(
                              color: _selectedDireccion?.tieneCobertura == false
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a Pagar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('\$${totalConEnvio.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── MODALIDAD DE ENTREGA ──────────────────────────────────
            _buildSectionTitle('¿Cómo lo quieres?'),
            Row(
              children: [
                Expanded(
                  child: _modalidadCard(
                    seleccionada: !_esDomicilio,
                    icon: LucideIcons.store,
                    titulo: 'Recoger',
                    sub: 'En sucursal',
                    onTap: () => setState(() => _tipoEntrega = 'pickup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modalidadCard(
                    seleccionada: _esDomicilio,
                    icon: LucideIcons.bike,
                    titulo: 'Domicilio',
                    sub: 'Envío a tu casa',
                    onTap: () => setState(() => _tipoEntrega = 'domicilio'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── SECCIÓN SEGÚN MODALIDAD ───────────────────────────────
            if (_esDomicilio) ..._buildDomicilioSection()
            else ..._buildPickupSection(),

            const SizedBox(height: 24),

            // ── MÉTODO DE PAGO ────────────────────────────────────────
            _buildSectionTitle('Método de pago'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(LucideIcons.creditCard,
                        color: AppColors.pierVerde, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tarjeta de crédito / débito',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Pago seguro con Stripe',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.lock,
                      color: AppColors.pierVerde, size: 20),
                ],
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(LucideIcons.circleAlert,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!,
                        style: TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── NOTA: PEDIDOS ESPECIALES ──────────────────────────────
            _buildNotaEspeciales(),
            const SizedBox(height: 24),

            // ── BOTÓN PAGAR ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Fuera de horario no se pueden crear pedidos.
                onPressed: (_isLoading || !BusinessInfo.estaAbierto())
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  disabledBackgroundColor:
                      AppColors.pierVerde.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24, width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        BusinessInfo.estaAbierto()
                            ? 'Pagar  \$${totalConEnvio.toStringAsFixed(0)} MXN'
                            : 'Fuera de servicio',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.lock,
                      size: 13, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text('Pago cifrado y seguro con Stripe',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── SECCIÓN PICKUP ──────────────────────────────────────────────────
  List<Widget> _buildPickupSection() => [
        _buildSectionTitle('¿Dónde recoges?'),
        Container(
          decoration: _cardDecoration(),
          child: ListTile(
            // Pin de ubicación animado (Lottie local, paleta Pier)
            leading: Lottie.asset(
              'assets/lottie/store_location.json',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            title: const Text(BusinessInfo.sucursal,
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_direccionSucursal),
            trailing: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppColors.pierVerde, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('¿Cuándo pasas?'),
        _buildFechaHora(),
      ];

  // ── SECCIÓN DOMICILIO ───────────────────────────────────────────────
  List<Widget> _buildDomicilioSection() => [
        _buildSectionTitle('Dirección de entrega'),
        if (_loadingDirecciones)
          Container(
            height: 90,
            decoration: _cardDecoration(),
            child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.pierVerde, strokeWidth: 2)),
          )
        else ...[
          ..._direcciones.map(_buildDireccionCard),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _abrirAgregarDireccion,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.pierVerde.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(LucideIcons.mapPinPlus,
                      color: AppColors.pierVerde, size: 20),
                  const SizedBox(width: 10),
                  Text('Agregar dirección',
                      style: TextStyle(
                          color: AppColors.pierVerde,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('¿Cuándo lo entregamos?'),
        _buildFechaHora(),
      ];

  Widget _buildDireccionCard(DireccionCliente d) {
    final sel = _selectedDireccion?.id == d.id;
    final sinCobertura = !d.tieneCobertura;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedDireccion = d),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel
                    ? AppColors.pierVerde
                    : AppColors.textSecondary.withValues(alpha: 0.15),
                width: sel ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sel
                      ? LucideIcons.circleDot
                      : LucideIcons.circle,
                  color: sel
                      ? AppColors.pierVerde
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(d.alias,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          if (sinCobertura)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Sin cobertura',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600)),
                            )
                          else
                            Text('\$${d.tarifa!.toStringAsFixed(0)} envío',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.pierVerde,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(d.lineaResumen,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (d.referencias != null)
                        Text('Ref: ${d.referencias}',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppColors.textSecondary.withValues(alpha: 0.8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _direccionAccion(LucideIcons.pencil,
                    () => _abrirAgregarDireccion(d)),
                const SizedBox(width: 4),
                _direccionAccion(LucideIcons.trash2,
                    () => _eliminarDireccion(d),
                    color: AppColors.error),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _direccionAccion(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon,
            size: 17, color: color ?? AppColors.textSecondary),
      ),
    );
  }

  Widget _buildFechaHora() => Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      Icon(LucideIcons.calendar,
                          size: 20, color: AppColors.pierVerde),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDate == null
                            ? 'Fecha'
                            : DateFormat('dd/MM/yyyy')
                                .format(_selectedDate!),
                        style: TextStyle(
                          color: _selectedDate == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: _cardDecoration(),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  icon: Icon(LucideIcons.chevronDown,
                      color: AppColors.pierVerde),
                  hint: Row(children: [
                    Icon(LucideIcons.clock,
                        size: 20, color: AppColors.pierVerde),
                    SizedBox(width: 10),
                    Text('Hora'),
                  ]),
                  value: _selectedTime,
                  items: _currentTimeSlots
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedTime = val),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _modalidadCard({
    required bool seleccionada,
    required IconData icon,
    required String titulo,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: seleccionada
                ? AppColors.pierVerde.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionada
                  ? AppColors.pierVerde
                  : AppColors.textSecondary.withValues(alpha: 0.15),
              width: seleccionada ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: seleccionada
                      ? AppColors.pierVerde
                      : AppColors.textSecondary,
                  size: 28),
              const SizedBox(height: 8),
              Text(titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: seleccionada
                          ? AppColors.pierVerde
                          : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.pierVerdeOscuro)),
      );

  // Nota: los pedidos especiales requieren anticipación + número de pedido.
  Widget _buildNotaEspeciales() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.pierDorado.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.pierDorado.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.info,
                color: AppColors.pierDoradoOscuro, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.pierDoradoOscuro),
                  children: [
                    const TextSpan(
                        text: 'Nota importante: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text:
                            'Los pedidos especiales requieren realizarse con 3 días '
                            'de anticipación. ${_esDomicilio ? 'Ten a la mano tu número de pedido al recibir.' : 'Presenta tu número de pedido al recoger.'}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // Aviso cuando el pedido se hace fuera del horario de atención.
  Widget _buildFueraDeServicio() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.clock,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fuera de servicio',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error)),
                  const SizedBox(height: 2),
                  Text(
                    'En este momento estamos cerrados. Horario: '
                    '${BusinessInfo.horario}. Puedes dejar tu pedido y lo '
                    'prepararemos en horario de atención.',
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════
// Hoja para agregar o editar una dirección de entrega. La colonia se elige
// de la lista con cobertura (GET /zonas-envio/colonias) para garantizar
// tarifa. Con [editar] precarga los campos y hace PUT /direcciones/:id.
// Devuelve la DireccionCliente creada/actualizada por Navigator.pop.
// ══════════════════════════════════════════════════════════════════════
class _AgregarDireccionSheet extends StatefulWidget {
  final DireccionCliente? editar;
  const _AgregarDireccionSheet({this.editar});

  @override
  State<_AgregarDireccionSheet> createState() => _AgregarDireccionSheetState();
}

class _AgregarDireccionSheetState extends State<_AgregarDireccionSheet> {
  final _direccionesRepo = DireccionesRepository();
  final _aliasCtrl = TextEditingController();
  final _calleCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  List<Map<String, dynamic>> _colonias = [];
  String? _colonia;
  bool _loadingColonias = true;
  bool _guardando = false;

  bool get _esEdicion => widget.editar != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    if (e != null) {
      _aliasCtrl.text = e.alias;
      _calleCtrl.text = e.calleNumero;
      _refCtrl.text = e.referencias ?? '';
      _telCtrl.text = e.telefonoContacto ?? '';
    }
    _cargarColonias();
  }

  @override
  void dispose() {
    _aliasCtrl.dispose();
    _calleCtrl.dispose();
    _refCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarColonias() async {
    final result = await _direccionesRepo.colonias();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _colonias = List<Map<String, dynamic>>.from(result['colonias'] ?? []);
        // En edición: preseleccionar la colonia actual si sigue con cobertura.
        final coloniaActual = widget.editar?.colonia;
        if (coloniaActual != null &&
            _colonias.any((c) => c['colonia'] == coloniaActual)) {
          _colonia = coloniaActual;
        }
      });
    }
    setState(() => _loadingColonias = false);
  }

  double? get _tarifaSel {
    if (_colonia == null) return null;
    final match = _colonias.where((c) => c['colonia'] == _colonia);
    if (match.isEmpty) return null;
    return double.tryParse(match.first['tarifa']?.toString() ?? '');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _guardar() async {
    // En edición la colonia puede quedar sin tocar (el backend conserva la
    // actual via COALESCE); al crear sí es obligatoria.
    if (_aliasCtrl.text.trim().isEmpty ||
        _calleCtrl.text.trim().isEmpty ||
        (_colonia == null && !_esEdicion)) {
      _snack('Completa alias, calle y número, y colonia');
      return;
    }
    setState(() => _guardando = true);
    final body = {
      'alias': _aliasCtrl.text.trim(),
      'calle_numero': _calleCtrl.text.trim(),
      if (_colonia != null) 'colonia': _colonia,
      'referencias': _refCtrl.text.trim(),
      'telefono_contacto': _telCtrl.text.trim(),
    };
    final result = _esEdicion
        ? await _direccionesRepo.actualizar(widget.editar!.id, body)
        : await _direccionesRepo.crear(body);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (result['success'] == true && result['direccion'] != null) {
      final d = DireccionCliente.fromJson(
          Map<String, dynamic>.from(result['direccion'] as Map));
      Navigator.pop(context, d);
    } else {
      _snack(result['message']?.toString() ?? 'No se pudo guardar la dirección');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(_esEdicion ? 'Editar dirección' : 'Nueva dirección',
                style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            _field(_aliasCtrl, 'Alias (Casa, Trabajo…)', LucideIcons.bookmark),
            const SizedBox(height: 12),
            _field(_calleCtrl, 'Calle y número, interior', LucideIcons.house),
            const SizedBox(height: 12),

            // Colonia (solo las que tienen cobertura)
            if (_loadingColonias)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.pierVerde, strokeWidth: 2)),
              )
            else if (_colonias.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                    'Aún no hay colonias con cobertura de envío. Recoge en sucursal.',
                    style: TextStyle(fontSize: 13, color: AppColors.error)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Row(children: [
                      Icon(LucideIcons.building2,
                          size: 20, color: AppColors.pierVerde),
                      SizedBox(width: 10),
                      Text('Colonia'),
                    ]),
                    value: _colonia,
                    icon: Icon(LucideIcons.chevronDown,
                        color: AppColors.pierVerde),
                    items: _colonias.map((c) {
                      final nombre = c['colonia']?.toString() ?? '';
                      final tarifa = c['tarifa']?.toString() ?? '';
                      return DropdownMenuItem(
                        value: nombre,
                        child: Text('$nombre  ·  \$$tarifa envío',
                            style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _colonia = v),
                  ),
                ),
              ),
            if (_tarifaSel != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(LucideIcons.truck,
                    size: 16, color: AppColors.pierVerde),
                const SizedBox(width: 6),
                Text('Envío: \$${_tarifaSel!.toStringAsFixed(0)} MXN',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.pierVerde,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            const SizedBox(height: 12),
            _field(_refCtrl, 'Referencias (opcional)', LucideIcons.info),
            const SizedBox(height: 12),
            _field(_telCtrl, 'Teléfono de contacto (opcional)', LucideIcons.phone,
                keyboard: TextInputType.phone),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde),
                child: _guardando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _esEdicion
                            ? 'Guardar cambios'
                            : 'Guardar dirección',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: keyboard == TextInputType.phone
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.pierVerde, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.pierVerde, width: 1.5),
        ),
      ),
    );
  }
}
