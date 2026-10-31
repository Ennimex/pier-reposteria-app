// test/esfuerzo/volumen_test.dart — volumen de datos (#70): la app con mucho
// más de lo que tiene en el uso normal, sin red. La corre
// esfuerzo-volumen.yml (a mano). El catálogo de 1,000 productos se agrega
// cuando el catálogo por páginas (#37) llegue a develop: cambia cómo se piden
// los productos y la prueba tiene que escribirse sobre esa forma.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_linea.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_screen.dart';

import '../fakes/fake_api_client.dart';
import '../helpers/pump_app.dart';

/// Cuántos artículos distintos lleva el carrito.
const _articulos = 100;

/// Precio del artículo [i] (1 a 100): 11, 12, …, 110 pesos.
int _precio(int i) => 10 + i;

/// El backend con el carrito lleno: [_articulos] productos distintos, uno de
/// cada uno, con la forma de GET /carrito.
FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
      },
      ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
      ApiConstants.carrito: {
        'success': true,
        'carrito': {
          'items': [
            for (var i = 1; i <= _articulos; i++)
              {
                'producto_id': i,
                'carrito_item_id': 1000 + i,
                'nombre': 'Producto $i',
                'precio_unitario': _precio(i).toStringAsFixed(2),
                'precio_original': _precio(i).toStringAsFixed(2),
                'cantidad': 1,
                'tamano': 'chico',
              },
          ],
        },
      },
    });

/// Página de partida que abre «Mi Carrito», como la pestaña del carrito.
class _Anfitriona extends StatelessWidget {
  const _Anfitriona();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const CartScreen()),
          ),
          child: const Text('Ver carrito'),
        ),
      );
}

void main() {
  group('Volumen de datos (#70)', () {
    testWidgets('carrito de 100 artículos: total correcto y llega al último',
        (tester) async {
      // Un celular como el Note 10+ (412×869 lógicos).
      tester.view
        ..physicalSize = const Size(1440, 3040)
        ..devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpApp(const _Anfitriona(), api: _backend());
      await tester.iniciarSesion(find.byType(_Anfitriona));
      await tester.pump();

      await tester.tap(find.text('Ver carrito'));
      // El total se anima: se deja correr el tiempo sin esperar a que todo
      // termine.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 11 + 12 + … + 110 = 6,050 pesos.
      final total = [for (var i = 1; i <= _articulos; i++) _precio(i)]
          .reduce((a, b) => a + b);
      expect(total, 6050);
      expect(find.text('\$$total MXN'), findsOneWidget);
      expect(find.text('$_articulos productos'), findsOneWidget);
      expect(find.widgetWithText(CartLinea, 'Producto 1'), findsOneWidget);

      final ultimo = find.widgetWithText(CartLinea, 'Producto $_articulos');
      await tester.scrollUntilVisible(
        ultimo,
        600,
        scrollable: find
            .descendant(
                of: find.byType(CartScreen), matching: find.byType(Scrollable))
            .first,
      );
      expect(ultimo, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
