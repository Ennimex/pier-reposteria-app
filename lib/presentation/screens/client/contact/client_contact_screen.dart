//presentation/screens/client/contact/client_contact_screen.dart import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';

class ClientContactScreen extends StatefulWidget {
  const ClientContactScreen({super.key});

  @override
  State<ClientContactScreen> createState() => _ClientContactScreenState();
}

class _ClientContactScreenState extends State<ClientContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mensajeController = TextEditingController();
  String _asunto = 'Información general';
  bool _isLoading = false;

  final List<String> _asuntos = [
    'Información general',
    'Pedidos',
    'Sugerencias',
    'Quejas',
    'Queja sobre pedido',
    'Otro',
  ];

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final api = ApiService();

    final result = await api.postAuth(ApiConstants.enviarContacto, {
      'nombre': user?['nombre'] ?? '',
      'email': user?['email'] ?? '',
      'asunto': _asunto,
      'mensaje': _mensajeController.text.trim(),
    });

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      _mensajeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado'), backgroundColor: AppColors.pierVerde),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al enviar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacto / Quejas'),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pierArena,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.pierVerde),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?['nombre'] ?? 'Usuario',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(user?['email'] ?? '',
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Asunto', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _asunto,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _asuntos.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => setState(() => _asunto = val!),
              ),
              const SizedBox(height: 20),
              const Text('Mensaje', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mensajeController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Describe tu consulta o queja...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 20) {
                    return 'El mensaje debe tener al menos 20 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enviarMensaje,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enviar Mensaje',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}