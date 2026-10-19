// test/widget/core/animated_indexed_stack_test.dart — AnimatedIndexedStack
// v2 (las pestañas de MainScreen y del repartidor): el primer build no
// anima; al cambiar animan las dos capas (la que sale y la que entra) y en
// 300 ms solo queda la nueva; las ocultas quedan fuera de escena, sin tickers
// ni Hero y con su estado intacto; el fling cambia de pestaña; con «reducir
// movimiento» el cambio es instantáneo; una entrada con trasPestana no
// avanza mientras la pestaña sigue transparente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/animated_indexed_stack.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../helpers/movimiento.dart';

/// Pestaña con un contador propio (para ver que conserva su estado).
class _Pestana extends StatefulWidget {
  const _Pestana(this.nombre);

  final String nombre;

  @override
  State<_Pestana> createState() => _PestanaState();
}

class _PestanaState extends State<_Pestana> {
  int _toques = 0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Center(
      child: TextButton(
        onPressed: () => setState(() => _toques++),
        child: Text('${widget.nombre} $_toques'),
      ),
    ),
  );
}

/// Anfitrión con su índice, como MainScreen o el panel del repartidor.
class _Pestanas extends StatefulWidget {
  const _Pestanas({this.conDeslizar = true});

  final bool conDeslizar;

  @override
  State<_Pestanas> createState() => _PestanasState();
}

class _PestanasState extends State<_Pestanas> {
  int indice = 0;

  void ir(int nuevo) => setState(() => indice = nuevo);

  @override
  Widget build(BuildContext context) => AnimatedIndexedStack(
    index: indice,
    onSwipeToIndex: widget.conDeslizar ? ir : null,
    children: const [_Pestana('Uno'), _Pestana('Dos'), _Pestana('Tres')],
  );
}

Future<_PestanasState> _montar(
  WidgetTester tester, {
  bool conDeslizar = true,
  bool reducido = false,
  TextDirection direccion = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direccion,
        child: reducido
            ? ConMovimientoReducido(child: _Pestanas(conDeslizar: conDeslizar))
            : _Pestanas(conDeslizar: conDeslizar),
      ),
    ),
  );
  return tester.state<_PestanasState>(find.byType(_Pestanas));
}

/// La capa (FadeTransition) de la pestaña cuyo texto empieza con [nombre].
Finder _capa(String nombre) => find
    .ancestor(
      of: find.textContaining(nombre, skipOffstage: false),
      matching: find.byType(FadeTransition, skipOffstage: false),
    )
    .first;

double _opacidad(WidgetTester tester, String nombre) =>
    tester.widget<FadeTransition>(_capa(nombre)).opacity.value;

double _dx(WidgetTester tester, String nombre) =>
    tester.getCenter(find.textContaining(nombre)).dx -
    tester.getCenter(find.byType(AnimatedIndexedStack)).dx;

