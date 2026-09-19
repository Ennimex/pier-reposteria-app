// lib/ui/reviews/widgets/create_review_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/my_reviews_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class CreateReviewScreen extends StatefulWidget {
  final Product product;
  const CreateReviewScreen({super.key, required this.product});

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final _resenasRepo = ResenasRepository();
  final _comentarioCtrl = TextEditingController();
  final _tituloCtrl = TextEditingController();

  int _rating = 0;
  bool _enviando = false;

  final List<String> _ratingLabels = [
    'Selecciona una calificación',
    'Malo 😕',
    'Regular 😐',
    'Bueno 🙂',
    'Muy bueno 😊',
    '¡Excelente! 🤩',
  ];

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ CreateReviewScreen: ${widget.product.nombre}');
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _tituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      PierLog.debug('No autenticado — redirigiendo a login');
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (_rating == 0) {
      _showSnack('Selecciona una calificación', AppColors.error);
      return;
    }
    if (_comentarioCtrl.text.trim().length < 10) {
      _showSnack('El comentario debe tener al menos 10 caracteres',
          AppColors.error);
      return;
    }

    setState(() => _enviando = true);
    final result = await _resenasRepo.crear(
      {
        'producto_id': widget.product.id,
        'rating': _rating,
        'titulo': _tituloCtrl.text.trim(),
        'comentario': _comentarioCtrl.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (result['success'] == true) {
      final autoAprobada = result['resena']?['auto_aprobada'] == true;
      PierLog.info('✅ Reseña enviada — auto_aprobada: $autoAprobada');
      _showSuccessDialog(autoAprobada);
    } else {
      PierLog.error('Error al enviar reseña: ${result['message']}');
      _showSnack(result['message'] ?? 'Error al enviar', AppColors.error);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog(bool autoAprobada) {
    // Capturamos el navigator de la pantalla ANTES de mostrar el diálogo,
    // para no usar el context del State después de que se desmonte al cerrar.
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.check,
                          color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('¡Gracias por tu\nopinión!',
                  style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2)),
              const SizedBox(height: 12),
              Text(
                autoAprobada
                    ? 'Tu reseña ha sido publicada. ¡Otros clientes podrán verla y disfrutar de nuestras delicias!'
                    : 'Tu reseña está en revisión y será publicada pronto. ¡Gracias por tomarte el tiempo!',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(LucideIcons.cake,
                        size: 20,
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.4)),
                  ),
                  Expanded(
                      child: Divider(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.2))),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // cierra el diálogo
                    navigator.pop(); // cierra la pantalla de reseña
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                    elevation: 0,
                  ),
                  child: const Text('Entendido',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(dialogContext).pop(); // cierra el diálogo
                    navigator.pop(); // cierra la pantalla de reseña
                    navigator.push(MaterialPageRoute(
                        builder: (_) => const MyReviewsScreen()));
                  },
                  child: Text('Ver mi reseña',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.pierDoradoOscuro,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
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
                  const Text('Escribir Opinión',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── CARD PRODUCTO ─────────────────────────────
                    Container(
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
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.product.imagenUrl,
                              width: 90, height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 90, height: 90,
                                color: AppColors.pierArena,
                                child: Icon(LucideIcons.cake,
                                    color: AppColors.pierVerde, size: 36),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.pierVerde
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(widget.product.categoria,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.pierVerde,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 6),
                                Text(widget.product.nombre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.textPrimary)),
                                if (widget.product.descripcion.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(widget.product.descripcion,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.7),
                                          height: 1.3),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── ESTRELLAS ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                        children: [
                          const Text('¿Qué te pareció el producto?',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final selected = i < _rating;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _rating = i + 1);
                                  PierLog.debug(
                                      'Rating seleccionado: ${i + 1}');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: Icon(
                                    selected
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: selected
                                        ? const Color(0xFF2D2D2D)
                                        : AppColors.textSecondary
                                            .withValues(alpha: 0.35),
                                    size: 46,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              key: ValueKey(_rating),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: _rating == 0
                                    ? Colors.transparent
                                    : AppColors.textSecondary
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                _ratingLabels[_rating],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _rating == 0
                                        ? AppColors.textSecondary
                                            .withValues(alpha: 0.6)
                                        : AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── TÍTULO ────────────────────────────────────
                    const Text('Título (opcional)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tituloCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ej. Delicioso y fresco',
                        hintStyle: TextStyle(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.6),
                            fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.pierVerde, width: 1.5)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── COMENTARIO ────────────────────────────────
                    const Text('Tu experiencia',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _comentarioCtrl,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            'Cuéntanos qué te gustó más de este past...',
                        hintStyle: TextStyle(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.6),
                            fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.pierVerde, width: 1.5)),
                        contentPadding: const EdgeInsets.all(14),
                        suffixText:
                            '${_comentarioCtrl.text.trim().length} / mín. 10',
                        suffixStyle: TextStyle(
                            fontSize: 11,
                            color: _comentarioCtrl.text.trim().length >= 10
                                ? AppColors.pierVerde
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.6)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── AVISO ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.info,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo puedes reseñar productos que hayas comprado. Las reseñas con calificación ≥ 4 se publican automáticamente.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── BOTÓN PUBLICAR ────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(LucideIcons.send,
                                color: Colors.white, size: 18),
                        label: Text(
                            _enviando
                                ? 'Publicando...'
                                : 'Publicar Opinión',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pierVerde,
                          disabledBackgroundColor:
                              AppColors.pierVerde.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                          elevation: 0,
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
}