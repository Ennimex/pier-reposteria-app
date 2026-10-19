// lib/ui/public/widgets/legal_screen.dart
//
// Movimiento: al llegar la página, el encabezado de la primera pestaña y
// sus secciones suben en cascada, una sola vez por visita. Las otras
// pestañas llegan con el deslizamiento del TabBarView, sin una segunda
// animación encima, y volver a una ya vista tampoco la repite. Mientras se
// desliza, la página que se va se atenúa (la profundidad de «Mis Pedidos»).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/domain/models/textos_legales.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/public/view_model/legal_view_model.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';
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
      widget.viewModel ?? LegalViewModel(repo: context.read<ConfiguracionRepository>());

  // La cascada solo acompaña la llegada de la página: lo que se arme
  // después (otra pestaña, volver a esta, más secciones del panel) aparece
  // ya en su lugar. Se reconstruye una vez tras el primer cuadro para que
  // las pestañas que se monten luego ya no traigan la entrada.
  bool _llegada = true;

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _llegada = false);
    });
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
                  PresionEscala(
                    escala: AppMovimiento.escalaPresionChica,
                    child: GestureDetector(
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
            // Al deslizar (o tocar otra pestaña), la página que se va se
            // atenúa y la que llega se aclara, como en «Mis Pedidos».
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  PaginaAtenuada(
                    pestanas: _tabController,
                    indice: 0,
                    child: _buildContent(
                      icon: LucideIcons.shieldAlert,
                      title: 'Aviso de Privacidad',
                      sections: _vm.privacidad,
                    ),
                  ),
                  PaginaAtenuada(
                    pestanas: _tabController,
                    indice: 1,
                    child: _buildContent(
                      icon: LucideIcons.fileText,
                      title: 'Términos y Condiciones',
                      sections: _vm.terminos,
                    ),
                  ),
                  PaginaAtenuada(
                    pestanas: _tabController,
                    indice: 2,
                    child: _buildContent(
                      icon: LucideIcons.undo2,
                      title: 'Política de Devoluciones',
                      sections: _vm.devoluciones,
                    ),
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
    // Solo la pestaña que se ve al llegar la página entra en cascada.
    final animar = _llegada;
    final espera = esperaDePagina(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección
          EntradaSuave(
            retraso: espera,
            animar: animar,
            child: Container(
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
          ),
          const SizedBox(height: 16),

          // Secciones
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EntradaSuave(
                orden: i + 1,
                retraso: espera,
                animar: animar,
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
                      if (sections[i].titulo.isNotEmpty) ...[
                        Text(sections[i].titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                      ],
                      Text(sections[i].contenido,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),

          // Footer contacto
          EntradaSuave(
            orden: sections.length + 1,
            retraso: espera,
            animar: animar,
            child: Container(
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
          ),
        ],
      ),
    );
  }
}
