// test/widget/core/movimiento/destello_corazon_test.dart — DestelloCorazon:
// destella (pop + aro y puntos pintados) solo cuando el usuario marca el
// favorito con un toque reciente; la carga de favoritos, desmarcar, un toque
// viejo que no cambió nada, un arrastre, un puntero cancelado y «reducir
// movimiento» no destellan, y no agrega íconos de corazón.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// Un corazón que se marca con un toque y un botón aparte que simula la
/// carga de favoritos desde el backend. Con `invitado` el toque no cambia
/// nada (sin sesión).
class _Corazon extends StatefulWidget {
  const _Corazon({this.invitado = false});

  final bool invitado;

  @override
  State<_Corazon> createState() => _CorazonState();
}

class _CorazonState extends State<_Corazon> {
  bool _favorito = false;

  void _alTocar() {
    if (!widget.invitado) setState(() => _favorito = !_favorito);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DestelloCorazon(
        activo: _favorito,
        child: GestureDetector(
          onTap: _alTocar,
          child: Icon(
            _favorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 32,
          ),
        ),
      ),
      const SizedBox(height: 40),
      TextButton(
        onPressed: () => setState(() => _favorito = true),
        child: const Text('Cargar favoritos'),
      ),
    ],
  );
}

Finder get _destello => find.byType(DestelloCorazon);

RenderObject _lienzo(WidgetTester tester) => tester.renderObject(
  find.descendant(of: _destello, matching: find.byType(CustomPaint)),
);

void main() {
  testWidgets('al marcar con un toque destella una vez', (tester) async {
    await montarMovimiento(tester, const _Corazon());
    expect(_lienzo(tester), paintsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _destello), greaterThan(1));
    expect(_lienzo(tester), paints..circle());

    await tester.pump(AppMovimiento.enfasis);
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
    // No agrega íconos: sigue habiendo un solo corazón.
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('si se marca sin toque (carga de favoritos) no destella', (
    tester,
  ) async {
    await montarMovimiento(tester, const _Corazon());

    await tester.tap(find.text('Cargar favoritos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
  });

  testWidgets('al desmarcar no destella', (tester) async {
    await montarMovimiento(tester, const _Corazon());
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
  });

  testWidgets('con movimiento reducido no destella', (tester) async {
    await montarMovimiento(tester, const _Corazon(), reducido: true);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
  });

  testWidgets('un toque que no cambió nada caduca: 5 s después no destella', (
    tester,
  ) async {
    await montarMovimiento(tester, const _Corazon(invitado: true));
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text('Cargar favoritos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
  });

  testWidgets('tras un rato sin cuadros, un toque sí destella', (tester) async {
    await montarMovimiento(tester, const _Corazon());
    await tester.pumpAndSettle();
    final ultimoCuadro = tester.binding.currentSystemFrameTimeStamp;
    await tester.pump(const Duration(seconds: 10));
    // Sin nada que pintar no hubo cuadros: la hora del último es vieja.
    expect(tester.binding.currentSystemFrameTimeStamp, ultimoCuadro);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _destello), greaterThan(1));
    expect(_lienzo(tester), paints..circle());
    await tester.pump(AppMovimiento.enfasis);
  });

  testWidgets('un arrastre que empieza sobre el corazón no lo arma', (
    tester,
  ) async {
    await montarMovimiento(tester, const _Corazon());
    final gesto = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.favorite_border_rounded)),
    );
    await tester.pump();
    await gesto.moveBy(const Offset(0, 40));
    await gesto.up();
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.text('Cargar favoritos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
  });

  testWidgets('si el sistema cancela el puntero no queda armado', (
    tester,
  ) async {
    await montarMovimiento(tester, const _Corazon());
    final gesto = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.favorite_border_rounded)),
    );
    await tester.pump();
    await gesto.cancel();
    await tester.pump();

    await tester.tap(find.text('Cargar favoritos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(escalaEn(tester, _destello), 1);
    expect(_lienzo(tester), paintsNothing);
  });
}
