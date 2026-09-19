// lib/ui/repartidor/widgets/confirmar_entrega_screen.dart
//
// Confirma una entrega: quién recibió, evidencia opcional y (si aplica) cobro
// en efectivo. Marca la entrega como "entregada".
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class ConfirmarEntregaScreen extends StatefulWidget {
  final EntregaRepartidor entrega;
  const ConfirmarEntregaScreen({super.key, required this.entrega});

  @override
  State<ConfirmarEntregaScreen> createState() => _ConfirmarEntregaScreenState();
}

class _ConfirmarEntregaScreenState extends State<ConfirmarEntregaScreen> {
  final _recibioController = TextEditingController();
  final _picker = ImagePicker();
  File? _evidencia;
  bool _enviando = false;

  @override
  void dispose() {
    _recibioController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (img != null) setState(() => _evidencia = File(img.path));
    } catch (_) {
      if (mounted) _snack('No se pudo acceder a la imagen');
    }
  }

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.pierVerde,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmar() async {
    final recibio = _recibioController.text.trim();
    if (recibio.isEmpty) {
      _snack('Indica quién recibió el pedido');
      return;
    }

    setState(() => _enviando = true);
    final provider = context.read<EntregasProvider>();

    String? evidenciaUrl;
    if (_evidencia != null) {
      evidenciaUrl = await provider.subirEvidencia(_evidencia!.path);
      if (evidenciaUrl == null && mounted) {
        // No bloqueamos la entrega por un fallo de subida; avisamos y seguimos.
        _snack('No se pudo subir la foto, se confirmará sin evidencia');
      }
    }

    final res = await provider.cambiarEstado(
      widget.entrega.id,
      EstadoEntrega.entregada,
      recibioNombre: recibio,
      evidenciaUrl: evidenciaUrl,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (res['success'] == true) {
      _snack('Entrega confirmada', error: false);
      Navigator.pop(context, true);
    } else {
      _snack(res['message']?.toString() ?? 'No se pudo confirmar la entrega');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final e = widget.entrega;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Confirmar entrega')),
      body: SafeArea(
        child: ListView(
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
                prefixIcon: Icon(LucideIcons.user,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Agregar foto de evidencia',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
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
            if (_evidencia != null)
              _preview()
            else
              Row(
                children: [
                  _sourceButton(
                    icon: LucideIcons.camera,
                    label: 'Cámara',
                    color: AppColors.pierVerde,
                    onTap: () => _pick(ImageSource.camera),
                  ),
                  const SizedBox(width: 14),
                  _sourceButton(
                    icon: LucideIcons.images,
                    label: 'Galería',
                    color: AppColors.textSecondary,
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            _cobroCard(e),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _confirmar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(_enviando ? 'Confirmando…' : 'Confirmar entrega'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _enviando ? null : () => Navigator.pop(context),
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
        ),
      ),
    );
  }

  Widget _preview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _evidencia!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() => _evidencia = null),
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

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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

  Widget _cobroCard(EntregaRepartidor e) {
    final esEfectivo = e.esEfectivo;
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoneyMxn(e.total),
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
