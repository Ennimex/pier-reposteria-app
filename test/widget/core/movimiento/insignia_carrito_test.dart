// test/widget/core/movimiento/insignia_carrito_test.dart — InsigniaCarrito:
// en 0 no existe; aparece creciendo, rebota solo cuando la cantidad sube,
// se encoge y sale del árbol al volver a 0 (sin mostrar «0»), no anima al
// montarse y con «reducir movimiento» cambia al instante. Con una miniatura
// en camino a su carrito no se adelanta: la reacción es el trago al llegar.
// Igual con un alta que espera al backend (lanzarAlConfirmar): no rebota con
// el +1 optimista antes de que salga la miniatura, y si el backend rechaza
// no reacciona.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Widget _insignia(int cantidad) => InsigniaCarrito(cantidad: cantidad);

/// El carrito de la barra (DestinoVuelo con su insignia) y tres botones:
/// «Agregar» sube la cantidad y lanza la miniatura en el mismo toque (como
/// el «+» del catálogo), «Sincronizar» la sube sin vuelo (una carga del
/// backend) y «Vaciar» la regresa a 0 (el backend revierte). Con [backend],
/// un cuarto botón «Añadir» hace el alta como el detalle: el +1 optimista
/// antes de esperar al backend (como CartProvider.addItem, que lo revierte
/// si este rechaza) y la espera con lanzarAlConfirmar.
class _Tienda extends StatefulWidget {
  const _Tienda({required this.inicial, this.backend});

  final int inicial;
  final Future<String?> Function()? backend;

  @override
  State<_Tienda> createState() => _TiendaState();
}

class _TiendaState extends State<_Tienda> {
  late int _cantidad = widget.inicial;

