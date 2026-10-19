// lib/ui/products/widgets/detalle_badges.dart
//
// Badges redondeados del detalle de producto (galería, sección de info y
// tarjetas de recomendados), igual que el PromoBadge de la web.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/products/widgets/movimiento_catalogo.dart';

/// Píldora de color con ícono y texto; [compacto] para las tarjetas.
class DetalleBadge extends StatelessWidget {
  const DetalleBadge({
    required this.color,
    required this.icon,
    required this.label,
    this.compacto = false,
    this.brillo = false,
    super.key,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool compacto;

  /// Un destello de luz la cruza una vez cuando la página ya llegó (la
  /// oferta relámpago del detalle).
  final bool brillo;

  static const BorderRadius _radio = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final pildora = Container(
      padding: EdgeInsets.symmetric(
          horizontal: compacto ? 6 : 10, vertical: compacto ? 3 : 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: _radio,
        boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.4), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: compacto ? 9 : 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compacto ? 8 : 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: brillo
          ? BrilloUnaVez(
              radio: _radio,
              // Después de que la hoja del detalle terminó de llegar.
              retraso: AppMovimiento.entrada +
                  AppMovimiento.paso * AppMovimiento.pasosMaximos,
              child: pildora,
            )
          : pildora,
    );
  }
}

/// Badge del tipo de promoción (relámpago, temporada, nuevo o destacado con
/// su texto). Cada promoción tiene un solo tipo: lista vacía o de uno.
/// [largo] usa los textos del detalle ("Oferta Relámpago", el nombre de la
/// temporada); si no, los cortos de las tarjetas ("Flash", "Temporada"). En
/// el detalle, la oferta relámpago lleva un destello que la cruza una vez.
List<Widget> badgeDeTipoPromo(
  Map<String, dynamic>? promo, {
  required bool largo,
  bool compacto = false,
}) {
  final tipo = promo?['tipo']?.toString() ?? '';
  final destacado = promo?['badge_destacado']?.toString();
  final temporada = promo?['nombre_temporada']?.toString();
  final badge = switch (tipo) {
    'relampago' => (
        Colors.orange.shade600,
        LucideIcons.zap,
        largo ? 'Oferta Relámpago' : 'Flash'
      ),
    'temporada' => (
        Colors.orange.shade700,
        LucideIcons.sparkles,
        largo ? (temporada ?? 'De Temporada') : 'Temporada'
      ),
    'nuevo' => (Colors.blue.shade500, LucideIcons.badgePlus, 'Nuevo'),
    'destacado' when destacado != null =>
      (Colors.purple.shade500, LucideIcons.sparkles, destacado),
    _ => null,
  };
  if (badge == null) return const [];
  return [
    DetalleBadge(
        color: badge.$1,
        icon: badge.$2,
        label: badge.$3,
        compacto: compacto,
        brillo: largo && tipo == 'relampago'),
  ];
}
