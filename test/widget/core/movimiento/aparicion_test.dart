// test/widget/core/movimiento/aparicion_test.dart — Aparicion: al mostrarse
// el hijo entra al árbol en ese mismo cuadro y el espacio se abre; al
// ocultarse se apaga y SALE del árbol (luego se cierra el espacio); con
// «reducir movimiento» todo es instantáneo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Widget _aparicion({required bool visible}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Aparicion(
      visible: visible,
      child: const SizedBox(width: 200, height: 80, child: Text('Aviso')),
    ),
    const Text('Debajo'),
  ],
);

double _alto(WidgetTester tester) =>
    tester.getSize(find.byType(Aparicion)).height;

void main() {
  testWidgets('oculta desde el inicio no ocupa lugar ni está en el árbol', (
    tester,
  ) async {
    await montarMovimiento(tester, _aparicion(visible: false));
    expect(find.text('Aviso'), findsNothing);
    expect(_alto(tester), 0);
  });

  testWidgets('al mostrarse entra al árbol en ese cuadro y se abre', (
    tester,
  ) async {
    await montarMovimiento(tester, _aparicion(visible: false));
    await montarMovimiento(tester, _aparicion(visible: true));

    expect(find.text('Aviso'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_alto(tester), inExclusiveRange(0, 80));
    await tester.pump(AppMovimiento.corta);
    expect(_alto(tester), 80);
    expect(opacidadEn(tester, find.byType(Aparicion)), 1);
  });

  testWidgets('al ocultarse se apaga, sale del árbol y cierra el espacio', (
    tester,
  ) async {
    await montarMovimiento(tester, _aparicion(visible: true));
    expect(_alto(tester), 80);

    await montarMovimiento(tester, _aparicion(visible: false));
    expect(find.text('Aviso'), findsOneWidget); // se está apagando
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Aviso'), findsNothing); // ya salió del árbol
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(AppMovimiento.corta);
    expect(_alto(tester), 0);
  });

  testWidgets('mostrarse a media salida la recupera', (tester) async {
    await montarMovimiento(tester, _aparicion(visible: true));
    await montarMovimiento(tester, _aparicion(visible: false));
    await tester.pump(const Duration(milliseconds: 30));
    await montarMovimiento(tester, _aparicion(visible: true));
    await tester.pump(AppMovimiento.corta);

    expect(find.text('Aviso'), findsOneWidget);
    expect(opacidadEn(tester, find.byType(Aparicion)), 1);
  });

  testWidgets('con movimiento reducido aparece y se va al instante', (
    tester,
  ) async {
    await montarMovimiento(tester, _aparicion(visible: false), reducido: true);
    await montarMovimiento(tester, _aparicion(visible: true), reducido: true);
    expect(find.text('Aviso'), findsOneWidget);
    // El tamaño se ajusta en el cuadro siguiente.
    await tester.pump(const Duration(milliseconds: 16));
    expect(_alto(tester), 80);

    await montarMovimiento(tester, _aparicion(visible: false), reducido: true);
    expect(find.text('Aviso'), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_alto(tester), 0);
  });
}
