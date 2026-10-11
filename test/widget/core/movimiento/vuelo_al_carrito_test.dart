// test/widget/core/movimiento/vuelo_al_carrito_test.dart — VueloAlCarrito:
// sin ámbito (pruebas sueltas) no hace nada; con ámbito la miniatura vuela
// en el Overlay raíz del botón al ícono del carrito, se quita sola y el ícono
// da un trago; no vuela con «reducir movimiento» ni sin destino, admite tres
// vuelos a la vez y se limpia si el ámbito se desmonta a medio vuelo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// La miniatura en vuelo (lo único con ClipOval en estas pruebas).
Finder get _miniatura => find.byType(ClipOval);

Finder get _boton => find.text('Agregar');

/// Pantalla con un botón «Agregar» arriba y el carrito abajo.
class _Tienda extends StatelessWidget {
  const _Tienda({
    this.conDestino = true,
    this.origen,
    this.desde,
    this.imagenUrl = '',
  });

  final bool conDestino;
  final GlobalKey? origen;
  final Rect? desde;
  final String imagenUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(key: origen, dimension: 60),
          Builder(
            builder: (contexto) => ElevatedButton(
              onPressed: () => VueloAlCarrito.lanzar(
                contexto,
                imagenUrl: imagenUrl,
                origen: origen,
                desde: desde,
              ),
              child: const Text('Agregar'),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SizedBox(
      height: 56,
      child: Center(
        child: conDestino
            ? const DestinoVuelo(child: Icon(Icons.shopping_cart))
            : const Icon(Icons.shopping_cart),
      ),
    ),
  );
}

Widget _app(Widget tienda, {bool conAmbito = true, bool reducido = false}) {
  var pantalla = conAmbito ? VueloAlCarrito(child: tienda) : tienda;
  if (reducido) pantalla = ConMovimientoReducido(child: pantalla);
  return MaterialApp(home: pantalla);
}

double _escalaDestino(WidgetTester tester) => escalaEn(
  tester,
  find.ancestor(
    of: find.byIcon(Icons.shopping_cart),
    matching: find.byType(DestinoVuelo),
  ),
);

void main() {
  testWidgets('sin ámbito no hace nada', (tester) async {
    await tester.pumpWidget(_app(const _Tienda(), conAmbito: false));
    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vuela del botón al carrito en el Overlay raíz y se quita', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Tienda()));
    final boton = tester.getCenter(_boton);
    final carrito = tester.getCenter(find.byIcon(Icons.shopping_cart));

    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Overlay).first,
        matching: _miniatura,
      ),
      findsOneWidget,
    );
    expect(tester.getCenter(_miniatura), boton);

    await tester.pump(const Duration(milliseconds: 280));
    final enMedio = tester.getCenter(_miniatura);
    expect(enMedio.dy, inExclusiveRange(boton.dy - 200, carrito.dy));

    await tester.pump(const Duration(milliseconds: 300));
    expect(_miniatura, findsNothing);
    // Al aterrizar, el ícono del carrito da un trago.
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalaDestino(tester), greaterThan(1));
    await tester.pump(AppMovimiento.media);
    expect(_escalaDestino(tester), 1);
  });

  testWidgets('el origen puede ser una GlobalKey o un rectángulo', (
    tester,
  ) async {
    final foto = GlobalKey();
    await tester.pumpWidget(_app(_Tienda(origen: foto)));
    await tester.tap(_boton);
    await tester.pump();
    expect(
      tester.getCenter(_miniatura),
      tester.getCenter(find.byKey(foto)),
    );
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);

    const rect = Rect.fromLTWH(10, 400, 40, 40);
    await tester.pumpWidget(_app(const _Tienda(desde: rect)));
    await tester.tap(_boton);
    await tester.pump();
    expect(tester.getCenter(_miniatura), rect.center);
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
  });

  testWidgets('con una URL muestra la foto (y arena dorada si falla)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const _Tienda(imagenUrl: 'https://pier.mx/pastel.png')),
    );
    await tester.tap(_boton);
    await tester.pump();
    expect(
      find.descendant(of: _miniatura, matching: find.byType(Image)),
      findsOneWidget,
    );
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
  });

  testWidgets('con movimiento reducido no vuela', (tester) async {
    await tester.pumpWidget(_app(const _Tienda(), reducido: true));
    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsNothing);
  });

  testWidgets('sin destino visible no vuela', (tester) async {
    await tester.pumpWidget(_app(const _Tienda(conDestino: false)));
    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsNothing);
  });

  testWidgets('como máximo tres vuelos a la vez', (tester) async {
    await tester.pumpWidget(_app(const _Tienda()));
    for (var i = 0; i < 5; i++) {
      await tester.tap(_boton);
    }
    await tester.pump();
    expect(_miniatura, findsNWidgets(3));
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
    expect(_miniatura, findsNothing);
  });

  testWidgets('si el ámbito se desmonta a medio vuelo, el vuelo se quita', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Tienda()));
    await tester.tap(_boton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_miniatura, findsOneWidget);

    // Como cerrar sesión: el shell se va con un vuelo en el aire.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(_miniatura, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
