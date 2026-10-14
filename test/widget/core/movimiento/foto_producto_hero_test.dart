// test/widget/core/movimiento/foto_producto_hero_test.dart — FotoProductoHero
// conserva la etiqueta de siempre (producto-img-<id>), vuela la foto de la
// tarjeta al detalle con esquinas que se enderezan, deja un hueco arena en la
// tarjeta y no vuela con «reducir movimiento».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

const BorderRadius _radioTarjeta = BorderRadius.all(Radius.circular(20));

/// Catálogo con una tarjeta (foto 100×100) que abre el detalle (foto 300×300).
class _Catalogo extends StatelessWidget {
  const _Catalogo({this.imagenUrl = ''});

  final String imagenUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: FotoProductoHero(
                  productoId: 7,
                  imagenUrl: imagenUrl,
                  marcador: false,
                  child: const SizedBox.square(
                    dimension: 300,
                    child: ColoredBox(color: Colors.brown),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: FotoProductoHero(
          productoId: 7,
          imagenUrl: imagenUrl,
          radio: _radioTarjeta,
          child: const SizedBox.square(
            dimension: 100,
            child: ColoredBox(color: Colors.orange),
          ),
        ),
      ),
    ),
  );
}

/// El ClipRRect del vuelo (el único del árbol en estas pruebas).
Finder get _vuelo => find.byType(ClipRRect);

/// La app con el push de Pier (Cupertino a 400 ms), como en producción.
Widget _app({String imagenUrl = ''}) => MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: TransicionPaginaPier()},
    ),
  ),
  home: _Catalogo(imagenUrl: imagenUrl),
);

void main() {
  test('la etiqueta es la de siempre, con ámbito opcional', () {
    expect(FotoProductoHero.etiqueta(7), 'producto-img-7');
    expect(
      FotoProductoHero.etiqueta('7', ambito: 'inicio-destacados'),
      'producto-img-inicio-destacados-7',
    );
  });

  testWidgets('la foto vuela al detalle y las esquinas se enderezan', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byType(GestureDetector));
    await tester.pump(); // cuadro de medición de los Hero
    await tester.pump(const Duration(milliseconds: 150));

    expect(_vuelo, findsOneWidget);
    final radio = tester
        .widget<ClipRRect>(_vuelo)
        .borderRadius
        .resolve(TextDirection.ltr)
        .topLeft
        .x;
    expect(radio, inExclusiveRange(0, 20));
    final lado = tester.getSize(_vuelo).width;
    expect(lado, inExclusiveRange(100, 300));

    // La tarjeta deja un hueco arena mientras la foto vuela.
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.pierArena,
      ),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(_vuelo, findsNothing);
    expect(tester.getSize(find.byType(FotoProductoHero).last).width, 300);
  });

  testWidgets('al regresar la foto vuelve a la tarjeta', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_vuelo, findsOneWidget);

    await tester.pumpAndSettle();
    expect(_vuelo, findsNothing);
    expect(find.byType(FotoProductoHero), findsOneWidget);
  });

  testWidgets('con una URL vuela la imagen de la tarjeta', (tester) async {
    await tester.pumpWidget(_app(imagenUrl: 'https://pier.mx/a.png'));
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.descendant(of: _vuelo, matching: find.byType(Image)),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('con movimiento reducido no hay vuelo', (tester) async {
    activarReducirMovimientoIos(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_vuelo, findsNothing);
    await tester.pumpAndSettle();
  });
}
