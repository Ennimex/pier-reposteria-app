// lib/ui/core/ui/explicacion_permiso.dart
//
// Antes de pedir un permiso o de abrir la cámara, la app explica para qué
// (#227, docs/PERMISOS.md). Si el cliente dice «Ahora no», no se pide nada.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';

/// Qué se pide y para qué.
class ExplicacionDePermiso {
  const ExplicacionDePermiso({
    required this.icono,
    required this.titulo,
    required this.mensaje,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;

  static const ubicacion = ExplicacionDePermiso(
    icono: LucideIcons.mapPin,
    titulo: 'Usar tu ubicación',
    mensaje: 'Pier usa tu ubicación solo para guardar el punto exacto de esta '
        'dirección, para que el repartidor llegue sin perderse. No se lee en '
        'ningún otro momento. Después Android te preguntará si das el permiso.',
  );

  static const camaraReembolso = ExplicacionDePermiso(
    icono: LucideIcons.camera,
    titulo: 'Tomar una foto',
    mensaje: 'Abriremos la cámara para que tomes la foto del producto. La foto '
        'solo se manda con tu solicitud de reembolso.',
  );

  static const camaraEntrega = ExplicacionDePermiso(
    icono: LucideIcons.camera,
    titulo: 'Foto de la entrega',
    mensaje: 'Abriremos la cámara para la foto que confirma la entrega. Solo '
        'se guarda con este pedido.',
  );
}

/// Muestra [explicacion] y devuelve true si el cliente quiere seguir.
Future<bool> explicarPermiso(
  BuildContext context,
  ExplicacionDePermiso explicacion,
) async {
  final sigue = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      icon: Icon(explicacion.icono, color: AppColors.pierVerde),
      title: Text(explicacion.titulo),
      content: Text(explicacion.mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.pierVerde),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  return sigue ?? false;
}
