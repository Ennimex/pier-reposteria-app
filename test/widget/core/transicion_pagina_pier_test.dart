// test/widget/core/transicion_pagina_pier_test.dart — TransicionPaginaPier:
// el push de la app (Android e iOS en AppTheme) es el de Cupertino, en
// 400 ms, con el parallax de la página de abajo y el gesto de regresar
// deslizando desde el borde.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/themes/app_theme.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

Widget _app() => MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: TransicionPaginaPier(),
        TargetPlatform.iOS: TransicionPaginaPier(),
      },
    ),
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('Detalle'))),
                ),
              )
              .ignore(),
          child: const Text('Catálogo'),
        ),
      ),
    ),
  ),
);

ModalRoute<dynamic> _detalle(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.text('Detalle')))!;

void main() {
  test('dura 400 ms y le da a la de abajo el parallax de Cupertino', () {
    const transicion = TransicionPaginaPier();
    expect(transicion.transitionDuration, AppMovimiento.empuje);
    expect(transicion.reverseTransitionDuration, AppMovimiento.empuje);
    expect(
      transicion.delegatedTransition,
      CupertinoPageTransition.delegatedTransition,
    );
  });

  test('AppTheme la usa en Android y en iOS', () {
    final builders = AppTheme.lightTheme.pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<TransicionPaginaPier>());
    expect(builders[TargetPlatform.iOS], isA<TransicionPaginaPier>());
  });

  testWidgets('un push termina en 400 ms con el deslizamiento de Cupertino', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final antes = tester.getCenter(find.text('Catálogo')).dx;

    await tester.tap(find.text('Catálogo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CupertinoPageTransition), findsWidgets);
    // La página de abajo se corre hacia la izquierda (parallax).
    expect(tester.getCenter(find.text('Catálogo')).dx, lessThan(antes));
    expect(_detalle(tester).animation!.isCompleted, isFalse);

    await tester.pump(const Duration(milliseconds: 210));
    expect(_detalle(tester).animation!.isCompleted, isTrue);
  });

  testWidgets('se puede regresar deslizando desde el borde', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsOneWidget);

    await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsNothing);
    expect(find.text('Catálogo'), findsOneWidget);
  });
}
