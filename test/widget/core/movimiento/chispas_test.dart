// test/widget/core/movimiento/chispas_test.dart — Chispas: una ráfaga
// pintada (chispitas y chochitos) que termina sola dentro de 1.6 s, nunca
// bloquea toques, respeta su retraso y no aparece con «reducir movimiento».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// Un botón con la ráfaga encima, como en la pantalla de éxito.
Widget _escena(VoidCallback alTocar, {Duration retraso = Duration.zero}) =>
    SizedBox(
      width: 400,
      height: 600,
      child: Stack(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: alTocar,
              child: const Text('Seguir'),
            ),
          ),
          Positioned.fill(child: Chispas(retraso: retraso)),
        ],
      ),
    );

RenderObject _lienzo(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byType(Chispas),
    matching: find.byType(CustomPaint),
  ),
);

void main() {
  testWidgets('pinta una ráfaga que termina sola', (tester) async {
    await montarMovimiento(tester, _escena(() {}));
    expect(_lienzo(tester), paintsNothing);

    await tester.pump(); // primer tick (arrancó en un post-frame)
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      _lienzo(tester),
      paints
        ..rrect()
        ..circle(),
    );

    // Finita: pumpAndSettle termina y ya no queda nada pintado.
    await tester.pumpAndSettle();
    expect(_lienzo(tester), paintsNothing);
  });

  testWidgets('no bloquea los toques de lo que tiene debajo', (tester) async {
    var toques = 0;
    await montarMovimiento(tester, _escena(() => toques++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Seguir'));
    expect(toques, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('respeta su retraso', (tester) async {
    await montarMovimiento(
      tester,
      _escena(() {}, retraso: const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lienzo(tester), paintsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lienzo(tester), paints..rrect());
    await tester.pumpAndSettle();
  });

  testWidgets('con movimiento reducido no aparece', (tester) async {
    await montarMovimiento(tester, _escena(() {}), reducido: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lienzo(tester), paintsNothing);
  });
}
