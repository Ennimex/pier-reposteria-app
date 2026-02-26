import 'package:flutter/material.dart';
// Ajusta los niveles de importación según tu estructura real
import '../../../../core/constants/app_colors.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({Key? key}) : super(key: key);

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Datos simulados para "Mis Solicitudes"
  final List<Map<String, dynamic>> _myRefunds = [
    {
      'id': 'REEM-001',
      'date': '01/02/2026',
      'product': 'Pastel de Chocolate',
      'amount': 350.00,
      'status': 'aprobado', // pendiente, aprobado, rechazado
    },
    {
      'id': 'REEM-002',
      'date': '15/01/2026',
      'product': 'Rosca de Reyes',
      'amount': 280.00,
      'status': 'pendiente',
    },
  ];

  // Datos para el formulario "Nueva Solicitud"
  final _formKey = GlobalKey<FormState>();
  String? _selectedOrder;
  String? _selectedProduct;
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _photosUploaded = false; // Simulación de fotos

  // Listas para los Dropdowns
  final List<String> _orders = ['PED-4829 (Entregado hoy)', 'PED-4810 (Ayer)'];
  final List<String> _products = ['Pastel de Zanahoria', 'Cheesecake Fresa'];
  final List<String> _reasons = [
    'Producto dañado',
    'No corresponde al pedido',
    'Producto en mal estado',
    'Calidad no satisfactoria',
    'Otro'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE ENVÍO ---
  void _submitRefund() async {
    if (_formKey.currentState!.validate()) {
      if (!_photosUploaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes subir al menos una foto de evidencia')),
        );
        return;
      }

      // Simular envío API
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.pierVerde)),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      // Mostrar éxito y limpiar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada con éxito. Folio: REEM-NEW'),
          backgroundColor: AppColors.pierVerde,
        ),
      );
      
      setState(() {
        _descriptionController.clear();
        _selectedOrder = null;
        _selectedProduct = null;
        _selectedReason = null;
        _photosUploaded = false;
        // Cambiar al tab de historial para ver la "nueva" solicitud
        _tabController.animateTo(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Reembolsos'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.pierVerde,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.pierVerde,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Mis Solicitudes'),
            Tab(text: 'Nueva Solicitud'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyRefundsList(),
          _buildNewRefundForm(),
        ],
      ),
    );
  }

  // --- TAB 1: LISTA DE REEMBOLSOS ---
  Widget _buildMyRefundsList() {
    if (_myRefunds.isEmpty) {
      return const Center(child: Text("No tienes solicitudes de reembolso"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myRefunds.length,
      itemBuilder: (context, index) {
        final refund = _myRefunds[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pierArena.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.pierVerde),
            ),
            title: Text(
              refund['id'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${refund['date']} • \$${refund['amount']}'),
            trailing: _buildStatusChip(refund['status']),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Producto: ${refund['product']}'),
                    const SizedBox(height: 8),
                    const Text('Motivo: Calidad no satisfactoria', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    // Timeline simple simulado
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.pierVerde, size: 16),
                        const SizedBox(width: 4),
                        const Text('Solicitado', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 10),
                        Container(height: 1, width: 20, color: Colors.grey),
                        const SizedBox(width: 10),
                        Icon(
                          refund['status'] == 'pendiente' ? Icons.radio_button_unchecked : Icons.check_circle,
                          color: refund['status'] == 'pendiente' ? Colors.grey : AppColors.pierVerde,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text('Revisión', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'aprobado':
        color = Colors.green;
        label = 'Aprobado';
        break;
      case 'rechazado':
        color = Colors.red;
        label = 'Rechazado';
        break;
      default:
        color = Colors.orange;
        label = 'Pendiente';
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  // --- TAB 2: FORMULARIO NUEVA SOLICITUD ---
  Widget _buildNewRefundForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alerta de políticas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Las solicitudes deben realizarse el mismo día de la recolección. Se requieren fotos de evidencia.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dropdowns
            DropdownButtonFormField<String>(
              decoration: _inputDecoration('Selecciona el Pedido'),
              value: _selectedOrder,
              items: _orders.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (val) => setState(() => _selectedOrder = val),
              validator: (val) => val == null ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              decoration: _inputDecoration('Selecciona el Producto'),
              value: _selectedProduct,
              items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) => setState(() => _selectedProduct = val),
              validator: (val) => val == null ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: _inputDecoration('Motivo del reembolso'),
              value: _selectedReason,
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => _selectedReason = val),
              validator: (val) => val == null ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDecoration('Descripción detallada del problema'),
              validator: (val) => (val == null || val.length < 20) ? 'Mínimo 20 caracteres' : null,
            ),
            const SizedBox(height: 24),

            // Subir Fotos (Simulado)
            const Text('Evidencia Fotográfica', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() => _photosUploaded = true);
              },
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: _photosUploaded
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle, color: AppColors.pierVerde),
                          SizedBox(width: 8),
                          Text('3 fotos adjuntadas'),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, color: Colors.grey),
                          Text('Toca para subir fotos (Máx 3)', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 32),

            // Botón Enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRefund,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enviar Solicitud', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}