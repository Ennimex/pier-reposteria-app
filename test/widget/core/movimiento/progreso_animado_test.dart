// test/widget/core/movimiento/progreso_animado_test.dart — ProgresoAnimado
// llena de 0 a su valor en el primer cuadro visible (también si estaba
// oculto: espera a mostrarse), avanza desde donde iba si el valor cambia y
// salta con «reducir movimiento»; BarraRelleno se llena hasta su fracción.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Widget _progreso(
  double valor, {
  bool desdeCero = true,
  Duration retraso = Duration.zero,
}) => ProgresoAnimado(
  valor: valor,
  desdeCero: desdeCero,
  retraso: retraso,
  builder: (context, progreso, _) => Text(progreso.toStringAsFixed(2)),
);

String _texto(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data!;

void main() {
  group('ProgresoAnimado', () {
    testWidgets('llena de 0 al valor en el primer cuadro visible', (
      tester,
    ) async {
      await montarMovimiento(tester, _progreso(3));
      expect(_texto(tester), '0.00');

      await tester.pump(); // primer tick (arrancó en un post-frame)
      await tester.pump(const Duration(milliseconds: 300));
      final medio = double.parse(_texto(tester));
      expect(medio, inExclusiveRange(0, 3));

      await tester.pump(AppMovimiento.relleno);
      expect(_texto(tester), '3.00');
    });

    testWidgets('si el valor cambia avanza desde donde iba', (tester) async {
      await montarMovimiento(tester, _progreso(2));
      await tester.pump();
      await tester.pump(AppMovimiento.relleno);
      expect(_texto(tester), '2.00');

      await montarMovimiento(tester, _progreso(4));
      expect(_texto(tester), '2.00');
      await tester.pump(const Duration(milliseconds: 300));
      expect(double.parse(_texto(tester)), inExclusiveRange(2, 4));
      await tester.pump(AppMovimiento.relleno);
      expect(_texto(tester), '4.00');
    });

    testWidgets('respeta el retraso del primer llenado', (tester) async {
      await montarMovimiento(
        tester,
        _progreso(1, retraso: const Duration(milliseconds: 250)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_texto(tester), '0.00');
      await tester.pump(AppMovimiento.relleno);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_texto(tester), '1.00');
    });

    testWidgets('desdeCero en falso muestra el valor de inmediato', (
      tester,
    ) async {
      await montarMovimiento(tester, _progreso(3, desdeCero: false));
      expect(_texto(tester), '3.00');
    });

    testWidgets('con movimiento reducido salta al valor', (tester) async {
      await montarMovimiento(tester, _progreso(3), reducido: true);
      expect(_texto(tester), '3.00');
      await montarMovimiento(tester, _progreso(5), reducido: true);
      expect(_texto(tester), '5.00');
    });

    testWidgets('en una pestaña oculta espera a mostrarse', (tester) async {
      var visible = false;
      late StateSetter cambiar;
      await montarMovimiento(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            cambiar = setState;
            return TickerMode(enabled: visible, child: _progreso(3));
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_texto(tester), '0.00');

      cambiar(() => visible = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMovimiento.relleno);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_texto(tester), '3.00');
    });

    testWidgets('oculto, un cambio salta al nuevo valor', (tester) async {
      Widget oculto(double valor) => TickerMode(
        enabled: false,
        child: _progreso(valor, desdeCero: false),
      );
      await montarMovimiento(tester, oculto(1));
      await montarMovimiento(tester, oculto(2));
      expect(_texto(tester), '2.00');
    });
  });

  group('BarraRelleno', () {
    Finder relleno() => find.descendant(
      of: find.byType(BarraRelleno),
      matching: find.byType(DecoratedBox),
    );

    testWidgets('se llena hasta su fracción', (tester) async {
      await montarMovimiento(
        tester,
        const SizedBox(
          width: 200,
          child: BarraRelleno(fraccion: 0.5, color: Colors.green),
        ),
      );
      expect(tester.getSize(relleno()).width, 0);
      await tester.pump();
      await tester.pump(AppMovimiento.relleno);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(relleno()).width, 100);
      expect(tester.getSize(find.byType(BarraRelleno)).height, 6);
    });

    testWidgets('en vertical se llena de arriba abajo y se acota a 1', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        const SizedBox(
          height: 120,
          child: BarraRelleno(
            fraccion: 2,
            color: Colors.green,
            fondo: Colors.black12,
            eje: Axis.vertical,
            grosor: 4,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(AppMovimiento.relleno);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(relleno()), const Size(4, 120));
    });
  });
}
