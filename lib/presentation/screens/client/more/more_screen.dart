import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../auth/login_screen.dart';

// --- IMPORTAMOS LAS PANTALLAS PÚBLICAS ---
import '../../public/about_us_screen.dart';
import '../../public/faq_screen.dart'; 
import '../../public/contact_screen.dart';
import '../../public/legal_screen.dart';

// --- IMPORTAMOS LAS PANTALLAS DE CLIENTE ---
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../refunds/refunds_screen.dart';
import '../more/edit_profile_screen.dart'; 

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado de autenticación
    final authProvider = Provider.of<AuthProvider>(context);
    final isAuthenticated = authProvider.isAuthenticated;

    // Función auxiliar para proteger rutas: 
    // Si no hay sesión, manda al Login. Si hay sesión, manda a la pantalla deseada.
    void handleProtectedNavigation(Widget screen) {
      if (!isAuthenticated) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Más Opciones'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // 1. CABECERA DINÁMICA (Logueado vs No Logueado)
          if (isAuthenticated) 
            _buildAuthenticatedHeader(context)
          else 
            _buildGuestHeader(context),

          const SizedBox(height: 10),

          // 2. SECCIONES DE CLIENTE (AHORA SIEMPRE VISIBLES, PERO PROTEGIDAS)
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text('Mi Cuenta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _buildListTile(context, icon: Icons.favorite_border, title: 'Mis Favoritos', onTap: () {
            handleProtectedNavigation(const FavoritesScreen());
          }),
          _buildListTile(context, icon: Icons.notifications_none, title: 'Notificaciones', onTap: () {
            handleProtectedNavigation(const NotificationsScreen());
          }),
          _buildListTile(context, icon: Icons.help_center_outlined, title: 'Mis Reembolsos', onTap: () {
            handleProtectedNavigation(const RefundsScreen());
          }),
          
          const Divider(height: 30),

          // 3. SECCIONES PÚBLICAS (Todos pueden entrar libremente)
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text('Acerca de Pier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _buildListTile(context, icon: Icons.storefront, title: 'Nuestra Historia', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen()));
          }),
          _buildListTile(context, icon: Icons.question_answer_outlined, title: 'Preguntas Frecuentes', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen())); 
          }),
          _buildListTile(context, icon: Icons.contact_support_outlined, title: 'Contacto', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen()));
          }),
          _buildListTile(context, icon: Icons.gavel, title: 'Legales y Privacidad', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen()));
          }),

          const SizedBox(height: 30),

          // 4. CERRAR SESIÓN (Este botón SÍ debe ocultarse si no hay sesión)
          if (isAuthenticated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  _showLogoutDialog(context, authProvider);
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- COMPONENTES VISUALES INTERNOS ---

  Widget _buildGuestHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¡Bienvenido!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Ingresa a tu cuenta para ver tus pedidos, favoritos y más.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ingresar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAuthenticatedHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.pierDorado.withValues(alpha: 0.2),
            child: const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.pierDorado)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alexander', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Text('alexander@correo.com', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  },
                  child: const Text('Editar Perfil', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: AppColors.pierVerde),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }

  // --- FUNCIONES AUXILIARES ---

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar tu sesión?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo
              authProvider.logout();  // Cierra sesión (el provider actualizará la UI)
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}