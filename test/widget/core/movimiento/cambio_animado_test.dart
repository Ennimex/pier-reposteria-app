// test/widget/core/movimiento/cambio_animado_test.dart — CambioAnimado
// cambia un contenido en sitio: durante el cambio conviven el anterior y el
// nuevo, al final solo queda el nuevo (o al instante con soloEntrada), cada
// variante llega a reposo, A → B → A no duplica y con «reducir movimiento»
// cualquier variante es un fundido.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Widget _cambio(
  String texto, {
  TipoCambio tipo = TipoCambio.fundido,
  bool soloEntrada = false,
  int direccion = 1,
}) => CambioAnimado(
  tipo: tipo,
  soloEntrada: soloEntrada,
  direccion: direccion,
  child: Text(texto, key: ValueKey(texto)),
);

void main() {
  testWidgets('durante el cambio conviven y al final solo queda el nuevo', (
    tester,
  ) async {
    await montarMovimiento(tester, _cambio('A'));
    expect(find.text('A'), findsOneWidget);

    await montarMovimiento(tester, _cambio('B'));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.pump(AppMovimiento.corta);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('soloEntrada quita al anterior en el mismo cuadro', (
    tester,
  ) async {
    await montarMovimiento(tester, _cambio('A', soloEntrada: true));
    await montarMovimiento(tester, _cambio('B', soloEntrada: true));

    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    await tester.pump(AppMovimiento.corta);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('cada variante deja al nuevo en su lugar', (tester) async {
    for (final tipo in TipoCambio.values) {
      await montarMovimiento(tester, _cambio('A', tipo: tipo));
      await montarMovimiento(tester, _cambio('B', tipo: tipo));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(AppMovimiento.corta);

      expect(find.text('A'), findsNothing, reason: '$tipo');
      expect(find.text('B'), findsOneWidget, reason: '$tipo');
      final textoB = tester.getCenter(find.text('B'));
      final caja = tester.getCenter(find.byType(CambioAnimado));
      expect(textoB.dy, closeTo(caja.dy, 0.01), reason: '$tipo');

      // Deja el árbol limpio para la siguiente variante.
      await montarMovimiento(tester, const SizedBox());
    }
  });

  testWidgets('ejeX trae al nuevo desde el lado de la dirección', (
    tester,
  ) async {
    await montarMovimiento(tester, _cambio('A', tipo: TipoCambio.ejeX));
    final enReposo = tester.getCenter(find.text('A')).dx;
    await montarMovimiento(tester, _cambio('B', tipo: TipoCambio.ejeX));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getCenter(find.text('B')).dx, greaterThan(enReposo));

    await montarMovimiento(
      tester,
      _cambio('C', tipo: TipoCambio.ejeX, direccion: -1),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getCenter(find.text('C')).dx, lessThan(enReposo));
    await tester.pump(AppMovimiento.corta);
  });

  testWidgets('subir mueve al nuevo en vertical y escalar lo hace crecer', (
    tester,
  ) async {
    await montarMovimiento(tester, _cambio('1', tipo: TipoCambio.subir));
    final enReposo = tester.getCenter(find.text('1')).dy;
    await montarMovimiento(tester, _cambio('2', tipo: TipoCambio.subir));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getCenter(find.text('2')).dy, greaterThan(enReposo));
    await tester.pump(AppMovimiento.corta);

    await montarMovimiento(tester, _cambio('x', tipo: TipoCambio.escalar));
    await montarMovimiento(tester, _cambio('y', tipo: TipoCambio.escalar));
    final escala = tester
        .widget<ScaleTransition>(
          find
              .ancestor(
                of: find.text('y'),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;
    expect(escala, lessThan(1));
    await tester.pump(AppMovimiento.corta);
  });

  testWidgets('A → B → A no duplica hijos', (tester) async {
    await montarMovimiento(tester, _cambio('A'));
    await montarMovimiento(tester, _cambio('B'));
    await tester.pump(const Duration(milliseconds: 50));
    await montarMovimiento(tester, _cambio('A'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(AppMovimiento.corta);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('con movimiento reducido toda variante es un fundido', (
    tester,
  ) async {
    await montarMovimiento(
      tester,
      _cambio('A', tipo: TipoCambio.ejeX),
      reducido: true,
    );
    final enReposo = tester.getCenter(find.text('A')).dx;
    await montarMovimiento(
      tester,
      _cambio('B', tipo: TipoCambio.ejeX),
      reducido: true,
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getCenter(find.text('B')).dx, closeTo(enReposo, 0.01));
    await tester.pump(AppMovimiento.corta);
    expect(find.text('A'), findsNothing);
  });
}