void main() {
  testWidgets('el primer build no anima y solo se ve la pestaña actual', (
    tester,
  ) async {
    await _montar(tester);
    expect(find.text('Uno 0'), findsOneWidget);
    expect(_opacidad(tester, 'Uno'), 1);
    expect(find.text('Dos 0'), findsNothing); // fuera de escena
    expect(find.text('Dos 0', skipOffstage: false), findsOneWidget);
  });

  testWidgets('al cambiar animan las dos capas y en 300 ms queda la nueva', (
    tester,
  ) async {
    final pestanas = await _montar(tester);
    pestanas.ir(1);
    await tester.pump();

    // Al principio las dos están en escena: la que sale aún se ve.
    expect(find.text('Uno 0'), findsOneWidget);
    expect(find.text('Dos 0'), findsOneWidget);
    expect(_opacidad(tester, 'Uno'), 1);
    expect(_opacidad(tester, 'Dos'), 0);

    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacidad(tester, 'Uno'), inExclusiveRange(0, 1));
    expect(_dx(tester, 'Uno'), lessThan(0)); // se va hacia la izquierda

    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacidad(tester, 'Uno'), 0);
    expect(_opacidad(tester, 'Dos'), inExclusiveRange(0, 1));
    expect(_dx(tester, 'Dos'), greaterThan(0)); // llega desde la derecha

    await tester.pump(const Duration(milliseconds: 141));
    expect(find.text('Uno 0'), findsNothing);
    expect(_opacidad(tester, 'Dos'), 1);
    expect(_dx(tester, 'Dos'), 0);
  });

  testWidgets('las ocultas no corren tickers, no vuelan Hero ni reciben '
      'toques', (tester) async {
    final pestanas = await _montar(tester);
    final oculta = tester.element(find.text('Tres 0', skipOffstage: false));
    expect(TickerMode.getValuesNotifier(oculta).value.enabled, isFalse);
    expect(
      tester
          .widget<HeroMode>(
            find
                .ancestor(
                  of: find.text('Tres 0', skipOffstage: false),
                  matching: find.byType(HeroMode, skipOffstage: false),
                )
                .first,
          )
          .enabled,
      isFalse,
    );

    pestanas.ir(2);
    await tester.pump();
    final visible = tester.element(find.text('Tres 0'));
    expect(TickerMode.getValuesNotifier(visible).value.enabled, isTrue);
    await tester.pump(AppMovimiento.media);
    await tester.tap(find.text('Tres 0'));
    await tester.pump();
    expect(find.text('Tres 1'), findsOneWidget);
  });

  testWidgets('cada pestaña conserva su estado', (tester) async {
    final pestanas = await _montar(tester);
    await tester.tap(find.text('Uno 0'));
    await tester.pump();
    expect(find.text('Uno 1'), findsOneWidget);

    pestanas.ir(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    pestanas.ir(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Uno 1'), findsOneWidget);
  });

  testWidgets('deslizar a la izquierda va a la siguiente y a la derecha a '
      'la anterior', (tester) async {
    final pestanas = await _montar(tester);

    await tester.fling(find.text('Uno 0'), const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(pestanas.indice, 1);

    await tester.fling(find.text('Dos 0'), const Offset(300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(pestanas.indice, 0);

    // A la derecha desde la primera no hay a dónde ir.
    await tester.fling(find.text('Uno 0'), const Offset(300, 0), 1000);
    await tester.pump();
    expect(pestanas.indice, 0);

    // Un roce lento (por debajo del umbral de 300 px/s) no cambia de pestaña.
    await tester.fling(find.text('Uno 0'), const Offset(-40, 0), 100);
    await tester.pump();
    expect(pestanas.indice, 0);
  });

  testWidgets('sin onSwipeToIndex no escucha el deslizamiento', (
    tester,
  ) async {
    final pestanas = await _montar(tester, conDeslizar: false);
    await tester.fling(find.text('Uno 0'), const Offset(-300, 0), 1000);
    await tester.pump();
    expect(pestanas.indice, 0);
  });

  testWidgets('cambiar a media transición retoma la opacidad que había', (
    tester,
  ) async {
    final pestanas = await _montar(tester);
    pestanas.ir(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final opacidadDos = _opacidad(tester, 'Dos');
    expect(opacidadDos, inExclusiveRange(0, 1));

    pestanas.ir(2);
    await tester.pump();
    // «Dos» ahora sale desde la opacidad que ya tenía (sin parpadeo) y
    // «Uno» ya no está en escena.
    expect(_opacidad(tester, 'Dos'), closeTo(opacidadDos, 0.02));
    expect(find.text('Uno 0'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Dos 0'), findsNothing);
    expect(find.text('Tres 0'), findsOneWidget);
  });

  testWidgets('de derecha a izquierda la nueva llega desde la izquierda', (
    tester,
  ) async {
    final pestanas = await _montar(tester, direccion: TextDirection.rtl);
    pestanas.ir(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(_dx(tester, 'Dos'), lessThan(0));
    await tester.pump(AppMovimiento.media);
  });

  testWidgets('con movimiento reducido el cambio es instantáneo', (
    tester,
  ) async {
    final pestanas = await _montar(tester, reducido: true);
    pestanas.ir(2);
    await tester.pump();
    expect(find.text('Uno 0'), findsNothing);
    expect(find.text('Tres 0'), findsOneWidget);
    expect(_opacidad(tester, 'Tres'), 1);
  });

  testWidgets('con trasPestana el contenido espera a que la pestaña se vea', (
    tester,
  ) async {
    final indice = ValueNotifier<int>(0);
    addTearDown(indice.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: indice,
          builder: (_, i, _) => AnimatedIndexedStack(
            index: i,
            children: const [
              Center(child: Text('Uno')),
              Center(
                child: EntradaSuave(
                  retraso: AppMovimiento.trasPestana,
                  child: Text('Dos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Oculta no gasta su entrada.
    await tester.pump(const Duration(seconds: 1));

    indice.value = 1;
    await tester.pump();
    final entrada = find.byType(EntradaSuave);
    // La capa de la pestaña: el FadeTransition más cercano por encima.
    double capa() => tester
        .widget<FadeTransition>(
          find
              .ancestor(of: entrada, matching: find.byType(FadeTransition))
              .first,
        )
        .opacity
        .value;
    // Mientras la pestaña sigue transparente, su contenido no avanza.
    for (var i = 0; i < 16; i++) {
      if (capa() == 0) expect(opacidadEn(tester, entrada), 0);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(opacidadEn(tester, entrada), greaterThan(0));
    await tester.pump(AppMovimiento.entrada);
  });
}
