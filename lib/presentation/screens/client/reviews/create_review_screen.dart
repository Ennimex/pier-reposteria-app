// lib/presentation/screens/client/reviews/create_review_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/product_model.dart';
import 'package:provider/provider.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../auth/login_screen.dart';

class CreateReviewScreen extends StatefulWidget {
  final Product product;
  const CreateReviewScreen({super.key, required this.product});

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final ApiService _api = ApiService();
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
      _showSnack('Selecciona una calificación', Colors.red);
      return;
    }
    if (_comentarioCtrl.text.trim().length < 10) {
      _showSnack('El comentario debe tener al menos 10 caracteres',
          Colors.red);
      return;
    }

    setState(() => _enviando = true);
    PierLog.api('POST ${ApiConstants.crearResena}');

    final result = await _api.postAuth(
      ApiConstants.crearResena,
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
      _showSnack(result['message'] ?? 'Error al enviar', Colors.red);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => Dialog(
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
                        color: Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 56, height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.pierVerde,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
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
                    fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Colors.grey.withValues(alpha: 0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.cake_outlined,
                        size: 20,
                        color: Colors.grey.withValues(alpha: 0.4)),
                  ),
                  Expanded(
                      child: Divider(
                          color: Colors.grey.withValues(alpha: 0.2))),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
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
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Ver mi reseña',
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
                      child: const Icon(Icons.arrow_back_ios_new,
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
                                child: const Icon(Icons.cake_outlined,
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
                                      style: const TextStyle(
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
                                          color: Colors.grey[500],
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
                                        : Colors.grey[300],
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
                                    : Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                _ratingLabels[_rating],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _rating == 0
                                        ? Colors.grey[400]
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
                            color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
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
                            color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.pierVerde, width: 1.5)),
                        contentPadding: const EdgeInsets.all(14),
                        suffixText:
                            '${_comentarioCtrl.text.trim().length} / mín. 10',
                        suffixStyle: TextStyle(
                            fontSize: 11,
                            color: _comentarioCtrl.text.trim().length >= 10
                                ? AppColors.pierVerde
                                : Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── AVISO ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo puedes reseñar productos que hayas comprado. Las reseñas con calificación ≥ 4 se publican automáticamente.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
                            : const Icon(Icons.send_rounded,
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