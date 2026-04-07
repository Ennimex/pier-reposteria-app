// lib/presentation/screens/client/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/providers/cart_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;

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

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora de recolección'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final cart = Provider.of<CartProvider>(context, listen: false);
    final totalPaid = cart.totalAmount;

    // Formatear horario para el backend: "2026-04-10 14:00"
    final horario =
        '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} ${_selectedTime!.split(' - ').first}';

    final result = await _api.postAuth(
      ApiConstants.crearPedido,
      {
        'horario_recogida': horario,
        'metodo_pago': 'tarjeta',
        'notas': '',
      },
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final pedido = result['pedido'] as Map<String, dynamic>;
      cart.clearCart();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: pedido['numero']?.toString() ?? pedido['id']?.toString() ?? '',
            pickupDate: DateFormat('dd/MM/yyyy').format(_selectedDate!),
            pickupTime: _selectedTime!,
            total: totalPaid,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al procesar el pedido'),
          backgroundColor: Colors.red,
        ),
      );
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── RESUMEN ─────────────────────────────────────────────
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

              // ── SUCURSAL — solo una ──────────────────────────────────
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

              // ── FECHA Y HORA ─────────────────────────────────────────
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

              // ── PAGO ─────────────────────────────────────────────────
              _buildSectionTitle('Pago'),
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
                          Text('Pago seguro procesado en sucursal',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppColors.pierVerde, shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── BOTÓN PAGAR ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Confirmar Pedido  \$${cart.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '🔒 Tu pedido se confirma al llegar a la sucursal',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 30),
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