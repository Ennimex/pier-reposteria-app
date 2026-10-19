// test/widget/orders/movimiento_pedidos_test.dart — el movimiento de «Mis
// Pedidos» y del detalle de un pedido: las tarjetas entran una sola vez
// (volver a la pestaña no repite la entrada y un pedido nuevo sí entra), la
// insignia de activos termina en su texto exacto, el chip de estado lleva el
// mismo Hero en la tarjeta y en el detalle, la línea de tiempo se llena de
// cero hasta el paso actual y su halo termina solo, al cancelar la línea y
// el botón salen del árbol y el diálogo abre como caja; con movimiento
// reducido todo queda en su estado final sin cuadros pendientes. También
// las piezas de movimiento_pedidos.dart. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/orders/view_model/order_detail_view_model.dart';
import 'package:pier_reposteria/ui/orders/view_model/orders_view_model.dart';
import 'package:pier_reposteria/ui/orders/widgets/detalle_pedido_partes.dart';
import 'package:pier_reposteria/ui/orders/widgets/detalle_pedido_timeline.dart';
import 'package:pier_reposteria/ui/orders/widgets/estado_pedido.dart';
import 'package:pier_reposteria/ui/orders/widgets/movimiento_pedidos.dart';
import 'package:pier_reposteria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_reposteria/ui/orders/widgets/orders_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

// ── Datos del backend falso ─────────────────────────────────────────────

Map<String, dynamic> _pedidoLista(int id, String numero) => {
  'id': id,
  'numero': numero,
  'estado': 'pendiente',
};

Map<String, dynamic> _misPedidos(List<Map<String, dynamic>> pedidos) => {
  'success': true,
  'pedidos': pedidos,
};

final String _detalle = ApiConstants.pedidoById('7');
final String _cancelar = ApiConstants.pedidoCancelar('7');

Map<String, dynamic> _respuestaDetalle(String estado) => {
  'success': true,
  'pedido': {
    'id': 7,
    'numero': 'PIER-261010-0007',
    'estado': estado,
    'tipo_entrega': 'pickup',
    'total': 300,
    'created_at': '2026-10-10T09:05:00',
  },
  'items': [
    {
      'nombre_producto': 'Chocoflan',
      'cantidad': 2,
      'precio_unitario': 150,
      'subtotal': 300,
    },
  ],
};

Order _pedido() => Order(
  id: '7',
  numero: 'PIER-261010-0007',
  items: const [],
  total: 300,
  status: OrderStatus.ready,
  createdAt: DateTime(2026, 10, 10, 9, 5),
);

// ── Montaje ─────────────────────────────────────────────────────────────

/// Pantalla de celular (412×869 lógicos, como el Note 10+).
void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

/// «Mis Pedidos» con sesión y con [pedidos] activos, después de entrar a la
/// pestaña (recarga silenciosa, como en la app). En la pantalla de 800×600
/// de las pruebas, como orders_screen_test: con la fuente de pruebas el
/// título y la insignia no caben en 412 de ancho.
Future<FakeApiClient> _montarLista(
  WidgetTester tester,
  List<Map<String, dynamic>> pedidos,
) async {
  final api = FakeApiClient(
    respuestas: {
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'nombre': 'Ana', 'rol': 'cliente'},
      },
      ApiConstants.misPedidos: _misPedidos(pedidos),
      _detalle: _respuestaDetalle('pendiente'),
    },
  );
  await tester.pumpApp(
    OrdersScreen(
      viewModel: OrdersViewModel(repo: PedidosRepositoryRemote(api: api)),
    ),
    api: api,
  );
  await tester.pump();
  await tester.iniciarSesion(find.byType(OrdersScreen), password: 'x');
  _volverALaPestana(tester);
  // Primer cuadro con la lista; el siguiente es el tick 0 de las entradas.
  await tester.pump();
  await tester.pump();
  return api;
}

/// Como tocar la pestaña Pedidos: recarga en silencio.
void _volverALaPestana(WidgetTester tester) {
  tester.element(find.byType(OrdersScreen)).read<NavigationProvider>()
    ..setSelectedIndex(0)
    ..setSelectedIndex(3);
}

/// La entrada (EntradaSuave) más cercana que envuelve a [texto].
Finder _entradaDe(String texto) => find
    .ancestor(of: find.text(texto), matching: find.byType(EntradaSuave))
    .first;

