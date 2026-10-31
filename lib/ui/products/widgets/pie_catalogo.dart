// lib/ui/products/widgets/pie_catalogo.dart
//
// Pie del catálogo (#37), abajo de la última tarjeta: un indicador mientras
// llega la siguiente página o, si no pudo llegar, el aviso con «Reintentar».
// Con el mismo aspecto que el pie del feed (feed_sliver.dart). Se repinta
// solo cuando cambia el ViewModel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';

class PieCatalogo extends StatelessWidget {
  const PieCatalogo({required this.viewModel, super.key});

  final ProductsViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.cargandoMas) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.pierVerde),
              ),
            );
          }
          final error = viewModel.errorMas;
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  const Icon(LucideIcons.wifiOff,
                      size: 36, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  const Text(
                    'No se pudieron cargar más',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => unawaited(viewModel.cargarMas()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox(height: 24);
        },
      );
}
