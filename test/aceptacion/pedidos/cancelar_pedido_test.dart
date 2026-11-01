// test/aceptacion/pedidos/cancelar_pedido_test.dart — escenarios Gherkin de
// cancelar un pedido que aún es cancelable (#64; historia #40) y el caso de
// error «pedido no cancelable», sin red.
//
// Cada prueba recorre la app como el cliente: inicia sesión, abre «Mis
// Pedidos», entra al detalle de un pedido y toca «Cancelar pedido». El
// backend es BackendMisPedidos (test/fakes/mis_pedidos_json.dart), que
// aplica la regla de PUT /pedidos/:id/cancelar: solo «pendiente» o «listo»,
// y genera la solicitud de reembolso si el pedido se pagó en línea.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/orders/widgets/detalle_pedido_partes.dart';
import 'package:pier_reposteria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_reposteria/ui/orders/widgets/orders_screen.dart';

import '../../fakes/mis_pedidos_json.dart';
import '../../helpers/pump_app.dart';

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

/// Inicia sesión y abre «Mis Pedidos» con [pedidos] en el backend. En la
/// pantalla de 800×600 de las pruebas, como orders_screen_test.dart: con la
/// fuente de pruebas el título y la insignia no caben en 412 de ancho.
Future<BackendMisPedidos> _abrirMisPedidos(
  WidgetTester tester,
  List<Map<String, dynamic>> pedidos,
) async {
  final backend = BackendMisPedidos(pedidos);
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

/// Abre el detalle del pedido [numero] tocando su tarjeta.
Future<void> _abrirPedido(WidgetTester tester, String numero) async {
  await tester.ensureVisible(find.text(numero));
  await tester.pumpAndSettle();
  await tester.tap(find.text(numero));
  await tester.pumpAndSettle();
  expect(find.byType(OrderDetailScreen), findsOneWidget);
}

/// Regresa del detalle a «Mis Pedidos» con la flecha del encabezado.
Future<void> _volver(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.chevronLeft));
  await tester.pumpAndSettle();
}

/// Baja hasta «Cancelar pedido» (queda bajo el pliegue) y lo toca.
Future<void> _elegirCancelar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Cancelar pedido'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cancelar pedido'));
  await tester.pumpAndSettle();
}