  Future<String?> _altaEsperada(Future<String?> Function() backend) async {
    setState(() => _cantidad++);
    final motivo = await backend();
    if (motivo != null && mounted) setState(() => _cantidad--);
    return motivo;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (contexto) => TextButton(
              onPressed: () {
                setState(() => _cantidad++);
                VueloAlCarrito.lanzar(contexto, imagenUrl: '');
              },
              child: const Text('Agregar'),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _cantidad++),
            child: const Text('Sincronizar'),
          ),
          TextButton(
            onPressed: () => setState(() => _cantidad = 0),
            child: const Text('Vaciar'),
          ),
          if (widget.backend case final backend?)
            Builder(
              builder: (contexto) => TextButton(
                onPressed: () async {
                  await VueloAlCarrito.lanzarAlConfirmar(
                    contexto,
                    _altaEsperada(backend),
                    imagenUrl: '',
                  );
                },
                child: const Text('Añadir'),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SizedBox(
      height: 56,
      child: Center(
        child: DestinoVuelo(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart),
              Positioned(
                right: -5,
                top: -5,
                child: InsigniaCarrito(cantidad: _cantidad),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _montarTienda(
  WidgetTester tester,
  int inicial, {
  Future<String?> Function()? backend,
}) => tester.pumpWidget(
  MaterialApp(
    home: VueloAlCarrito(
      child: _Tienda(inicial: inicial, backend: backend),
    ),
  ),
);

/// Escala del trago del carrito (el ScaleTransition de DestinoVuelo).
double _trago(WidgetTester tester) =>
    escalaEn(tester, find.byType(DestinoVuelo));

/// Escalas de la insignia: [presencia, rebote].
List<double> _escalas(WidgetTester tester) => tester
    .widgetList<ScaleTransition>(
      find.descendant(
        of: find.byType(InsigniaCarrito),
        matching: find.byType(ScaleTransition),
      ),
    )
    .map((t) => t.scale.value)
    .toList();

void main() {
  testWidgets('en 0 no hay insignia', (tester) async {
    await montarMovimiento(tester, _insignia(0));
    expect(find.text('0'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(InsigniaCarrito),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('al montarse con cantidad no anima', (tester) async {
    await montarMovimiento(tester, _insignia(3));
    expect(find.text('3'), findsOneWidget);
    expect(_escalas(tester), [1, 1]);
  });

  testWidgets('de 0 a 1 aparece creciendo', (tester) async {
    await montarMovimiento(tester, _insignia(0));
    await montarMovimiento(tester, _insignia(1));

    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    expect(_escalas(tester).first, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_escalas(tester), [1, 1]);
  });

  testWidgets('rebota al subir y no al bajar', (tester) async {
    await montarMovimiento(tester, _insignia(1));
    await montarMovimiento(tester, _insignia(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalas(tester).last, greaterThan(1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(AppMovimiento.enfasis);
    expect(_escalas(tester).last, 1);

    await montarMovimiento(tester, _insignia(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalas(tester).last, 1);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('al volver a 0 se encoge con su número y sale del árbol', (
    tester,
  ) async {
    await montarMovimiento(tester, _insignia(2));
    await montarMovimiento(tester, _insignia(0));

    expect(find.text('2'), findsOneWidget); // no muestra «0» al irse
    expect(find.text('0'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_escalas(tester).first, lessThan(1));
    await tester.pump(AppMovimiento.rapida);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('con movimiento reducido aparece y se va al instante', (
    tester,
  ) async {
    await montarMovimiento(tester, _insignia(0), reducido: true);
    await montarMovimiento(tester, _insignia(4), reducido: true);
    expect(_escalas(tester), [1, 1]);

    await montarMovimiento(tester, _insignia(5), reducido: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalas(tester), [1, 1]); // sin rebote

    await montarMovimiento(tester, _insignia(0), reducido: true);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('usa el color que se le da', (tester) async {
    await montarMovimiento(
      tester,
      const InsigniaCarrito(cantidad: 1, color: Colors.teal),
    );
    final caja = tester.widget<Container>(
      find.descendant(
        of: find.byType(InsigniaCarrito),
        matching: find.byType(Container),
      ),
    );
    expect((caja.decoration! as BoxDecoration).color, Colors.teal);
  });

  group('con una miniatura en camino a su carrito', () {
    testWidgets('no rebota: la única reacción es el trago al llegar', (
      tester,
    ) async {
      await _montarTienda(tester, 1);
      await tester.tap(find.text('Agregar'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget); // el número cambia al instante

      // Mientras la miniatura vuela (560 ms) nada se adelanta.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_escalas(tester), [1, 1]);
        expect(_trago(tester), 1);
      }

      await tester.pump(const Duration(milliseconds: 100)); // aterriza
      await tester.pump(const Duration(milliseconds: 100));
      expect(_trago(tester), greaterThan(1));
      expect(_escalas(tester), [1, 1]); // sin rebote aparte
      await tester.pump(AppMovimiento.media);
      expect(_trago(tester), 1);
    });

    testWidgets('de 0 a 1 está en el árbol pero aparece al llegar', (
      tester,
    ) async {
      await _montarTienda(tester, 0);
      await tester.tap(find.text('Agregar'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_escalas(tester).first, 0);

      await tester.pump(const Duration(milliseconds: 300)); // aterriza
      await tester.pump(const Duration(milliseconds: 60));
      expect(_escalas(tester).first, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_escalas(tester), [1, 1]);
    });

    testWidgets('si vuelve a 0 antes de que llegue, ya no aparece', (
      tester,
    ) async {
      await _montarTienda(tester, 0);
      await tester.tap(find.text('Agregar'));
      await tester.pump();
      await tester.tap(find.text('Vaciar'));
      await tester.pump();
      expect(find.text('1'), findsNothing);

      await tester.pump(AppMovimiento.vuelo);
      await tester.pump(AppMovimiento.media);
      expect(find.text('1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin vuelo en camino rebota como siempre', (tester) async {
      await _montarTienda(tester, 1);
      await tester.tap(find.text('Sincronizar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_escalas(tester).last, greaterThan(1));
      expect(_trago(tester), 1);
      await tester.pump(AppMovimiento.enfasis);
    });
  });

  group('con un alta que espera al backend (lanzarAlConfirmar)', () {
    /// La miniatura en vuelo (lo único con ClipOval en la tienda).
    Finder miniatura() => find.byType(ClipOval);

    /// Deja correr la respuesta del backend: el primer pump vacía las
    /// microtareas y el segundo pinta lo que se haya lanzado.
    Future<void> trasResponder(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets('no rebota antes de que salga la miniatura: solo el trago', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      await _montarTienda(tester, 1, backend: () => respuesta.future);
      await tester.tap(find.text('Añadir'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget); // el +1 optimista, al instante

      // El backend tarda 400 ms: nada reacciona ni vuela todavía.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_escalas(tester), [1, 1]);
        expect(_trago(tester), 1);
        expect(miniatura(), findsNothing);
      }

      respuesta.complete();
      await trasResponder(tester);
      expect(miniatura(), findsOneWidget); // sale al aceptar

      // Mientras vuela (560 ms) tampoco.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_escalas(tester), [1, 1]);
        expect(_trago(tester), 1);
      }
      await tester.pump(const Duration(milliseconds: 100)); // aterriza
      await tester.pump(const Duration(milliseconds: 100));
      expect(_trago(tester), greaterThan(1));
      expect(_escalas(tester), [1, 1]); // sin rebote aparte
      await tester.pump(AppMovimiento.media);
      expect(_trago(tester), 1);
    });

    testWidgets('de 0 a 1 está en el árbol y aparece cuando llega', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      await _montarTienda(tester, 0, backend: () => respuesta.future);
      await tester.tap(find.text('Añadir'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_escalas(tester).first, 0);

      respuesta.complete();
      await trasResponder(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_escalas(tester).first, 0); // la miniatura sigue en el aire

      await tester.pump(const Duration(milliseconds: 300)); // aterriza
      await tester.pump(const Duration(milliseconds: 60));
      expect(_escalas(tester).first, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_escalas(tester), [1, 1]);
    });

    testWidgets('si el backend rechaza, vuelve la cantidad sin reaccionar', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      await _montarTienda(tester, 1, backend: () => respuesta.future);
      await tester.tap(find.text('Añadir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2'), findsOneWidget);

      respuesta.complete('No hay stock suficiente');
      await trasResponder(tester);
      expect(find.text('1'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_escalas(tester), [1, 1]);
        expect(_trago(tester), 1);
        expect(miniatura(), findsNothing);
      }
    });

    testWidgets('de 0 a 1 rechazada nunca aparece', (tester) async {
      final respuesta = Completer<String?>();
      await _montarTienda(tester, 0, backend: () => respuesta.future);
      await tester.tap(find.text('Añadir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_escalas(tester).first, 0);

      respuesta.complete('No hay stock suficiente');
      await trasResponder(tester);
      expect(find.text('1'), findsNothing);
      expect(miniatura(), findsNothing);
      await tester.pump(AppMovimiento.media);
      expect(find.text('1'), findsNothing);
      expect(_trago(tester), 1);
      expect(tester.takeException(), isNull);
    });
  });
}
