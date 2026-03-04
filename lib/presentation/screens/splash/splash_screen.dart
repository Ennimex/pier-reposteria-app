import 'package:flutter/material.dart';
// Provider y AuthProvider ya no son estrictamente necesarios para la navegación aquí,
// pero puedes dejarlos si planeas hacer una carga inicial de datos (ej. cargar el perfil) antes de saltar.
// import 'package:provider/provider.dart';
// import '../../../data/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

import '../client/main_screen.dart'; 
// ¡ELIMINADO! import '../public/home_public_screen.dart'; ya no existe.

class AppAssets {
  static const logo = 'assets/images/logo.png';
  static const splashBackground = 'assets/images/fondo_splash_verde_pier.png';
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  // Renombramos la función para que sea más descriptiva de su nueva acción
  Future<void> _navigateToMain() async {
    // Simulamos un tiempo de carga inicial (aquí iría inicialización de bases de datos locales, etc.)
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    // TODOS LOS USUARIOS van al MainScreen ahora (Contenedor Unificado).
    // MainScreen decidirá qué mostrar en cada pestaña basado en la sesión.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. IMAGEN DE FONDO
          Image.asset(
            AppAssets.splashBackground,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: const Color(0xFFF5F1ED)); // Color crema de respaldo
            },
          ),

          // 2. CAPA OSCURA (Overlay)
          Container(
            color: Colors.black.withAlpha(102), 
          ),

          // 3. CONTENIDO
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(64),
                        blurRadius: 30, 
                        spreadRadius: 5, 
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0), 
                      child: Image.asset(
                        AppAssets.logo,
                        fit: BoxFit.contain, 
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 35),
                
                // TÍTULO
                const Text(
                  'Pastelería Pier',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Playfair Display',
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // SUBTÍTULO
                const Text(
                  'Dulces momentos',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.pierDorado,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 60),
                
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}