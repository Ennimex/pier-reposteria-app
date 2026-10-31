// test/aceptacion/pedidos/mis_pedidos_test.dart — escenarios Gherkin de «Mis
// Pedidos»: activos e historial, el detalle de un pedido y el repartidor en
// camino (#64; historia #39), sin red.
//
// Cada prueba recorre la app como el cliente: inicia sesión, abre «Mis
// Pedidos» desde una página anfitriona (en la app es una pestaña), cambia de
// pestaña o entra al detalle tocando la tarjeta. El backend es
// BackendMisPedidos (test/fakes/mis_pedidos_json.dart): los pedidos en
// memoria sobre FakeApiClient, con el estado que define la API.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_reposteria/ui/orders/widgets/orders_screen.dart';

import '../../fakes/mis_pedidos_json.dart';
import '../../helpers/pump_app.dart';

/// Los pedidos del cliente. En curso: uno para recoger, ya listo, y otro a
/// domicilio, en camino. Terminados: uno entregado y uno cancelado.
List<Map<String, dynamic>> _pedidos() => [
  miPedidoJson(
    id: 1,
    estado: 'listo',
    productos: [
      productoDelPedidoJson(
        'Chocoflan',
        precio: 150,
        cantidad: 2,
        tamano: 'grande',
      ),
      productoDelPedidoJson('Pay de queso', precio: 250),
    ],
  ),
  miPedidoJson(
    id: 2,
    estado: 'en_camino',
    domicilio: true,
    productos: [productoDelPedidoJson('Rosca de reyes', precio: 480)],
  ),
  miPedidoJson(id: 3, estado: 'entregado', domicilio: true),
  miPedidoJson(id: 4, estado: 'cancelado'),
];

/// Página de partida: «Mis pedidos» abre la pantalla de la pestaña.
class _Cuenta extends StatelessWidget {
  const _Cuenta();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
        ),
        child: const Text('Mis pedidos'),
      ),
    ),
  );
}

/// Dado que inicié sesión y tengo pedidos / Cuando abro la sección de
/// pedidos. En la pantalla de 800×600 de las pruebas, como
/// orders_screen_test.dart: con la fuente de pruebas el título y la
/// insignia no caben en 412 de ancho.
Future<BackendMisPedidos> _abrirMisPedidos(WidgetTester tester) async {
  final backend = BackendMisPedidos(_pedidos());
  await tester.pumpApp(const _Cuenta(), api: backend.api);
  await tester.iniciarSesion(find.byType(_Cuenta));
  await tester.tap(find.text('Mis pedidos'));
  await tester.pumpAndSettle();
  return backend;
}

/// La tarjeta del pedido [numero] en «Mis Pedidos».
Finder _tarjeta(String numero) => find
    .ancestor(of: find.text(numero), matching: find.byType(PresionEscala))
    .first;

/// El chip de [estado] en la tarjeta del pedido [numero].
Finder _chip(String numero, String estado) =>
    find.descendant(of: _tarjeta(numero), matching: find.text(estado));

/// Deja llegar el detalle sin esperar a que todo termine: el Lottie del
/// repartidor se repite sin fin y pumpAndSettle no acabaría.
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('#39 Mis pedidos: activos, historial y detalle', () {
    // Escenario: pedidos activos e historial
    //   Dado que inicié sesión y tengo pedidos
    //   Cuando abro la sección de pedidos
    //   Entonces veo una pestaña «Activos» y otra «Historial» con los
    //   pedidos de cada grupo
    testWidgets('Escenario: pedidos activos e historial', (tester) async {
      // Dado que inicié sesión y tengo pedidos / Cuando abro la sección de
      // pedidos
      final backend = await _abrirMisPedidos(tester);
      expect(
        backend.api.llamo(ApiConstants.misPedidos, metodo: 'GET-Auth'),
        isTrue,
      );

      // Entonces veo una pestaña «Activos» y otra «Historial»…
      expect(find.text('Activos'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);

      // …en «Activos», los pedidos que siguen en curso, con su estado
      expect(find.text('2 activos'), findsOneWidget);
      expect(_chip('PIER-261031-0001', 'Listo'), findsOneWidget);
      expect(_chip('PIER-261031-0002', 'En camino'), findsOneWidget);
      expect(find.text('PIER-261031-0003'), findsNothing);
      expect(find.text('PIER-261031-0004'), findsNothing);

      // …y en «Historial», los que ya terminaron
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(_chip('PIER-261031-0003', 'Entregado'), findsOneWidget);
      expect(_chip('PIER-261031-0004', 'Cancelado'), findsOneWidget);
      expect(find.text('PIER-261031-0001'), findsNothing);
      expect(find.text('PIER-261031-0002'), findsNothing);
    });

    // Escenario: detalle de un pedido
    //   Dado que estoy en mi lista de pedidos
    //   Cuando abro uno
    //   Entonces veo sus productos, su total, su tipo de entrega y su estado
    //   actual
    testWidgets('Escenario: detalle de un pedido', (tester) async {
      // Dado que estoy en mi lista de pedidos
      final backend = await _abrirMisPedidos(tester);
      expect(_tarjeta('PIER-261031-0001'), findsOneWidget);

      // Cuando abro uno
      await tester.tap(find.text('PIER-261031-0001'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      // (el detalle vuelve a leer el pedido del backend)
      expect(
        backend.api.llamo(ApiConstants.pedidoById('1'), metodo: 'GET-Auth'),
        isTrue,
      );

      // Entonces veo sus productos…
      expect(find.text('Productos (2)'), findsOneWidget);
      expect(find.text('Chocoflan'), findsOneWidget);
      expect(find.text(r'2× $150 c/u · grande'), findsOneWidget);
      expect(find.text('Pay de queso'), findsOneWidget);
      expect(find.text(r'1× $250 c/u'), findsOneWidget);
      // …su total…
      expect(find.text('Resumen de pago'), findsOneWidget);
      expect(find.text(r'$550 MXN'), findsOneWidget);
      // …su tipo de entrega…
      expect(find.text('Recoger en sucursal'), findsOneWidget);
      expect(find.text('Principal — Huejutla de Reyes'), findsOneWidget);
      // …y su estado actual
      expect(find.text('Listo para recoger'), findsOneWidget);
      expect(
        find.text('Tu pedido está listo. Pasa a recogerlo'),
        findsOneWidget,
      );
    });

    // Escenario: repartidor en camino
    //   Dado que tengo un pedido a domicilio en estado «en camino»
    //   Cuando abro su detalle
    //   Entonces la app indica que el repartidor va en camino
    testWidgets('Escenario: repartidor en camino', (tester) async {
      // Dado que tengo un pedido a domicilio en estado «en camino»
      await _abrirMisPedidos(tester);
      expect(_chip('PIER-261031-0002', 'En camino'), findsOneWidget);

      // Cuando abro su detalle
      await tester.tap(find.text('PIER-261031-0002'));
      await _asentar(tester);
      expect(find.byType(OrderDetailScreen), findsOneWidget);

      // Entonces la app indica que el repartidor va en camino
      expect(find.textContaining('¡Tu pedido va en camino!'), findsOneWidget);
      expect(
        find.textContaining('El repartidor está por llegar.'),
        findsOneWidget,
      );
      expect(
        find.text('Tu pedido va en camino a tu domicilio'),
        findsOneWidget,
      );
      expect(find.text('A domicilio'), findsOneWidget);
    });
  });
}
