// lib/ui/repartidor/widgets/repartidor_main_screen.dart
//
// Shell del módulo Repartidor (MVVM, Fase 5): bottom nav Entregas /
// Historial / Perfil. Es dueño del RepartidorViewModel que comparten las
// tres pestañas y hace la primera carga al abrir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/animated_indexed_stack.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entregas_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/historial_repartidor_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/perfil_repartidor_screen.dart';
import 'package:provider/provider.dart';

class RepartidorMainScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const RepartidorMainScreen({super.key, this.viewModel});

  final RepartidorViewModel? viewModel;

  @override
  State<RepartidorMainScreen> createState() => _RepartidorMainScreenState();
}

class _RepartidorMainScreenState extends State<RepartidorMainScreen> {
  late final RepartidorViewModel _vm =
      widget.viewModel ?? RepartidorViewModel(repo: context.read());
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        bottom: false,
        child: AnimatedIndexedStack(
          index: _index,
          // Deslizar entre pestañas (fling); equivale a tocar la pestaña
          onSwipeToIndex: (i) => setState(() => _index = i),
          children: [
            EntregasScreen(viewModel: _vm),
            HistorialRepartidorScreen(viewModel: _vm),
            PerfilRepartidorScreen(viewModel: _vm),
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
