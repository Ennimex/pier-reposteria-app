// lib/ui/public/widgets/legal_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/domain/models/textos_legales.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/public/view_model/legal_view_model.dart';
import 'package:provider/provider.dart';

class LegalScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const LegalScreen({super.key, this.viewModel});

  final LegalViewModel? viewModel;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final LegalViewModel _vm =
      widget.viewModel ?? LegalViewModel(repo: ConfiguracionRepository());

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildPantalla(context),
    );
  }

  Widget _buildPantalla(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Icon(LucideIcons.chevronLeft,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Marco Legal',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),

            // ── TABS ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(
                    color: AppColors.pierVerde,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Privacidad'),
                    Tab(text: 'Términos'),
                    Tab(text: 'Devoluciones'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── CONTENIDO ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContent(
                    icon: LucideIcons.shieldAlert,
                    title: 'Aviso de Privacidad',
                    sections: _vm.privacidad,
                  ),
                  _buildContent(
                    icon: LucideIcons.fileText,
                    title: 'Términos y Condiciones',
                    sections: _vm.terminos,
                  ),
                  _buildContent(
                    icon: LucideIcons.undo2,
                    title: 'Política de Devoluciones',
                    sections: _vm.devoluciones,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required IconData icon,
    required String title,
    required List<SeccionLegal> sections,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.pierVerde.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(icon, color: AppColors.pierVerde, size: 22),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerdeOscuro)),
            ]),
          ),
          const SizedBox(height: 16),

          // Secciones
          ...sections.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.titulo.isNotEmpty) ...[
                        Text(s.titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                      ],
                      Text(s.contenido,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ],
                  ),
                ),
              )),

          // Footer contacto
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(LucideIcons.mail,
                  color: AppColors.pierVerde, size: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Dudas legales?',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(BusinessInfo.email,
                      style: TextStyle(
                          color: AppColors.pierVerde,
                          fontSize: 12)),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
