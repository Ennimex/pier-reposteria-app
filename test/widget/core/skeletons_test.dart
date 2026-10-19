// test/widget/core/skeletons_test.dart — los esqueletos de carga: brillan
// con los colores de la paleta, cada uno aislado en su RepaintBoundary, y
// con «reducir movimiento» quedan quietos.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/skeletons.dart';
import 'package:shimmer/shimmer.dart';

import '../../helpers/movimiento.dart';

Widget _esqueletos() => const SizedBox(
  width: 300,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: 200, child: ProductSkeletonCard()),
      OrderSkeletonCard(),
    ],
  ),
);

void main() {
  testWidgets('brillan con la paleta, cada uno en su RepaintBoundary', (
    tester,
  ) async {
    await montarMovimiento(tester, _esqueletos());

    final brillos = tester.widgetList<Shimmer>(find.byType(Shimmer));
    expect(brillos, hasLength(2));
    for (final brillo in brillos) {
      expect(brillo.enabled, isTrue);
      expect(brillo.gradient.colors.first, AppColors.pierArenaOscuro);
    }
    expect(
      find.ancestor(
        of: find.byType(Shimmer),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('con movimiento reducido el brillo queda quieto', (
    tester,
  ) async {
    await montarMovimiento(tester, _esqueletos(), reducido: true);

    for (final brillo in tester.widgetList<Shimmer>(find.byType(Shimmer))) {
      expect(brillo.enabled, isFalse);
    }
  });
}
