import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../auth/login_screen.dart'; // Para el logout
import 'edit_profile_screen.dart'; // Para navegar a editar

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Estado de los switches de preferencias
  bool _pushNotifications = true;
  bool _emailOffers = false;

  // Datos simulados del usuario (Vendrían de tu AuthProvider)
  final String _userName = "Alexander Martinez";
  final String _userEmail = "alexander@email.com";
  final String _userPhone = "7711234567";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: AppColors.pierVerde,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. HEADER CON AVATAR
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.pierDorado, AppColors.pierDorado.withAlpha(153)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _userName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    _userEmail,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. INFORMACIÓN PERSONAL (Card)
            _buildSectionCard(
              title: 'Información Personal',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  _buildInfoRow('Nombre', _userName),
                  const Divider(),
                  _buildInfoRow('Email', _userEmail, isVerified: true),
                  const Divider(),
                  _buildInfoRow('Teléfono', _userPhone),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Navegar a editar
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.pierVerde),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Editar Información', style: TextStyle(color: AppColors.pierVerde)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. PREFERENCIAS (Card)
            _buildSectionCard(
              title: 'Preferencias',
              icon: Icons.settings_outlined,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notificaciones Push'),
                    value: _pushNotifications,
                    activeThumbColor: AppColors.pierVerde,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Ofertas por Email'),
                    value: _emailOffers,
                    activeThumbColor: AppColors.pierVerde,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _emailOffers = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. SEGURIDAD (Card)
            _buildSectionCard(
              title: 'Seguridad',
              icon: Icons.lock_outline,
              child: ListTile(
                title: const Text('Cambiar Contraseña'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                contentPadding: EdgeInsets.zero,
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 32),

            // 5. CERRAR SESIÓN
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.pierVerde, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isVerified = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              if (isVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, color: AppColors.pierVerde, size: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE DIÁLOGOS ---

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            TextField(decoration: InputDecoration(labelText: 'Contraseña Actual', prefixIcon: Icon(Icons.lock_outline))),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Nueva Contraseña', prefixIcon: Icon(Icons.lock))),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Confirmar Nueva', prefixIcon: Icon(Icons.lock))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pierVerde),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar Sesión?'),
        content: const Text('¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              // Aquí iría la lógica real de AuthProvider.logout()
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}