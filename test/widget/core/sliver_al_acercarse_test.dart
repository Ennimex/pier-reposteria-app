// test/widget/core/sliver_al_acercarse_test.dart — SliverAlAcercarse (#341):
// lo que empieza cerca de la pantalla se arma de inmediato; lo que empieza
// lejos solo aparta su alto y se arma cuando el scroll lo acerca; ya armado
// se queda con su estado aunque el scroll lo aleje.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/sliver_al_acercarse.dart';

/// Caja de 200 de alto con un contador propio (para ver que conserva su
/// estado).
class _Caja extends StatefulWidget {
  const _Caja(this.nombre);

  final String nombre;

  @override
  State<_Caja> createState() => _CajaState();
}

class _CajaState extends State<_Caja> {
  int _toques = 0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: TextButton(
      onPressed: () => setState(() => _toques++),
      child: Text('${widget.nombre} $_toques'),
    ),
  );
}

/// Una lista de 600 de alto (la franja que prepara por adelantado mide 250)
/// con [arriba] de alto antes de los slivers que se prueban.
Future<void> _montar(
  WidgetTester tester, {
  required double arriba,
  required List<Widget> slivers,
}) async {
  tester.view
    ..physicalSize = const Size(400, 600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: arriba)),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ],
      ),
    ),
  );
}

Finder _montada(String texto) => find.text(texto, skipOffstage: false);

void main() {
  testWidgets('lo que empieza en la pantalla o en la franja de adelanto se '
      'arma de inmediato', (tester) async {
    await _montar(
      tester,
      arriba: 500,
      slivers: const [
        SliverAlAcercarse(child: _Caja('Visible')),
        // Empieza en 700: fuera de la pantalla (600), dentro de la franja.
        SliverAlAcercarse(child: _Caja('En la franja')),
      ],
    );
    expect(find.text('Visible 0'), findsOneWidget);
    expect(_montada('En la franja 0'), findsOneWidget);
  });

  testWidgets('lo que empieza lejos aparta su alto y se arma cuando el '
      'scroll lo acerca', (tester) async {
    await _montar(
      tester,
      arriba: 1000,
      slivers: const [
        SliverAlAcercarse(altoApartado: 320, child: _Caja('Lejana')),
        SliverAlAcercarse(altoApartado: 320, child: _Caja('Más lejana')),
      ],
    );
    expect(_montada('Lejana 0'), findsNothing);
    expect(_montada('Más lejana 0'), findsNothing);
    // Cada una aparta su alto: lo que sigue no queda pegado.
    final control = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(control.position.maxScrollExtent, 1000 + 320 + 320 + 2000 - 600);

    // 1000 queda a 250 del final de la pantalla con el scroll en 150.
    control.position.jumpTo(149);
    await tester.pump();
    expect(_montada('Lejana 0'), findsNothing);
    control.position.jumpTo(151);
    await tester.pump();
    expect(_montada('Lejana 0'), findsOneWidget);
    // La que sigue empieza después de la primera, ya con su alto real.
    expect(_montada('Más lejana 0'), findsNothing);

    control.position.jumpTo(500);
    await tester.pump();
    expect(_montada('Más lejana 0'), findsOneWidget);
  }, tags: 'regresion');

  testWidgets('ya armado se queda, con su estado, aunque el scroll lo aleje', (
    tester,
  ) async {
    await _montar(
      tester,
      arriba: 1000,
      slivers: const [SliverAlAcercarse(child: _Caja('Lejana'))],
    );
    final control = tester.state<ScrollableState>(find.byType(Scrollable));
    control.position.jumpTo(900);
    await tester.pump();
    await tester.tap(find.text('Lejana 0'));
    await tester.pump();
    expect(find.text('Lejana 1'), findsOneWidget);

    control.position.jumpTo(0);
    await tester.pump();
    expect(find.text('Lejana 1'), findsNothing); // fuera de la pantalla
    expect(_montada('Lejana 1'), findsOneWidget);

    control.position.jumpTo(3000);
    await tester.pump();
    expect(_montada('Lejana 1'), findsOneWidget);
  });
}
