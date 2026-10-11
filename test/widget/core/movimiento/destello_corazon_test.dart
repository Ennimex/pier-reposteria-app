// test/widget/core/movimiento/destello_corazon_test.dart — DestelloCorazon:
// destella (pop + aro y puntos pintados) solo cuando el usuario marca el
// favorito con un toque; la carga de favoritos, desmarcar y «reducir
// movimiento» no destellan, y no agrega íconos de corazón.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// Un corazón que se marca con un toque y un botón aparte que simula la
/// carga de favoritos desde el backend.
class _Corazon extends StatefulWidget {
  const _Corazon();

  @override
  State<_Corazon> createState() => _CorazonState();
}

class _CorazonState extends State<_Corazon> {
  bool _favorito = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DestelloCorazon(
        activo: _favorito,
        child: GestureDetector(
          onTap: () => setState(() => _favorito = !_favorito),
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
}
