// test/widget/core/movimiento/monto_animado_test.dart — MontoAnimado no
// anima al montarse, cuenta hacia el nuevo valor y termina EXACTAMENTE en
// formato(valor); salta al valor con «reducir movimiento» u oculto, y los
// lectores de pantalla leen siempre el valor final.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

String _pesos(double v) => '\$${v.toStringAsFixed(2)} MXN';

Widget _monto(double valor) => MontoAnimado(valor: valor, formato: _pesos);

void main() {
  testWidgets('al montarse pinta el monto final sin animar', (tester) async {
    await montarMovimiento(tester, _monto(270));
    expect(find.text(r'$270.00 MXN'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(r'$270.00 MXN'), findsOneWidget);
  });

  testWidgets('al cambiar cuenta y termina exactamente en el nuevo formato', (
    tester,
  ) async {
    await montarMovimiento(tester, _monto(100));
    await montarMovimiento(tester, _monto(450));
    await tester.pump(const Duration(milliseconds: 150));

    final intermedio = tester.widget<Text>(find.byType(Text)).data!;
    expect(intermedio, isNot(r'$100.00 MXN'));
    expect(intermedio, isNot(r'$450.00 MXN'));

    await tester.pump(AppMovimiento.conteo);
    expect(find.text(r'$450.00 MXN'), findsOneWidget);
  });

  testWidgets('si cambia a medio conteo sigue desde lo que se ve', (
    tester,
  ) async {
    await montarMovimiento(tester, _monto(100));
    await montarMovimiento(tester, _monto(200));
    await tester.pump(const Duration(milliseconds: 150));
    await montarMovimiento(tester, _monto(0.1 + 0.2));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(AppMovimiento.conteo);

    // Sin errores de redondeo: el texto final es formato(valor).
    expect(find.text(_pesos(0.1 + 0.2)), findsOneWidget);
  });

  testWidgets('con movimiento reducido salta al valor', (tester) async {
    await montarMovimiento(tester, _monto(100), reducido: true);
    await montarMovimiento(tester, _monto(300), reducido: true);
    expect(find.text(r'$300.00 MXN'), findsOneWidget);
  });

  testWidgets('oculto (ticker pausado) salta al valor', (tester) async {
    Widget oculto(double valor) =>
        TickerMode(enabled: false, child: _monto(valor));
    await montarMovimiento(tester, oculto(100));
    await montarMovimiento(tester, oculto(300));
    expect(find.text(r'$300.00 MXN'), findsOneWidget);
  });

  testWidgets('los lectores de pantalla leen el valor final', (tester) async {
    final semantica = tester.ensureSemantics();
    await montarMovimiento(tester, _monto(100));
    await montarMovimiento(tester, _monto(450));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel(r'$450.00 MXN'), findsOneWidget);
    await tester.pump(AppMovimiento.conteo);
    semantica.dispose();
  });
}