/// El detalle de un pedido «listo para recoger» como ruta inicial.
Future<FakeApiClient> _montarDetalle(
  WidgetTester tester, {
  bool reducido = false,
}) async {
  _celular(tester);
  final api = FakeApiClient(respuestas: {_detalle: _respuestaDetalle('listo')});
  final pedido = _pedido();
  final pantalla = OrderDetailScreen(
    order: pedido,
    viewModel: OrderDetailViewModel(
      repo: PedidosRepositoryRemote(api: api),
      pedido: pedido,
    ),
  );
  await tester.pumpApp(
    reducido ? ConMovimientoReducido(child: pantalla) : pantalla,
    api: api,
  );
  return api;
}

/// Cuánto está lleno cada tramo de la línea de tiempo, en orden.
List<double> _tramos(WidgetTester tester) => tester
    .widgetList<FractionallySizedBox>(
      find.descendant(
        of: find.byType(DetallePedidoTimeline),
        matching: find.byType(FractionallySizedBox),
      ),
    )
    .map((tramo) => tramo.widthFactor!)
    .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Mis Pedidos', () {
    testWidgets('las tarjetas entran una vez: volver a la pestaña no repite '
        'la entrada y un pedido nuevo sí entra', (tester) async {
      final api = await _montarLista(tester, [_pedidoLista(1, 'PIER-UNO')]);

      expect(opacidadEn(tester, _entradaDe('PIER-UNO')), lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(opacidadEn(tester, _entradaDe('PIER-UNO')), 1);

      // Volver a la pestaña recarga con los mismos pedidos: nada se repite.
      _volverALaPestana(tester);
      await tester.pump();
      await tester.pump();
      expect(opacidadEn(tester, _entradaDe('PIER-UNO')), 1);

      // Llega un pedido nuevo: entra él, el que ya estaba no.
      api.responder(
        ApiConstants.misPedidos,
        _misPedidos([_pedidoLista(2, 'PIER-DOS'), _pedidoLista(1, 'PIER-UNO')]),
      );
      _volverALaPestana(tester);
      await tester.pump();
      await tester.pump();
      expect(opacidadEn(tester, _entradaDe('PIER-DOS')), lessThan(1));
      expect(opacidadEn(tester, _entradaDe('PIER-UNO')), 1);

      await tester.pump(const Duration(seconds: 1));
      expect(opacidadEn(tester, _entradaDe('PIER-DOS')), 1);
    });

    testWidgets('la insignia de activos aparece y su cuenta termina exacta', (
      tester,
    ) async {
      final api = await _montarLista(tester, [_pedidoLista(1, 'PIER-UNO')]);
      expect(find.text('1 activo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      api.responder(
        ApiConstants.misPedidos,
        _misPedidos([_pedidoLista(2, 'PIER-DOS'), _pedidoLista(1, 'PIER-UNO')]),
      );
      _volverALaPestana(tester);
      await tester.pump();
      expect(find.text('2 activos'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 activos'), findsOneWidget);
      expect(find.text('1 activo'), findsNothing);
    });

    testWidgets('la tarjeta se hunde al tocarla y su chip vuela al detalle '
        'con la misma etiqueta', (tester) async {
      await _montarLista(tester, [_pedidoLista(7, 'PIER-261010-0007')]);
      await tester.pump(const Duration(seconds: 1));

      final tarjeta = find.text('PIER-261010-0007');
      expect(
        find.ancestor(of: tarjeta, matching: find.byType(PresionEscala)),
        findsOneWidget,
      );
      final heroeLista = tester.widget<Hero>(
        find.descendant(
          of: find.byType(EstadoPedidoHero),
          matching: find.byType(Hero),
        ),
      );
      expect(heroeLista.tag, EstadoPedidoHero.etiqueta('7'));

      await tester.tap(tarjeta);
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      final heroeDetalle = tester.widget<Hero>(
        find.descendant(
          of: find.byType(OrderDetailScreen),
          matching: find.byType(Hero),
        ),
      );
      expect(heroeDetalle.tag, heroeLista.tag);
    });
  });

  group('Detalle del pedido', () {
    testWidgets('la línea se llena de cero hasta el paso actual y su halo '
        'termina solo', (tester) async {
      await _montarDetalle(tester);
      // Recibido → Listo → Entregado, en «Listo»: al llegar, todo vacío.
      expect(_tramos(tester), [0, 0, 0, 0]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final aMedias = _tramos(tester);
      expect(aMedias.first, greaterThan(0));

      // pumpAndSettle no termina si algo se repite sin fin.
      await tester.pumpAndSettle();
      expect(_tramos(tester), [1, 1, 0, 0]);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('los bloques se arman en cascada después de llegar', (
      tester,
    ) async {
      await _montarDetalle(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final estado = opacidadEn(tester, _entradaDe('Listo para recoger'));
      final resumen = opacidadEn(tester, _entradaDe('Resumen de pago'));
      expect(estado, greaterThan(resumen));

      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('Listo para recoger')), 1);
      expect(opacidadEn(tester, _entradaDe('Resumen de pago')), 1);
    });

    testWidgets('el diálogo de cancelar abre como caja y, al cancelar, la '
        'línea y el botón salen del árbol', (tester) async {
      final api = await _montarDetalle(tester);
      await tester.pumpAndSettle();
      api
        ..responder(_cancelar, {'success': true, 'message': 'Cancelado ok'})
        ..responder(_detalle, _respuestaDetalle('cancelado'));

      await tester.ensureVisible(find.text('Cancelar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar pedido'));
      await tester.pumpAndSettle();
      expect(find.byType(EntradaDialogo), findsOneWidget);

      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Pedido cancelado'), findsOneWidget);
      expect(find.text('Recibido'), findsNothing);
      expect(find.byType(BotonCancelarPedido), findsNothing);
      expect(find.text('Cancelando…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cancelado'), findsNWidgets(2));
    });

    testWidgets('con movimiento reducido queda en su estado final de '
        'inmediato y sin cuadros pendientes', (tester) async {
      await _montarDetalle(tester, reducido: true);
      await tester.pump();

      expect(_tramos(tester), [1, 1, 0, 0]);
      expect(opacidadEn(tester, _entradaDe('Resumen de pago')), 1);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('piezas de movimiento_pedidos', () {
    testWidgets('ContadorRodante rueda y termina en su texto exacto', (
      tester,
    ) async {
      Widget contador(int valor) =>
          ContadorRodante(valor: valor, texto: '$valor activos');
      await montarMovimiento(tester, contador(2));
      final reposo = tester.getTopLeft(find.text('2 activos')).dy;

      await montarMovimiento(tester, contador(1));
      await tester.pump(const Duration(milliseconds: 50));
      // Baja: el nuevo llega desde arriba.
      expect(tester.getTopLeft(find.text('1 activos')).dy, lessThan(reposo));

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 activos'), findsOneWidget);
      expect(find.text('2 activos'), findsNothing);
      expect(tester.getTopLeft(find.text('1 activos')).dy, reposo);
    });

    testWidgets(
      'MovimientoUnaVez avanza una sola vez y, reducido, queda en 1',
      (tester) async {
        Widget gesto() => MovimientoUnaVez(
          duracion: const Duration(milliseconds: 300),
          builder: (context, avance, _) => AnimatedBuilder(
            animation: avance,
            builder: (_, _) => Text(avance.value.toStringAsFixed(1)),
          ),
        );
        await montarMovimiento(tester, gesto());
        expect(find.text('0.0'), findsOneWidget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('1.0'), findsOneWidget);

        // Reconstruir no lo repite.
        await montarMovimiento(tester, gesto());
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('1.0'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);

        await tester.pumpWidget(const SizedBox());
        await montarMovimiento(tester, gesto(), reducido: true);
        expect(find.text('1.0'), findsOneWidget);
      },
    );

    testWidgets('esperaDeLlegada: nada en una pantalla ya visible, '
        'trasEmpuje mientras la página llega', (tester) async {
      final esperas = <String, Duration>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              esperas['inicio'] = esperaDeLlegada(context);
              return TextButton(
                onPressed: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (context) {
                          esperas['empujada'] ??= esperaDeLlegada(context);
                          return const SizedBox();
                        },
                      ),
                    )
                    .ignore(),
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      );
      expect(esperas['inicio'], Duration.zero);

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      expect(esperas['empujada'], AppMovimiento.trasEmpuje);
      await tester.pumpAndSettle();
    });

    testWidgets('esperaDeLlegada: trasPestana con los tickers apagados', (
      tester,
    ) async {
      Duration? espera;
      await montarMovimiento(
        tester,
        TickerMode(
          enabled: false,
          child: Builder(
            builder: (context) {
              espera = esperaDeLlegada(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(espera, AppMovimiento.trasPestana);
    });
  });
}
