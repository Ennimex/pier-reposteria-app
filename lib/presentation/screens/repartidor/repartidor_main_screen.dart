// lib/presentation/screens/repartidor/repartidor_main_screen.dart
//
// Shell del módulo Repartidor: bottom nav Entregas / Historial / Perfil.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/entregas_provider.dart';
import 'entregas_screen.dart';
import 'historial_repartidor_screen.dart';
import 'perfil_repartidor_screen.dart';

class RepartidorMainScreen extends StatefulWidget {
  const RepartidorMainScreen({super.key});

  @override
  State<RepartidorMainScreen> createState() => _RepartidorMainScreenState();
}

class _RepartidorMainScreenState extends State<RepartidorMainScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EntregasProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            EntregasScreen(),
            HistorialRepartidorScreen(),
            PerfilRepartidorScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppColors.pierVerde,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.truck),
            activeIcon: Icon(LucideIcons.truck),
            label: 'Entregas',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.history),
            activeIcon: Icon(LucideIcons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.user),
            activeIcon: Icon(LucideIcons.user),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
