import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

import '../client/main_screen.dart'; 
import '../public/home_public_screen.dart';

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
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated) {
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePublicScreen()),
      );
    }
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
                // LOGO CORREGIDO: Sin bordes extraños
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    // Sombra suave difuminada, sin líneas duras
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(64),
                        blurRadius: 30, // Más difuminado
                        spreadRadius: 5, // Un poco más extendido
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  // ClipOval asegura que el recorte sea suave (anti-aliasing)
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0), // Más espacio para que no toque el borde
                      child: Image.asset(
                        AppAssets.logo,
                        fit: BoxFit.contain, // Se ajusta sin cortarse
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