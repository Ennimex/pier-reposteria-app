import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({Key? key}) : super(key: key);

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  final List<String> _subjects = ['Información general', 'Pedidos', 'Sugerencias', 'Quejas', 'Otro'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Contacto'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estamos para escucharte',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro),
            ),
            const SizedBox(height: 8),
            const Text('Envíanos un mensaje o visítanos en nuestras sucursales.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // Formulario
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: _inputDecoration('Nombre Completo', Icons.person),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _inputDecoration('Correo Electrónico', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => !v!.contains('@') ? 'Email inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _inputDecoration('Teléfono (10 dígitos)', Icons.phone),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (v) => v!.length != 10 ? 'Debe tener 10 dígitos' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration('Asunto', Icons.subject),
                    value: _selectedSubject,
                    items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _selectedSubject = val),
                    validator: (v) => v == null ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _inputDecoration('Mensaje', Icons.message).copyWith(alignLabelWithHint: true),
                    maxLines: 4,
                    validator: (v) => v!.length < 20 ? 'Mínimo 20 caracteres' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mensaje enviado. Te responderemos pronto.'), backgroundColor: AppColors.pierVerde),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pierVerde,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Enviar Mensaje', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            
            // Datos de Contacto
            const Text('Otros medios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildContactRow(Icons.phone, '771 123 4567', () {}),
            _buildContactRow(Icons.email, 'hola@pier.com', () {}),
            _buildContactRow(Icons.facebook, 'Pier Repostería', () {}),
            
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.message, color: Colors.white),
              label: const Text('Escríbenos por WhatsApp', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildContactRow(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.pierVerde),
      ),
      title: Text(text),
      onTap: onTap,
    );
  }
}