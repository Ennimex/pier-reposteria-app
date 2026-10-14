// lib/ui/refunds/widgets/evidencia_fotos.dart
//
// Fotos de evidencia de un reembolso (#117): el selector del formulario
// (miniaturas con «x» y botones de cámara/galería) y el resumen que lleva
// cada solicitud del historial.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Selector del formulario. La cámara y la galería las abre la pantalla
/// ([onCamara], [onGaleria]); aquí solo se pintan las rutas elegidas.
class EvidenciaFotos extends StatelessWidget {
  const EvidenciaFotos({
    required this.fotos,
    required this.maximo,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitar,
    super.key,
  });

  final List<String> fotos;
  final int maximo;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final ValueChanged<String> onQuitar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Fotos de evidencia (opcional)',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            Text('${fotos.length}/$maximo',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Ayudan a revisar tu caso más rápido.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        if (fotos.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final ruta in fotos)
                _Miniatura(ruta: ruta, onQuitar: () => onQuitar(ruta)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (fotos.length < maximo)
          Row(
            children: [
              _BotonFuente(
                  icono: LucideIcons.camera,
                  texto: 'Cámara',
                  onTap: onCamara),
              const SizedBox(width: 10),
              _BotonFuente(
                  icono: LucideIcons.images,
                  texto: 'Galería',
                  onTap: onGaleria),
            ],
          ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.ruta, required this.onQuitar});

  final String ruta;
  final VoidCallback onQuitar;

  static const double _lado = 84;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(ruta),
            width: _lado,
            height: _lado,
            fit: BoxFit.cover,
            // Si el archivo ya no se puede leer, un recuadro en su lugar.
            errorBuilder: (_, _, _) => Container(
              width: _lado,
              height: _lado,
              color: AppColors.pierArena,
              alignment: Alignment.center,
              child: const Icon(LucideIcons.imageOff,
                  color: AppColors.textSecondary),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filled(
            tooltip: 'Quitar foto',
            onPressed: onQuitar,
            iconSize: 14,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.6)),
            icon: const Icon(LucideIcons.x, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _BotonFuente extends StatelessWidget {
  const _BotonFuente({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 18, color: AppColors.pierVerde),
        label: Text(texto, style: TextStyle(color: AppColors.pierVerde)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: AppColors.pierVerde.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Resumen en la tarjeta del historial: miniaturas de las fotos guardadas.
class FotosGuardadas extends StatelessWidget {
  const FotosGuardadas({required this.urls, super.key});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final n = urls.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (final url in urls)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 40,
                    height: 40,
                    color: AppColors.pierArena,
                    child: const Icon(LucideIcons.image,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          Text(n == 1 ? '1 foto de evidencia' : '$n fotos de evidencia',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
