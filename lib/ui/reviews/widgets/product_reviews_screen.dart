// lib/ui/reviews/widgets/product_reviews_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/domain/models/resena_producto.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

class ProductReviewsScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const ProductReviewsScreen({
    required this.product,
    super.key,
    this.viewModel,
  });

  final Product product;
  final ProductReviewsViewModel? viewModel;

  @override
  State<ProductReviewsScreen> createState() =>
      _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final ProductReviewsViewModel _vm = widget.viewModel ??
      ProductReviewsViewModel(
        repo: context.read<ResenasRepository>(),
        productoId: widget.product.id,
      );

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ ProductReviewsScreen: ${widget.product.nombre}');
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _irALogin() {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  void _toggleLike(ResenaProducto resena) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _irALogin();
      return;
    }
    unawaited(_vm.alternarUtil(resena.id));
  }

  String _formatFecha(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 14) return 'Hace 1 semana';
    if (diff.inDays < 30) {
      return 'Hace ${(diff.inDays / 7).floor()} semanas';
    }
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final resenas = _vm.resenas;
    final filtradas = _vm.filtradas;
    final filtroEstrellas = _vm.filtroEstrellas;

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
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Opiniones',
                            style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text(widget.product.nombre,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      PierLog.nav('→ CreateReviewScreen desde reviews');
                      if (auth.isAuthenticated) {
                        unawaited(Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => CreateReviewScreen(
                                  product: widget.product)),
                        ).then((_) => _vm.cargar()));
                      } else {
                        _irALogin();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.pencil,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text('Escribir',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _vm.cargando
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : RefreshIndicator(
                      onRefresh: _vm.cargar,
                      color: AppColors.pierVerde,
                      child: CustomScrollView(
                        slivers: [

                          // ── RESUMEN ────────────────────────────
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: resenas.isEmpty
                                  ? const Center(
                                      child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                          'Aún no hay calificaciones',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14)),
                                    ))
                                  : _buildResumen(),
                            ),
                          ),

                          // ── FILTROS ────────────────────────────
                          if (resenas.isNotEmpty)
                            SliverToBoxAdapter(
                                child: _buildFiltros()),

                          // ── LISTA ──────────────────────────────
                          if (resenas.isEmpty)
                            SliverFillRemaining(
                                child: _buildEmptyState())
                          else if (filtradas.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    'No hay opiniones de $filtroEstrellas estrella${filtroEstrellas == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 32),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child:
                                        _buildReviewCard(filtradas[i]),
                                  ),
                                  childCount: filtradas.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RESUMEN ──────────────────────────────────────────────────────
  Widget _buildResumen() {
    final dist = _vm.distribucion;
    final total = _vm.resenas.length;
    final promedio = _vm.promedio;

    return Row(
      children: [
        Column(
          children: [
            Text(
              promedio.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                        i < promedio.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 16,
                        color: AppColors.pierDorado,
                      )),
            ),
            const SizedBox(height: 4),
            Text('$total reseña${total == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [5, 4, 3, 2, 1].map((star) {
              final count = dist[star] ?? 0;
              final pct = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text('$star',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppColors.textSecondary
                              .withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  AppColors.pierDorado),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text('$count',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── FILTROS ──────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Todas', 0),
            const SizedBox(width: 8),
            ...List.generate(5, (i) {
              final star = 5 - i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChip('$star ★', star),
              );
            }),
            Container(
              width: 1, height: 28,
              color: AppColors.textSecondary.withValues(alpha: 0.2),
              margin: const EdgeInsets.only(right: 8),
            ),
            GestureDetector(
              onTap: _showOrdenSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.textSecondary
                          .withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.arrowUpDown,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      switch (_vm.orden) {
                        OrdenResenas.recientes => 'Recientes',
                        OrdenResenas.mejor => 'Mejor',
                        OrdenResenas.peor => 'Peor',
                      },
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 3),
                    const Icon(LucideIcons.chevronDown,
                        size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int value) {
    final sel = _vm.filtroEstrellas == value;
    return GestureDetector(
      onTap: () => _vm.filtrar(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.pierVerde : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel
                  ? AppColors.pierVerde
                  : AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  void _showOrdenSheet() {
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24,
            MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ordenar por',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ...[
              ('Más recientes', OrdenResenas.recientes,
                  LucideIcons.clock),
              ('Mejor calificación', OrdenResenas.mejor,
                  LucideIcons.thumbsUp),
              ('Peor calificación', OrdenResenas.peor,
                  LucideIcons.thumbsDown),
            ].map((t) {
              final sel = _vm.orden == t.$2;
              return GestureDetector(
                onTap: () {
                  _vm.ordenar(t.$2);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.pierVerde.withValues(alpha: 0.08)
                        : AppColors.textSecondary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: sel
                        ? Border.all(
                            color: AppColors.pierVerde
                                .withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(children: [
                    Icon(t.$3,
                        size: 18,
                        color: sel
                            ? AppColors.pierVerde
                            : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(t.$1,
                            style: TextStyle(
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: sel
                                    ? AppColors.pierVerde
                                    : AppColors.textPrimary))),
                    if (sel)
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.pierVerde, size: 18),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    ));
  }

  // ── CARD DE RESEÑA ───────────────────────────────────────────────
  Widget _buildReviewCard(ResenaProducto r) {
    final nombre = r.autor;
    final rating = r.rating;
    final titulo = r.titulo;
    final comentario = r.comentario;
    final verificada = r.verificada;
    final util = _vm.esUtil(r.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AUTOR + RATING ─────────────────────────────────
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.pierArena,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    nombre.length >= 2
                        ? nombre.substring(0, 2).toUpperCase()
                        : nombre.isNotEmpty
                            ? nombre[0]
                            : '?',
                    style: TextStyle(
                        color: AppColors.pierDoradoOscuro,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    Text(_formatFecha(r.creadaEn),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.pierDorado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Icon(Icons.star_rounded,
                      color: AppColors.pierDorado, size: 13),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierDoradoOscuro)),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (verificada) ...[
            Row(children: [
              Icon(LucideIcons.badgeCheck,
                  size: 14, color: AppColors.pierVerde),
              const SizedBox(width: 4),
              Text('Compra verificada',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.pierVerde,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
          ],

          if (titulo.isNotEmpty) ...[
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
          ],

          Text(comentario,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5)),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _toggleLike(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: util
                        ? AppColors.pierVerde.withValues(alpha: 0.1)
                        : AppColors.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            util
                                ? AppColors.pierVerde
                                    .withValues(alpha: 0.3)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.thumbsUp,
                        size: 14,
                        color: util
                            ? AppColors.pierVerde
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${r.utilCount}',
                        style: TextStyle(
                            fontSize: 12,
                            color: util
                                ? AppColors.pierVerde
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.messageSquare,
                size: 46,
                color: AppColors.pierVerde.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text('Sin opiniones aún',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Sé el primero en calificar\neste producto.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
