import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/providers/cart_provider.dart';
import 'order_success_screen.dart'; // Importa la pantalla de éxito

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Estado
  int _selectedBranch = 1;
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;

  // Controladores
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  final List<String> _timeSlots = [
    '09:00 - 10:00', '10:00 - 11:00', '11:00 - 12:00',
    '12:00 - 13:00', '13:00 - 14:00', '14:00 - 15:00',
    '15:00 - 16:00', '16:00 - 17:00', '17:00 - 18:00', '18:00 - 19:00',
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = now.add(const Duration(days: 1)); 
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.pierVerde, 
              onPrimary: Colors.white, 
              onSurface: AppColors.textPrimary, 
            ),
          ),
          child: child!,
        );
      },
      selectableDayPredicate: (DateTime day) {
        return day.weekday != DateTime.sunday;
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _processPayment() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona fecha y hora de recolección'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      // Simulación API
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      final cart = Provider.of<CartProvider>(context, listen: false);
      final totalPaid = cart.totalAmount;
      
      cart.clearCart();
      
      // AQUÍ ESTABA EL ERROR: Llamada corregida con los parámetros exactos
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderId: 'PED-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
            branchName: _selectedBranch == 1 ? 'Sucursal Principal' : 'Plaza Las Flores',
            // Corregido: Pasamos el String formateado, no el objeto DateTime
            pickupDate: DateFormat('dd/MM/yyyy').format(_selectedDate!),
            pickupTime: _selectedTime!,
            total: totalPaid,
          ),
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
              _buildSectionTitle('Resumen'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    ...cart.items.values.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                            child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.pierVerde)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          ),
                          Text('\$${(item.price * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a Pagar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '\$${cart.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('¿Dónde recoges?'),
              Container(
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      value: 1,
                      groupValue: _selectedBranch,
                      activeColor: AppColors.pierVerde,
                      title: const Text('Sucursal Principal', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Av. Revolución 123, Centro'),
                      secondary: const Icon(Icons.store, color: AppColors.pierDorado),
                      onChanged: (val) => setState(() => _selectedBranch = val!),
                    ),
                    const Divider(height: 1),
                    RadioListTile<int>(
                      value: 2,
                      groupValue: _selectedBranch,
                      activeColor: AppColors.pierVerde,
                      title: const Text('Plaza Las Flores', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Blvd. Central km 2, Local 4'),
                      secondary: const Icon(Icons.store, color: AppColors.pierDorado),
                      onChanged: (val) => setState(() => _selectedBranch = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                            const Icon(Icons.calendar_today, size: 20, color: AppColors.pierVerde),
                            const SizedBox(width: 10),
                            Text(
                              _selectedDate == null ? 'Fecha' : DateFormat('dd/MM').format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null ? Colors.grey : AppColors.textPrimary,
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
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.pierVerde),
                          hint: Row(
                            children: const [
                              Icon(Icons.access_time, size: 20, color: AppColors.pierVerde),
                              SizedBox(width: 10),
                              Text('Hora'),
                            ],
                          ),
                          value: _selectedTime,
                          items: _timeSlots.map((time) => DropdownMenuItem(value: time, child: Text(time, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) => setState(() => _selectedTime = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              _buildSectionTitle('Pago Seguro'),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número de Tarjeta',
                        prefixIcon: Icon(Icons.credit_card, color: Colors.grey),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) => (value == null || value.length < 16) ? 'Inválido' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.datetime,
                            decoration: const InputDecoration(
                              labelText: 'MM/AA',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (val) => val!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (val) => val!.length < 3 ? 'Inválido' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Pagar \$${cart.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          // Uso de withValues para evitar deprecation warning
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}