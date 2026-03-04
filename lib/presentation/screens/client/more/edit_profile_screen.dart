import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores (Idealmente vendrían con los datos del usuario actual)
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: "Alexander Martinez");
    _phoneController = TextEditingController(text: "7711234567");

    // Escuchar cambios para habilitar el botón de guardar
    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    // Simulación simple de detección de cambios
    setState(() {
      _hasChanges = true; 
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      // Simular guardado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardando cambios...'),
          backgroundColor: AppColors.pierVerde,
          duration: Duration(seconds: 1),
        ),
      );
      
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      Navigator.pop(context); // Volver al perfil
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Guardar', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Foto de Perfil con botón de cámara
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1 * 255),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "A",
                          style: TextStyle(fontSize: 50, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          // Aquí iría la lógica de ImagePicker
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abrir galería...")));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.pierVerde,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Campo Nombre
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'El nombre es obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Campo Teléfono
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.length != 10) return 'Debe tener 10 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email (Solo lectura)
              TextFormField(
                initialValue: 'alexander@email.com',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'El correo electrónico no se puede cambiar.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}