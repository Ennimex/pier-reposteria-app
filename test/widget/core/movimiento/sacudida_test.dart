// test/widget/core/movimiento/sacudida_test.dart — Sacudida oscila al
// cambiar el disparo y vuelve a su lugar; no se mueve al montarse ni con un
// disparo nulo, ni con «reducir movimiento».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Widget _sacudida(Object? disparo) =>
    Sacudida(disparo: disparo, child: const Text('Código'));

double _x(WidgetTester tester) => tester.getCenter(find.text('Código')).dx;

void main() {
  testWidgets('al cambiar el disparo sacude y vuelve a su lugar', (
    tester,
  ) async {
    await montarMovimiento(tester, _sacudida(0));
    final enReposo = _x(tester);

    await montarMovimiento(tester, _sacudida(1));
    // A 1/12 de la duración el seno está en su máximo.
    await tester.pump(const Duration(milliseconds: 37));
    expect((_x(tester) - enReposo).abs(), greaterThan(4));

    await tester.pump(AppMovimiento.enfasis);
    expect(_x(tester), enReposo);
  });

  testWidgets('no sacude al montarse ni con un disparo nulo', (tester) async {
    await montarMovimiento(tester, _sacudida(null));
    final enReposo = _x(tester);
    await montarMovimiento(tester, _sacudida(null));
    await tester.pump(const Duration(milliseconds: 37));
    expect(_x(tester), enReposo);

    // De un error a «sin error» tampoco sacude.
    await montarMovimiento(tester, _sacudida('Código incorrecto'));
    await tester.pump(AppMovimiento.enfasis);
    await montarMovimiento(tester, _sacudida(null));
    await tester.pump(const Duration(milliseconds: 37));
    expect(_x(tester), enReposo);
  });

  testWidgets('con movimiento reducido no se mueve', (tester) async {
    await montarMovimiento(tester, _sacudida(0), reducido: true);
    final enReposo = _x(tester);
    await montarMovimiento(tester, _sacudida(1), reducido: true);
    await tester.pump(const Duration(milliseconds: 37));
    expect(_x(tester), enReposo);
  });
}
