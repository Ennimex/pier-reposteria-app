// lib/presentation/screens/client/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../data/providers/cart_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = ApiService();

  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;
  String? _errorMsg;

  String _direccionSucursal =
      'Calle Allende, Col. Tahuizán — Huejutla de Reyes';

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

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
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
      backgroundColor: error ? Colors.red : AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _processPayment() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('Selecciona fecha y hora de recolección', error: true);
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      // ── PASO 1: Crear Payment Intent ──────────────────────────────
      // El backend calcula el total con descuentos del carrito automáticamente
      final intentResult =
          await _api.postAuth(ApiConstants.crearPaymentIntent, {});
      if (!mounted) return;

      if (intentResult['success'] != true) {
        setState(() =>
            _errorMsg = intentResult['message'] ?? 'Error al iniciar pago');
        _showSnack(_errorMsg!, error: true);
        return;
      }

      final clientSecret = intentResult['clientSecret'] as String;
      final publishableKey = intentResult['publishableKey'] as String;

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
      // ✅ FIX: codigo_descuento removido — el backend aplica descuentos
      //         automáticamente desde tblpromociones, no desde el body
      final paymentIntentId = clientSecret.split('_secret_').first;
      final horario =
          '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ${_selectedTime!.split(' - ').first}';

      final confirmResult =
          await _api.postAuth(ApiConstants.confirmarPago, {
        'payment_intent_id': paymentIntentId,
        'horario_recogida': horario,
        'notas': '',
      });

      if (!mounted) return;

      if (confirmResult['success'] == true) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        final pedido =
            confirmResult['pedido'] as Map<String, dynamic>;
        final total = cart.totalAmount;
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
              total: total,
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

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
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
                                  color: Colors.grey[100],
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
                                  Text(item.nombre,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500)),
                                  // ✅ NUEVO: descuento por item en checkout
                                  if (item.tieneDescuento)
                                    Row(children: [
                                      Text(
                                        '\$${item.precio.toStringAsFixed(0)} c/u',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '\$${item.precioOriginal.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[400],
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

                  // ✅ NUEVO: mostrar ahorro si hay descuentos
                  if (cart.tieneDescuentos) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14)),
                        Text(
                          '\$${cart.totalOriginal.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: Colors.grey[400],
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
                              size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Text('Descuentos aplicados',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        Text(
                          '-\$${cart.totalAhorro.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.withValues(alpha: 0.2)),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a Pagar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('\$${cart.totalAmount.toStringAsFixed(0)}',
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

            // ── SUCURSAL ──────────────────────────────────────────────
            _buildSectionTitle('¿Dónde recoges?'),
            Container(
              decoration: _cardDecoration(),
              child: ListTile(
                leading: const Icon(Icons.store,
                    color: AppColors.pierDorado),
                title: const Text('Sucursal Principal',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_direccionSucursal),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: AppColors.pierVerde,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── FECHA Y HORA ──────────────────────────────────────────
            _buildSectionTitle('¿Cuándo pasas?'),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                        decoration: _cardDecoration(),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 20,
                                color: AppColors.pierVerde),
                            const SizedBox(width: 10),
                            Text(
                              _selectedDate == null
                                  ? 'Fecha'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? Colors.grey
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
                              size: 20,
                              color: AppColors.pierVerde),
                          SizedBox(width: 10),
                          Text('Hora'),
                        ]),
                        value: _selectedTime,
                        items: _currentTimeSlots
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t,
                                    style: const TextStyle(
                                        fontSize: 14))))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedTime = val),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/b/ba/Stripe_Logo%2C_revised_2016.svg',
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.lock_rounded,
                        color: AppColors.pierVerde,
                        size: 20),
                  ),
                ],
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13)),
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
                        'Pagar  \$${cart.totalAmount.toStringAsFixed(0)} MXN',
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
                      size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('Pago cifrado y seguro con Stripe',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
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