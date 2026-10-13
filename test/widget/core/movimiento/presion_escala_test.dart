// test/widget/core/movimiento/presion_escala_test.dart — PresionEscala hunde
// la tarjeta mientras el dedo está abajo y la regresa al soltar, sin tocar el
// onTap del GestureDetector de adentro; un scroll o un puntero cancelado la
// regresan ya desde donde iba, la más interna gana y con «reducir
// movimiento» atenúa en lugar de escalar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// Tarjeta tocable de 120×120 con un contador de toques.
Widget _tarjeta(ValueNotifier<int> toques, {Key? key}) => GestureDetector(
  key: key,
  onTap: () => toques.value++,
  child: const SizedBox.square(
    dimension: 120,
    child: ColoredBox(color: Colors.amber),
  ),
);

Finder get _presion => find.byType(PresionEscala).first;

/// Escala de la tarjeta en cada cuadro de los siguientes 256 ms (16 × 16).
Future<List<double>> _escalasPorCuadro(WidgetTester tester) async {
  final escalas = <double>[];
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    escalas.add(escalaEn(tester, _presion));
  }
  return escalas;
}

void main() {
  late ValueNotifier<int> toques;

  setUp(() => toques = ValueNotifier<int>(0));
  tearDown(() => toques.dispose());

  testWidgets('se hunde con el dedo abajo y regresa al soltar', (tester) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));

    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      escalaEn(tester, _presion),
      closeTo(AppMovimiento.escalaPresion, 0.001),
    );

    await gesto.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(escalaEn(tester, _presion), 1);
    expect(toques.value, 1); // el onTap de adentro sigue igual
  });

  testWidgets('un toque rápido alcanza a verse y termina en reposo', (
    tester,
  ) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));

    await tester.tap(_presion);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(escalaEn(tester, _presion), lessThan(1));
    // Termina de hundirse (100 ms) y entonces regresa.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(escalaEn(tester, _presion), 1);
    expect(toques.value, 1);
  });

  testWidgets('si el dedo se arrastra (scroll) la suelta', (tester) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));

    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _presion), lessThan(1));
    await gesto.moveBy(const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(escalaEn(tester, _presion), 1);
    await gesto.up();
    await tester.pump();
  });

  testWidgets('un scroll que empieza encima la regresa ya, sin hundirla', (
    tester,
  ) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));

    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // A medio hundido el dedo ya se arrastra: es un scroll, no un toque.
    await gesto.moveBy(const Offset(0, 40));
    final escalas = await _escalasPorCuadro(tester);
    // Regresa desde donde iba: no termina de hundirse ni rebota.
    expect(escalas, everyElement(greaterThan(0.985)));
    expect(escalas, everyElement(lessThanOrEqualTo(1)));
    expect(escalas.last, 1);
    await gesto.up();
    await tester.pump();
    expect(toques.value, 0);
  });

  testWidgets('si el sistema cancela el puntero la regresa ya', (tester) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));

    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await gesto.cancel();
    final escalas = await _escalasPorCuadro(tester);
    expect(escalas, everyElement(greaterThan(0.985)));
    expect(escalas, everyElement(lessThanOrEqualTo(1)));
    expect(escalas.last, 1);
    expect(toques.value, 0);
  });

  testWidgets('la más interna gana: el «+» no hunde la tarjeta completa', (
    tester,
  ) async {
    await montarMovimiento(
      tester,
      PresionEscala(
        child: SizedBox.square(
          dimension: 240,
          child: Center(
            child: PresionEscala(
              escala: AppMovimiento.escalaPresionChica,
              child: _tarjeta(toques),
            ),
          ),
        ),
      ),
    );
    final externa = find.byType(PresionEscala).first;
    final interna = find.byType(PresionEscala).last;

    final gesto = await tester.startGesture(tester.getCenter(interna));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      escalaEn(tester, interna),
      closeTo(AppMovimiento.escalaPresionChica, 0.001),
    );
    expect(escalaEn(tester, externa), 1);
    await gesto.up();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('con movimiento reducido atenúa en lugar de escalar', (
    tester,
  ) async {
    await montarMovimiento(
      tester,
      PresionEscala(child: _tarjeta(toques)),
      reducido: true,
    );

    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _presion), 1);
    expect(opacidadEn(tester, _presion), closeTo(0.82, 0.001));
    await gesto.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacidadEn(tester, _presion), 1);
    expect(toques.value, 1);
  });

  testWidgets('cambiar la escala la actualiza', (tester) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));
    await montarMovimiento(
      tester,
      PresionEscala(
        escala: AppMovimiento.escalaPresionChica,
        child: _tarjeta(toques),
      ),
    );

    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      escalaEn(tester, _presion),
      closeTo(AppMovimiento.escalaPresionChica, 0.001),
    );
    await gesto.up();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('desmontarse con el dedo abajo libera el puntero', (
    tester,
  ) async {
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));
    final gesto = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump(const Duration(milliseconds: 50));

    await montarMovimiento(tester, const SizedBox());
    await gesto.up();

    // Una PresionEscala nueva responde a punteros nuevos con normalidad.
    await montarMovimiento(tester, PresionEscala(child: _tarjeta(toques)));
    final otro = await tester.startGesture(tester.getCenter(_presion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _presion), lessThan(1));
    await otro.up();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
