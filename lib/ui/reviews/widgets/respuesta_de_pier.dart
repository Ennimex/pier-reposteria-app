// lib/ui/reviews/widgets/respuesta_de_pier.dart
//
// La respuesta de Pier Repostería bajo una opinión (#138): la escribe el
// personal desde «Atención a clientes» y se ve en el detalle del producto y
// en todas sus opiniones.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';

class RespuestaDePier extends StatelessWidget {
  const RespuestaDePier(this.respuesta, {super.key});

  final String respuesta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pierVerde.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pierVerde.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.store, size: 14, color: AppColors.pierVerde),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Respuesta de Pier Repostería',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pierVerde,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            respuesta,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.pierVerdeOscuro,
            ),
          ),
        ],
      ),
    );
  }
}
