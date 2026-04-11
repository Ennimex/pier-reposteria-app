// lib/presentation/screens/client/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
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

  final List<String> _timeSlots = [
    '09:00 - 10:00', '10:00 - 11:00', '11:00 - 12:00',
    '12:00 - 13:00', '13:00 - 14:00', '14:00 - 15:00',
    '15:00 - 16:00', '16:00 - 17:00', '17:00 - 18:00', '18:00 - 19:00',
  ];

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.pierVerde,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
      selectableDayPredicate: (day) => day.weekday != DateTime.sunday,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      final intentResult = await _api.postAuth('/pagos/crear-intent', {});
      if (!mounted) return;

      if (intentResult['success'] != true) {
        setState(() => _errorMsg = intentResult['message'] ?? 'Error al iniciar pago');
        _showSnack(_errorMsg!, error: true);
        return;
      }

      final clientSecret = intentResult['clientSecret'] as String;
      final publishableKey = intentResult['publishableKey'] as String;

      // ── PASO 2: Inicializar Stripe con la publishable key ─────────
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      // ── PASO 3: Mostrar sheet de pago de Stripe ───────────────────
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

      final confirmResult = await _api.postAuth('/pagos/confirmar', {
        'payment_intent_id': paymentIntentId,
        'horario_recogida': horario,
        'notas': '',
      });

      if (!mounted) return;

      if (confirmResult['success'] == true) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        final pedido = confirmResult['pedido'] as Map<String, dynamic>;
        final total = cart.totalAmount;
        cart.clearCart();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              orderId: pedido['numero']?.toString() ?? pedido['id']?.toString() ?? '',
              pickupDate: DateFormat('dd/MM/yyyy').format(_selectedDate!),
              pickupTime: _selectedTime!,
              total: total,
            ),
          ),
        );
      } else {
        _showSnack(confirmResult['message'] ?? 'Error al confirmar pedido', error: true);
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
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('${item.quantity}x',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pierVerde)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(item.nombre,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500))),
                            Text(
                                '\$${(item.precio * item.quantity).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a Pagar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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
                leading: const Icon(Icons.store, color: AppColors.pierDorado),
                title: const Text('Sucursal Principal',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Calle Allende, Col. Tahuizán — Huejutla de Reyes'),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: AppColors.pierVerde, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── FECHA Y HORA ──────────────────────────────────────────
            _buildSectionTitle('¿Cuándo pasas?'),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
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
                                : DateFormat('dd/MM/yyyy').format(_selectedDate!),
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
                        items: _timeSlots
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t,
                                    style: const TextStyle(fontSize: 14))))
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
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Pago seguro con Stripe',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/b/ba/Stripe_Logo%2C_revised_2016.svg',
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.lock_rounded,
                        color: AppColors.pierVerde, size: 20),
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
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
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
                  disabledBackgroundColor: AppColors.pierVerde.withValues(alpha: 0.5),
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
                  Icon(Icons.lock_rounded, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('Pago cifrado y seguro con Stripe',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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