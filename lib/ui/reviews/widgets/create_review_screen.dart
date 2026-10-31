// lib/ui/reviews/widgets/create_review_screen.dart
//
// Movimiento: la tarjeta del producto, las estrellas, los campos, el aviso y
// el botón suben en cascada después del push (la foto aparece con fundido).
// Al calificar, las estrellas que se encienden dan un pop una tras otra y la
// etiqueta rueda; sin calificación se sacuden las estrellas y con un
// comentario corto, el campo. El botón cambia en sitio mientras publica y
// el diálogo de gracias se abre como caja, con chispas si quedó publicada.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/auth/widgets/login_screen.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';
import 'package:pier_reposteria/ui/reviews/view_model/create_review_view_model.dart';
import 'package:pier_reposteria/ui/reviews/widgets/my_reviews_screen.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:provider/provider.dart';

class CreateReviewScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const CreateReviewScreen({
    required this.product,
    super.key,
    this.viewModel,
  });

  final Product product;
  final CreateReviewViewModel? viewModel;

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final _comentarioCtrl = TextEditingController();
  final _tituloCtrl = TextEditingController();

  // El State es dueño del ViewModel (lo crea y lo libera).
  late final CreateReviewViewModel _vm = widget.viewModel ??
      CreateReviewViewModel(
        repo: context.read<ResenasRepository>(),
        productoId: widget.product.id,
      );

  final List<String> _ratingLabels = [
    'Selecciona una calificación',
    'Malo 😕',
    'Regular 😐',
    'Bueno 🙂',
    'Muy bueno 😊',
    '¡Excelente! 🤩',
  ];

  // Lo que se sacude cuando no se puede publicar (el aviso es el de siempre).
  final _sacudirEstrellas = ValueNotifier<int>(0);
  final _sacudirComentario = ValueNotifier<int>(0);

  // La etiqueta sube al mejorar la calificación y baja al empeorarla.
  int _ratingPrevio = 0;
  int _sentidoEtiqueta = 1;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ CreateReviewScreen: ${widget.product.nombre}');
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _tituloCtrl.dispose();
    _sacudirEstrellas.dispose();
    _sacudirComentario.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Sentido en que rueda la etiqueta: 1 si la calificación subió, -1 si
  /// bajó.
  int _sentido(int rating) {
    if (rating != _ratingPrevio) {
      _sentidoEtiqueta = rating > _ratingPrevio ? 1 : -1;
      _ratingPrevio = rating;
    }
    return _sentidoEtiqueta;
  }

  Future<void> _enviar() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      PierLog.debug('No autenticado — redirigiendo a login');
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen())).ignore();
      return;
    }

    final autoAprobada = await _vm.enviar(titulo: _tituloCtrl.text);
    if (!mounted) return;

    if (autoAprobada != null) {
      PierLog.info('✅ Reseña enviada — auto_aprobada: $autoAprobada');
      _showSuccessDialog(autoAprobada);
    } else if (_vm.error != null) {
      PierLog.error('Reseña no enviada: ${_vm.error}');
      _sacudirLoQueFalta();
      _showSnack(_vm.error!, AppColors.error);
    }
  }

  /// Sacude lo que impidió publicar, en el orden en que lo revisa el
  /// ViewModel: primero la calificación, después el comentario. Un rechazo
  /// del backend no sacude nada.
  void _sacudirLoQueFalta() {
    if (_vm.rating == 0) {
      _sacudirEstrellas.value++;
    } else if (!_vm.comentarioValido) {
      _sacudirComentario.value++;
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
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      // Se abre como caja (fundido corto + EntradaDialogo); la insignia cae
      // (con chispas si la reseña ya quedó publicada) y el texto sube detrás.
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) {
        final espera = esperaDePagina(dialogContext);
        return EntradaDialogo(
          child: Dialog(
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
                    child: InsigniaExito(
                      opacidadHalo: 0.15,
                      conChispas: autoAprobada,
                    ),
                  ),
                  const SizedBox(height: 24),
                  EntradaSuave(
                    retraso: espera,
                    child: const Text('¡Gracias por tu\nopinión!',
                        style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.2)),
                  ),
                  const SizedBox(height: 12),
                  EntradaSuave(
                    orden: 1,
                    retraso: espera,
                    child: Text(
                      autoAprobada
                          ? 'Tu reseña ha sido publicada. ¡Otros clientes podrán verla y disfrutar de nuestras delicias!'
                          : 'Tu reseña está en revisión y será publicada pronto. ¡Gracias por tomarte el tiempo!',
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  EntradaSuave(
                    orden: 2,
                    retraso: espera,
                    child: Row(
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
                  ),
                  const SizedBox(height: 20),
                  EntradaSuave(
                    orden: 3,
                    retraso: espera,
                    child: SizedBox(
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
                  ),
                  const SizedBox(height: 12),
                  EntradaSuave(
                    orden: 4,
                    retraso: espera,
                    child: Center(
                      child: PresionEscala(
                        escala: AppMovimiento.escalaPresionChica,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(dialogContext).pop(); // cierra el diálogo
                            navigator
                              ..pop() // cierra la pantalla de reseña
                              ..push(MaterialPageRoute(
                                  builder: (_) => const MyReviewsScreen())).ignore();
                          },
                          child: Text('Ver mi reseña',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.pierDoradoOscuro,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ));
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
    final rating = _vm.rating;
    final enviando = _vm.enviando;
    // Los bloques suben en cascada después del push (se lee al montarse:
    // escribir o calificar no lo repite).
    final espera = esperaDePagina(context);
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
                    EntradaSuave(
                      retraso: espera,
                      child: Container(
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
                                // Si llega de la red, aparece con un fundido.
                                frameBuilder: (_, foto, cuadro, sincrona) =>
                                    FotoAlLlegar(
                                        foto: foto,
                                        cuadro: cuadro,
                                        sincrona: sincrona),
                                errorBuilder: (_, _, _) => Container(
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
                    ),
                    const SizedBox(height: 16),

                    // ── ESTRELLAS ─────────────────────────────────
                    // Sin calificación al publicar, la tarjeta se sacude.
                    EntradaSuave(
                      orden: 1,
                      retraso: espera,
                      child: SacudidaConAviso(
                        aviso: _sacudirEstrellas,
                        child: Container(
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
                              // Las que se encienden dan un pop en fila (el ícono
                              // cambia al instante; solo se mueve).
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (i) {
                                  final selected = i < rating;
                                  return GestureDetector(
                                    onTap: () {
                                      _vm.calificar(i + 1);
                                      PierLog.debug(
                                          'Rating seleccionado: ${i + 1}');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: EstrellaAnimada(
                                        indice: i,
                                        calificacion: rating,
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
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 12),
                              // La etiqueta rueda: sube si la calificación
                              // mejora y baja si empeora.
                              CambioAnimado(
                                tipo: TipoCambio.subir,
                                direccion: _sentido(rating),
                                alineacion: Alignment.center,
                                child: Container(
                                  key: ValueKey(rating),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: rating == 0
                                        ? Colors.transparent
                                        : AppColors.textSecondary
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Text(
                                    _ratingLabels[rating],
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: rating == 0
                                            ? AppColors.textSecondary
                                                .withValues(alpha: 0.6)
                                            : AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── TÍTULO ────────────────────────────────────
                    EntradaSuave(
                      orden: 2,
                      retraso: espera,
                      child: const Text('Título (opcional)',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    const SizedBox(height: 8),
                    EntradaSuave(
                      orden: 2,
                      retraso: espera,
                      child: TextField(
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
                    ),
                    const SizedBox(height: 16),

                    // ── COMENTARIO ────────────────────────────────
                    EntradaSuave(
                      orden: 3,
                      retraso: espera,
                      child: const Text('Tu experiencia',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    const SizedBox(height: 8),
                    // Un comentario demasiado corto al publicar sacude el
                    // campo.
                    EntradaSuave(
                      orden: 3,
                      retraso: espera,
                      child: SacudidaConAviso(
                        aviso: _sacudirComentario,
                        child: TextField(
                          controller: _comentarioCtrl,
                          maxLines: 5,
                          onChanged: _vm.editarComentario,
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
                                '${_vm.largoComentario} / mín. ${CreateReviewViewModel.minimoComentario}',
                            suffixStyle: TextStyle(
                                fontSize: 11,
                                color: _vm.comentarioValido
                                    ? AppColors.pierVerde
                                    : AppColors.textSecondary
                                        .withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── AVISO ─────────────────────────────────────
                    EntradaSuave(
                      orden: 4,
                      retraso: espera,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.15)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.info,
                                size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                // #41: ni la app ni el backend limitan la
                                // reseña a lo comprado; la compra solo la
                                // marca como verificada.
                                'Si compraste este producto, tu reseña aparecerá como compra verificada. Algunas reseñas pasan por revisión antes de publicarse.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── BOTÓN PUBLICAR ────────────────────────────
                    // «Publicar Opinión» ↔ «Publicando...» en el mismo
                    // botón: el ícono cambia con un pop y el texto con un
                    // fundido.
                    EntradaSuave(
                      orden: 5,
                      retraso: espera,
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: enviando ? null : _enviar,
                          icon: CambioAnimado(
                            tipo: TipoCambio.escalar,
                            alineacion: Alignment.center,
                            child: enviando
                                ? const SizedBox(
                                    key: ValueKey('publicando'),
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(LucideIcons.send,
                                    key: ValueKey('publicar'),
                                    color: Colors.white, size: 18),
                          ),
                          label: TamanoSuave(
                            alineacion: Alignment.center,
                            child: CambioAnimado(
                              alineacion: Alignment.center,
                              child: Text(
                                  enviando
                                      ? 'Publicando...'
                                      : 'Publicar Opinión',
                                  key: ValueKey(enviando),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
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