void main() {
  group('#40 Cancelar un pedido que aún es cancelable', () {
    // Escenario: pedido cancelable
    //   Dado que tengo un pedido en estado «pendiente» o «listo»
    //   Cuando abro su detalle
    //   Entonces la app me ofrece la opción de cancelarlo
    testWidgets('Escenario: pedido cancelable', (tester) async {
      // Dado que tengo un pedido en estado «pendiente» y otro «listo».
      // Ajuste: con el pago actual, un pedido «pendiente» es uno programado
      // que la sucursal aún confirma (por_confirmar): la app lo muestra como
      // «Por confirmar» y también deja cancelarlo.
      await _abrirMisPedidos(tester, [
        miPedidoJson(id: 5, estado: 'pendiente', porConfirmar: true),
        miPedidoJson(id: 6, estado: 'listo'),
      ]);
      expect(_chip('PIER-261031-0005', 'Por confirmar'), findsOneWidget);
      expect(_chip('PIER-261031-0006', 'Listo'), findsOneWidget);

      // Cuando abro el detalle del «pendiente»
      await _abrirPedido(tester, 'PIER-261031-0005');

      // Entonces la app me ofrece la opción de cancelarlo
      expect(
        find.textContaining('estamos confirmando la disponibilidad'),
        findsOneWidget,
      );
      expect(find.text('Cancelar pedido'), findsOneWidget);
      expect(
        find.text('Disponible mientras tu pedido no haya sido tomado'),
        findsOneWidget,
      );

      // Y lo mismo en el detalle del «listo»
      await _volver(tester);
      await _abrirPedido(tester, 'PIER-261031-0006');
      expect(
        find.text('Tu pedido está listo. Pasa a recogerlo'),
        findsOneWidget,
      );
      expect(find.text('Cancelar pedido'), findsOneWidget);
    });

    // Escenario: confirmar la cancelación
    //   Dado que elegí cancelar un pedido cancelable
    //   Cuando confirmo en el diálogo
    //   Entonces el pedido se cancela y se genera mi solicitud de reembolso
    testWidgets('Escenario: confirmar la cancelación', (tester) async {
      // Dado que elegí cancelar un pedido cancelable (listo, pagado con
      // tarjeta)
      final backend = await _abrirMisPedidos(tester, [
        miPedidoJson(id: 6, estado: 'listo'),
      ]);
      expect(find.text('1 activo'), findsOneWidget);
      await _abrirPedido(tester, 'PIER-261031-0006');
      await _elegirCancelar(tester);
      expect(find.text('¿Cancelar pedido?'), findsOneWidget);
      expect(
        find.textContaining('Si lo pagaste en línea, generaremos'),
        findsOneWidget,
      );

      // Cuando confirmo en el diálogo
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      // Entonces el pedido se cancela…
      expect(
        backend.api.llamo(ApiConstants.pedidoCancelar('6'), metodo: 'PUT-Auth'),
        isTrue,
      );
      expect(backend.pedido(6)['estado'], 'cancelado');
      expect(find.text('Pedido cancelado'), findsOneWidget);
      expect(find.text('Este pedido fue cancelado'), findsOneWidget);
      expect(find.byType(BotonCancelarPedido), findsNothing);

      // …y se genera mi solicitud de reembolso.
      // Ajuste: el backend solo la genera si el pedido se pagó en línea
      // (#40, como lo advierte el diálogo); este se pagó con tarjeta y la
      // app muestra el mensaje del backend con el monto. La app no crea el
      // reembolso: lo hace el backend al cancelar.
      expect(
        find.text(
          r'Pedido cancelado; generamos tu solicitud de reembolso por $300.00',
        ),
        findsOneWidget,
      );
      expect(backend.pedido(6)['reembolso'], {
        'id': 1,
        'estado': 'pendiente',
        'monto': '300.00',
      });

      // En «Mis Pedidos» ya no está entre los activos: pasó al historial
      await _volver(tester);
      expect(find.text('No tienes pedidos activos'), findsOneWidget);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(_chip('PIER-261031-0006', 'Cancelado'), findsOneWidget);
    });

    // Escenario: pedido ya asignado
    //   Dado que mi pedido ya fue asignado a un repartidor
    //   Cuando abro su detalle
    //   Entonces la opción de cancelar ya no aparece
    testWidgets('Escenario: pedido ya asignado', (tester) async {
      // Dado que mi pedido ya fue asignado a un repartidor
      final backend = await _abrirMisPedidos(tester, [
        miPedidoJson(id: 7, estado: 'asignado', domicilio: true),
      ]);
      expect(_chip('PIER-261031-0007', 'Asignado'), findsOneWidget);

      // Cuando abro su detalle
      await _abrirPedido(tester, 'PIER-261031-0007');

      // Entonces la opción de cancelar ya no aparece
      expect(find.text('Repartidor asignado'), findsOneWidget);
      expect(
        find.text('Un repartidor tomó tu pedido y saldrá pronto'),
        findsOneWidget,
      );
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.byType(BotonCancelarPedido), findsNothing);
      expect(backend.api.llamo(ApiConstants.pedidoCancelar('7')), isFalse);
    });

    // Escenario: pedido no cancelable (caso de error del #64)
    //   Dado que abrí el detalle de mi pedido «listo» a domicilio
    //   Y un repartidor lo tomó antes de que yo confirmara la cancelación
    //   Cuando confirmo en el diálogo
    //   Entonces la app muestra el motivo del backend
    //   Y el pedido sigue en curso, ya sin la opción de cancelar
    testWidgets('Escenario: pedido no cancelable', (tester) async {
      final backend = await _abrirMisPedidos(tester, [
        miPedidoJson(id: 8, estado: 'listo', domicilio: true),
      ]);

      // Dado que abrí el detalle de mi pedido «listo» a domicilio
      await _abrirPedido(tester, 'PIER-261031-0008');
      expect(
        find.text('Tu pedido está listo y en espera de un repartidor'),
        findsOneWidget,
      );
      await _elegirCancelar(tester);
      expect(find.text('¿Cancelar pedido?'), findsOneWidget);

      // Y un repartidor lo tomó antes de que yo confirmara la cancelación
      backend.asignarRepartidor(8);

      // Cuando confirmo en el diálogo
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      // Entonces la app muestra el motivo del backend
      expect(find.text(BackendMisPedidos.yaTomado), findsOneWidget);

      // Y el pedido sigue en curso, ya sin la opción de cancelar
      expect(backend.pedido(8)['estado'], 'asignado');
      expect(find.text('Repartidor asignado'), findsOneWidget);
      expect(find.text('Pedido cancelado'), findsNothing);
      expect(find.byType(BotonCancelarPedido), findsNothing);
    });
  });
}
