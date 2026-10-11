// lib/ui/repartidor/widgets/confirmar_entrega_screen.dart
//
// Confirma una entrega (MVVM, Fase 5): quién recibió, evidencia opcional y
// (si aplica) cobro en efectivo. Marca la entrega como «entregada» y se
// cierra con true. El estado vive en ConfirmarEntregaViewModel; la cámara y
// la galería (image_picker) se quedan en la vista.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/confirmar_entrega_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class ConfirmarEntregaScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo
  /// con [entrega].
  const ConfirmarEntregaScreen({
    required this.entrega,
    super.key,
    this.alCambiar,
    this.viewModel,
  });

  final EntregaRepartidor entrega;

  /// Se llama (y se espera) al confirmar, para que el panel se ponga al día.
  final Future<void> Function()? alCambiar;
  final ConfirmarEntregaViewModel? viewModel;

  @override
  State<ConfirmarEntregaScreen> createState() => _ConfirmarEntregaScreenState();
}

class _ConfirmarEntregaScreenState extends State<ConfirmarEntregaScreen> {
  late final ConfirmarEntregaViewModel _vm = widget.viewModel ??
      ConfirmarEntregaViewModel(
        repo: context.read(),
        entrega: widget.entrega,
        alCambiar: widget.alCambiar,
      );
  final _recibioController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _recibioController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (img != null) _vm.elegirEvidencia(img.path);
    } on Exception {
      if (mounted) mostrarAviso(context, 'No se pudo acceder a la imagen');
    }
  }

  Future<void> _confirmar() async {
    final r = await _vm.confirmar(_recibioController.text);
    if (!mounted) return;
    if (_vm.fotoSinSubir) {
      // No se bloqueó la entrega por un fallo de subida; solo se avisa.
      mostrarAviso(
          context, 'No se pudo subir la foto, se confirmará sin evidencia');
    }
    mostrarAviso(context, r.mensaje, ok: r.ok);
    if (r.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Confirmar entrega')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => _formulario(),
        ),
      ),
    );
  }

  Widget _formulario() {
    final evidencia = _vm.evidencia;
    final enviando = _vm.enviando;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '¿Quién recibió el pedido?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _recibioController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Ej. María Alejandra',
            prefixIcon: Icon(LucideIcons.user, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Agregar foto de evidencia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              'Opcional',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (evidencia != null)
          _VistaPrevia(ruta: evidencia, onQuitar: _vm.quitarEvidencia)
        else
          Row(
            children: [
              _BotonFuente(
                icon: LucideIcons.camera,
                label: 'Cámara',
                color: AppColors.pierVerde,
                onTap: () => _pick(ImageSource.camera),
              ),
              const SizedBox(width: 14),
              _BotonFuente(
                icon: LucideIcons.images,
                label: 'Galería',
                color: AppColors.textSecondary,
                onTap: () => _pick(ImageSource.gallery),
              ),
            ],
          ),
        const SizedBox(height: 24),
        _CobroCard(entrega: _vm.entrega),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: enviando ? null : _confirmar,
            icon: IconoCargando(
              icono: Icons.check_circle_outline,
              cargando: enviando,
              tamano: 20,
              color: Colors.white,
            ),
            label: Text(enviando ? 'Confirmando…' : 'Confirmar entrega'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: enviando ? null : () => Navigator.pop(context),
            child: Text(
              'Regresar',
              style: TextStyle(
                color: AppColors.pierVerde,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Foto elegida con una «x» para quitarla.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({required this.ruta, required this.onQuitar});

  final String ruta;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(ruta),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            // Si el archivo ya no se puede leer, un recuadro en su lugar.
            errorBuilder: (_, _, _) => Container(
              height: 180,
              color: AppColors.pierArena,
              alignment: Alignment.center,
              child: const Icon(LucideIcons.imageOff,
                  size: 40, color: AppColors.textSecondary),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onQuitar,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.x, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón grande para elegir la foto con la cámara o de la galería.
class _BotonFuente extends StatelessWidget {
  const _BotonFuente({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.pierArena,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuánto se cobra (efectivo) o que ya se pagó en la app.
class _CobroCard extends StatelessWidget {
  const _CobroCard({required this.entrega});

  final EntregaRepartidor entrega;

  @override
  Widget build(BuildContext context) {
    final esEfectivo = entrega.esEfectivo;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pierArena,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: esEfectivo ? AppColors.pierVerde : AppColors.pierDorado,
              shape: BoxShape.circle,
            ),
            child: Icon(
              esEfectivo ? LucideIcons.banknote : LucideIcons.creditCard,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esEfectivo ? 'Cobro en efectivo' : 'Pagado en la app',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoneyMxn(entrega.total),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
