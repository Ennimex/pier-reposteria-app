// lib/presentation/screens/client/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/business_info.dart';
import '../../../../core/services/api_service.dart';
import '../../../../data/models/direccion_model.dart';
import '../../../../data/providers/cart_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = ApiService();

  // pickup | domicilio
  String _tipoEntrega = 'pickup';

  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;
  String? _errorMsg;

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
        await _api.get(ApiConstants.configuracionSeccion('contacto'));
    if (!mounted) return;
    if (result['success'] == true) {
      final config = result['config'] as Map<String, dynamic>? ?? {};
      final dir = config['direccion']?.toString();
      if (dir != null && dir.isNotEmpty) {
        setState(() => _direccionSucursal = dir);
      }
    }
  }

  Future<void> _cargarDirecciones() async {
    setState(() => _loadingDirecciones = true);
    final result = await _api.getAuth(ApiConstants.direcciones);
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

  Future<void> _abrirAgregarDireccion() async {
    final nueva = await showModalBottomSheet<DireccionCliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AgregarDireccionSheet(),
    );
    if (nueva != null && mounted) {
      await _cargarDirecciones();
      if (mounted) {
        setState(() {
          _selectedDireccion = _direcciones.firstWhere(
            (d) => d.id == nueva.id,
            orElse: () => nueva,
          );
        });
      }
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
            colorScheme: const ColorScheme.light(
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

  Future<void> _processPayment() async {
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

    try {
      // ── PASO 1: Crear Payment Intent (el backend calcula total + envío) ──
      final intentBody = <String, dynamic>{};
      if (_esDomicilio) {
        intentBody['tipo_entrega'] = 'domicilio';
        intentBody['direccion_id'] = _selectedDireccion!.id;
      }
      final intentResult =
          await _api.postAuth(ApiConstants.crearPaymentIntent, intentBody);
      if (!mounted) return;

      if (intentResult['success'] != true) {
        setState(() =>
            _errorMsg = intentResult['message'] ?? 'Error al iniciar pago');
        _showSnack(_errorMsg!, error: true);
        return;
      }

      final clientSecret = intentResult['clientSecret'] as String;
      final publishableKey = intentResult['publishableKey'] as String;
      // Total autoritativo del backend (incluye envío)
      final totalBackend =
          double.tryParse(intentResult['total']?.toString() ?? '') ??
              (cartTotalConEnvio());

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

      // ── PASO 4: Confirmar pedido en el backend ────────────────────
      final paymentIntentId = clientSecret.split('_secret_').first;
      final horario =
          '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ${_selectedTime!.split(' - ').first}';

      final confirmBody = <String, dynamic>{
        'payment_intent_id': paymentIntentId,
        'notas': '',
      };
      if (_esDomicilio) {
        confirmBody['horario_entrega'] = horario;
      } else {
        confirmBody['horario_recogida'] = horario;
      }

      final confirmResult =
          await _api.postAuth(ApiConstants.confirmarPago, confirmBody);

      if (!mounted) return;

      if (confirmResult['success'] == true) {
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
            ),
          ),
        );
      } else {
        _showSnack(
            confirmResult['message'] ?? 'Error al confirmar pedido',
            error: true);
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
    final cart = Provider.of<CartProvider>(context);
    final totalConEnvio = cart.totalAmount + _costoEnvio;

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(
        title: const Text('Finalizar Pedido'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

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
                                  style: const TextStyle(
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
                                        style: const TextStyle(
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
                          Icon(Icons.local_offer_rounded,
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
                          const Icon(Icons.local_shipping_outlined,
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
                          style: const TextStyle(
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
                    icon: Icons.store_rounded,
                    titulo: 'Recoger',
                    sub: 'En sucursal',
                    onTap: () => setState(() => _tipoEntrega = 'pickup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modalidadCard(
                    seleccionada: _esDomicilio,
                    icon: Icons.delivery_dining_rounded,
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
                    child: const Icon(Icons.credit_card,
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
                  Icon(Icons.lock_rounded,
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
                  Icon(Icons.error_outline,
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

            const SizedBox(height: 32),

            // ── BOTÓN PAGAR ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
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
                        'Pagar  \$${totalConEnvio.toStringAsFixed(0)} MXN',
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
                  Icon(Icons.lock_rounded,
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
            leading: const Icon(Icons.store, color: AppColors.pierDorado),
            title: const Text(BusinessInfo.sucursal,
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_direccionSucursal),
            trailing: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: AppColors.pierVerde, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
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
            child: const Center(
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
                  const Icon(Icons.add_location_alt_outlined,
                      color: AppColors.pierVerde, size: 20),
                  const SizedBox(width: 10),
                  const Text('Agregar dirección',
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
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
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
                                style: const TextStyle(
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
              ],
            ),
          ),
        ),
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
                      const Icon(Icons.calendar_today,
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
                  icon: const Icon(Icons.arrow_drop_down,
                      color: AppColors.pierVerde),
                  hint: const Row(children: [
                    Icon(Icons.access_time,
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
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.pierVerdeOscuro)),
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
// Hoja para agregar una dirección de entrega. La colonia se elige de la
// lista con cobertura (GET /zonas-envio/colonias) para garantizar tarifa.
// Devuelve la DireccionCliente creada por Navigator.pop.
// ══════════════════════════════════════════════════════════════════════
class _AgregarDireccionSheet extends StatefulWidget {
  const _AgregarDireccionSheet();

  @override
  State<_AgregarDireccionSheet> createState() => _AgregarDireccionSheetState();
}

class _AgregarDireccionSheetState extends State<_AgregarDireccionSheet> {
  final _api = ApiService();
  final _aliasCtrl = TextEditingController();
  final _calleCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  List<Map<String, dynamic>> _colonias = [];
  String? _colonia;
  bool _loadingColonias = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
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
    final result = await _api.get(ApiConstants.zonasColonias);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _colonias = List<Map<String, dynamic>>.from(result['colonias'] ?? []);
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
    if (_aliasCtrl.text.trim().isEmpty ||
        _calleCtrl.text.trim().isEmpty ||
        _colonia == null) {
      _snack('Completa alias, calle y número, y colonia');
      return;
    }
    setState(() => _guardando = true);
    final result = await _api.postAuth(ApiConstants.direcciones, {
      'alias': _aliasCtrl.text.trim(),
      'calle_numero': _calleCtrl.text.trim(),
      'colonia': _colonia,
      'referencias': _refCtrl.text.trim(),
      'telefono_contacto': _telCtrl.text.trim(),
    });
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
            const Text('Nueva dirección',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            _field(_aliasCtrl, 'Alias (Casa, Trabajo…)', Icons.bookmark_outline),
            const SizedBox(height: 12),
            _field(_calleCtrl, 'Calle y número, interior', Icons.home_outlined),
            const SizedBox(height: 12),

            // Colonia (solo las que tienen cobertura)
            if (_loadingColonias)
              const Padding(
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
                    hint: const Row(children: [
                      Icon(Icons.location_city_outlined,
                          size: 20, color: AppColors.pierVerde),
                      SizedBox(width: 10),
                      Text('Colonia'),
                    ]),
                    value: _colonia,
                    icon: const Icon(Icons.arrow_drop_down,
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
                const Icon(Icons.local_shipping_outlined,
                    size: 16, color: AppColors.pierVerde),
                const SizedBox(width: 6),
                Text('Envío: \$${_tarifaSel!.toStringAsFixed(0)} MXN',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.pierVerde,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            const SizedBox(height: 12),
            _field(_refCtrl, 'Referencias (opcional)', Icons.info_outline),
            const SizedBox(height: 12),
            _field(_telCtrl, 'Teléfono de contacto (opcional)', Icons.phone_outlined,
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
                    : const Text('Guardar dirección',
                        style: TextStyle(
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
          borderSide: const BorderSide(color: AppColors.pierVerde, width: 1.5),
        ),
      ),
    );
  }
}
