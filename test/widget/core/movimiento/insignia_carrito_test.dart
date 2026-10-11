// test/widget/core/movimiento/insignia_carrito_test.dart — InsigniaCarrito:
// en 0 no existe; aparece creciendo, rebota solo cuando la cantidad sube,
// se encoge y sale del árbol al volver a 0 (sin mostrar «0»), no anima al
// montarse y con «reducir movimiento» cambia al instante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Widget _insignia(int cantidad) => InsigniaCarrito(cantidad: cantidad);

/// Escalas de la insignia: [presencia, rebote].
List<double> _escalas(WidgetTester tester) => tester
    .widgetList<ScaleTransition>(
      find.descendant(
        of: find.byType(InsigniaCarrito),
        matching: find.byType(ScaleTransition),
      ),
    )
    .map((t) => t.scale.value)
    .toList();

void main() {
  testWidgets('en 0 no hay insignia', (tester) async {
    await montarMovimiento(tester, _insignia(0));
    expect(find.text('0'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(InsigniaCarrito),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('al montarse con cantidad no anima', (tester) async {
    await montarMovimiento(tester, _insignia(3));
    expect(find.text('3'), findsOneWidget);
    expect(_escalas(tester), [1, 1]);
  });

  testWidgets('de 0 a 1 aparece creciendo', (tester) async {
    await montarMovimiento(tester, _insignia(0));
    await montarMovimiento(tester, _insignia(1));

    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    expect(_escalas(tester).first, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_escalas(tester), [1, 1]);
  });

  testWidgets('rebota al subir y no al bajar', (tester) async {
    await montarMovimiento(tester, _insignia(1));
    await montarMovimiento(tester, _insignia(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalas(tester).last, greaterThan(1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(AppMovimiento.enfasis);
    expect(_escalas(tester).last, 1);

    await montarMovimiento(tester, _insignia(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalas(tester).last, 1);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('al volver a 0 se encoge con su número y sale del árbol', (
    tester,
  ) async {
    await montarMovimiento(tester, _insignia(2));
    await montarMovimiento(tester, _insignia(0));

    expect(find.text('2'), findsOneWidget); // no muestra «0» al irse
    expect(find.text('0'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_escalas(tester).first, lessThan(1));
    await tester.pump(AppMovimiento.rapida);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('con movimiento reducido aparece y se va al instante', (
    tester,
  ) async {
    await montarMovimiento(tester, _insignia(0), reducido: true);
    await montarMovimiento(tester, _insignia(4), reducido: true);
    expect(_escalas(tester), [1, 1]);

    await montarMovimiento(tester, _insignia(5), reducido: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalas(tester), [1, 1]); // sin rebote

    await montarMovimiento(tester, _insignia(0), reducido: true);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('usa el color que se le da', (tester) async {
    await montarMovimiento(
      tester,
      const InsigniaCarrito(cantidad: 1, color: Colors.teal),
    );
    final caja = tester.widget<Container>(
      find.descendant(
        of: find.byType(InsigniaCarrito),
        matching: find.byType(Container),
      ),
    );
    expect((caja.decoration! as BoxDecoration).color, Colors.teal);
  });
}
