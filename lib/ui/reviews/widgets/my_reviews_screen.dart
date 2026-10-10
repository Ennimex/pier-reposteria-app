// lib/ui/reviews/widgets/my_reviews_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/mi_resena.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/themes/app_dimensions.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/my_reviews_view_model.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

class MyReviewsScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const MyReviewsScreen({super.key, this.viewModel});

  final MyReviewsViewModel? viewModel;

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final MyReviewsViewModel _vm =
      widget.viewModel ?? MyReviewsViewModel(repo: context.read<ResenasRepository>());

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ MyReviewsScreen');
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _editarResena(MiResena r) async {
    final cambios = await showModalBottomSheet<_CambiosResena>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarResenaSheet(resena: r),
    );
    if (cambios == null || !mounted) return;
    final mensaje = await _vm.editar(
      r,
      rating: cambios.rating,
      titulo: cambios.titulo,
      comentario: cambios.comentario,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  String _formatFecha(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
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
    final resenas = _vm.resenas;
    final cargando = _vm.cargando;
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
                  const Text('Mis Reseñas',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (!cargando && resenas.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${resenas.length}',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: cargando
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : resenas.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => _vm.cargar(silenciosa: true),
                          color: AppColors.pierVerde,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: resenas.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) =>
                                _buildCard(resenas[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(MiResena r) {
    final rating = r.rating;
    final titulo = r.titulo;
    final comentario = r.comentario;
    final productoNombre = r.productoNombre;
    final productoImagen = r.productoImagen;
    final respuesta = r.respuestaNegocio;
    final motivo = r.motivoRechazo;

    final (estadoColor, estadoLabel, estadoIcon) = switch (r.estado) {
      EstadoResena.aprobada => (
          AppColors.pierVerde,
          'Publicada',
          Icons.check_circle_rounded,
        ),
      EstadoResena.rechazada => (
          Colors.red.shade400,
          'Rechazada',
          LucideIcons.circleX,
        ),
      EstadoResena.enRevision => (
          Colors.orange.shade400,
          'En revisión',
          LucideIcons.hourglass,
        ),
    };

    return Container(
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
          // ── PRODUCTO ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: productoImagen.isNotEmpty
                      ? Image.network(
                          productoImagen,
                          width: 52, height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _productoPlaceholder(),
                        )
                      : _productoPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(productoNombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(_formatFecha(r.creadaEn),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(estadoIcon, size: 12, color: estadoColor),
                    const SizedBox(width: 4),
                    Text(estadoLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: estadoColor,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                GestureDetector(
                  onTap: () => _editarResena(r),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Icon(LucideIcons.pencil,
                        size: 18, color: AppColors.pierVerde),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),

          // ── CALIFICACIÓN + CONTENIDO ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ...List.generate(
                      5,
                      (i) => Icon(
                            i < rating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: i < rating.round()
                                ? Colors.amber
                                : Colors.grey[300],
                          )),
                  const SizedBox(width: 8),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ]),
                if (titulo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                ],
                const SizedBox(height: 6),
                Text(comentario,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4)),

                // Respuesta del negocio
                if (respuesta != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pierArena,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.pierDorado
                              .withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('✦ ',
                              style: TextStyle(
                                  color: AppColors.pierDorado,
                                  fontSize: 12)),
                          Text('Respuesta de Pier',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.pierDoradoOscuro)),
                        ]),
                        const SizedBox(height: 4),
                        Text(respuesta,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],

                // Motivo de rechazo
                if (r.estado == EstadoResena.rechazada &&
                    motivo != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info,
                            size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(motivo,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productoPlaceholder() => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.pierArena,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(LucideIcons.cake,
            color: AppColors.pierVerde, size: 24),
      );

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
          const Text('Sin reseñas aún',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Cuando compres y califiques un producto\naparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ── HOJA DE EDICIÓN DE RESEÑA ──────────────────────────────────────
/// Lo capturado en la hoja; null si se canceló.
typedef _CambiosResena = ({int rating, String titulo, String comentario});

class _EditarResenaSheet extends StatefulWidget {
  const _EditarResenaSheet({required this.resena});

  final MiResena resena;

  @override
  State<_EditarResenaSheet> createState() => _EditarResenaSheetState();
}

class _EditarResenaSheetState extends State<_EditarResenaSheet> {
  late int _rating;
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _comentarioCtrl;

  @override
  void initState() {
    super.initState();
    _rating = widget.resena.estrellas.clamp(1, 5);
    _tituloCtrl = TextEditingController(text: widget.resena.titulo);
    _comentarioCtrl = TextEditingController(text: widget.resena.comentario);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _comentarioCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final comentario = _comentarioCtrl.text.trim();
    if (comentario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El comentario es obligatorio')),
      );
      return;
    }
    Navigator.pop<_CambiosResena>(context, (
      rating: _rating,
      titulo: _tituloCtrl.text.trim(),
      comentario: comentario,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final productoNombre = widget.resena.productoNombre;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppDimensions.space20, AppDimensions.space12,
            AppDimensions.space20, AppDimensions.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            const Text('Editar reseña',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            if (productoNombre.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(productoNombre,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 34,
                      color: filled ? Colors.amber : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppDimensions.space16),
            TextField(
              controller: _tituloCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'Título (opcional)'),
            ),
            const SizedBox(height: AppDimensions.space12),
            TextField(
              controller: _comentarioCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'Tu comentario'),
            ),
            const SizedBox(height: AppDimensions.space20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _guardar,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
