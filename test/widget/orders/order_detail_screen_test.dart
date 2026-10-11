// test/widget/orders/order_detail_screen_test.dart — la vista del detalle de
// un pedido pinta lo que expone su ViewModel (MVVM, Fase 5) y confirma antes
// de cancelar, sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/orders/view_model/order_detail_view_model.dart';
import 'package:pier_pasteleria/ui/orders/widgets/estado_pedido.dart';
import 'package:pier_pasteleria/ui/orders/widgets/order_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _detalle = ApiConstants.pedidoById('7');
final String _cancelar = ApiConstants.pedidoCancelar('7');

Order _pedido({OrderStatus estado = OrderStatus.ready, String? tipoEntrega}) =>
    Order(
      id: '7',
      numero: 'PIER-261010-0007',
      items: const [],
      total: 300,
      tipoEntrega: tipoEntrega,
      status: estado,
      createdAt: DateTime(2026, 10, 10, 9, 5),
    );

Map<String, dynamic> _respuestaDetalle(String estado,
        {String tipo = 'pickup'}) =>
    {
      'success': true,
      'pedido': {
        'id': 7,
        'numero': 'PIER-261010-0007',
        'estado': estado,
        'tipo_entrega': tipo,
        'total': 300,
        'horario_recogida': '10:00 - 11:00',
        'notas': 'Sin nuez',
        'created_at': '2026-10-10T09:05:00',
      },
      'items': [
        {
          'nombre_producto': 'Chocoflan',
          'cantidad': 2,
          'precio_unitario': 150,
          'subtotal': 300,
          'tamano': 'grande',
        },
      ],
    };

Future<FakeApiClient> _montar(
  WidgetTester tester, {
  Order? pedido,
  Map<String, dynamic>? respuestas,
}) async {
  // Pantalla de celular (412×869 lógicos, como el Note 10+).
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final api = FakeApiClient(respuestas: {
    _detalle: _respuestaDetalle('listo'),
    ...?respuestas,
  });
  final inicial = pedido ?? _pedido();
  await tester.pumpApp(
    OrderDetailScreen(
      order: inicial,
      viewModel: OrderDetailViewModel(
        repo: PedidosRepositoryRemote(api: api),
        pedido: inicial,
      ),
    ),
    api: api,
  );
  await _asentar(tester);
  return api;
}

/// Deja correr las animaciones de la línea de tiempo (y el Lottie, que se
/// repite sin fin).
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Baja hasta «Cancelar pedido» (queda bajo el pliegue) y lo toca.
Future<void> _abrirCancelacion(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Cancelar pedido'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cancelar pedido'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cada estado tiene etiqueta corta e ícono propios del chip', () {
    final etiquetas = {
      for (final estado in OrderStatus.values)
        _pedido(estado: estado).estadoCorto,
    };
    expect(etiquetas, hasLength(OrderStatus.values.length));
    expect(_pedido(estado: OrderStatus.deliveryFailed).estadoCorto,
        'Entrega fallida');
    expect(
      Order(
        id: '1',
        numero: 'P',
        items: const [],
        total: 0,
        porConfirmar: true,
        createdAt: DateTime(2026),
      ).estadoCorto,
      'Por confirmar',
    );

    final iconos = OrderStatus.values.map(iconoEstadoPedido).toSet();
    // Completado y Entregado comparten el doble check.
    expect(iconos, hasLength(OrderStatus.values.length - 1));
  });

  group('OrderDetailScreen', () {
    testWidgets('muestra el pedido fresco: estado, línea, info y productos',
        (tester) async {
      await _montar(tester);

      expect(find.text('PIER-261010-0007'), findsWidgets);
      expect(find.text('10 Oct 2026'), findsOneWidget);
      expect(find.text('Listo'), findsWidgets); // chip y paso
      expect(find.text('Listo para recoger'), findsOneWidget);
      expect(find.text('Tu pedido está listo. Pasa a recogerlo'),
          findsOneWidget);
      expect(find.text('Recibido'), findsOneWidget);
      expect(find.text('10 Oct 2026 · 09:05 hrs'), findsOneWidget);
      expect(find.text('10:00 - 11:00'), findsOneWidget);
      expect(find.text('Sin nuez'), findsOneWidget);
      expect(find.text('Productos (1)'), findsOneWidget);
      expect(find.text(r'2× $150 c/u · grande'), findsOneWidget);
      expect(find.text(r'$300 MXN'), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsOneWidget);
    });

    testWidgets('domicilio en camino muestra al repartidor y no se cancela',
        (tester) async {
      await _montar(
        tester,
        pedido: _pedido(estado: OrderStatus.onTheWay, tipoEntrega: 'domicilio'),
        respuestas: {
          _detalle: _respuestaDetalle('en_camino', tipo: 'domicilio'),
        },
      );

      expect(find.textContaining('¡Tu pedido va en camino!'), findsOneWidget);
      expect(find.text('Asignado'), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsNothing);
    });

    testWidgets('un pedido cancelado avisa en lugar de la línea de tiempo',
        (tester) async {
      await _montar(
        tester,
        pedido: _pedido(estado: OrderStatus.cancelled),
        respuestas: {_detalle: _respuestaDetalle('cancelado')},
      );

      expect(find.text('Pedido cancelado'), findsOneWidget);
      expect(find.text('Recibido'), findsNothing);
    });

    testWidgets('cancelar pide confirmación; «Conservar» no llama al backend',
        (tester) async {
      final api = await _montar(tester);

      await _abrirCancelacion(tester);
      expect(find.text('¿Cancelar pedido?'), findsOneWidget);

      await tester.tap(find.text('Conservar pedido'));
      await tester.pumpAndSettle();

      expect(api.llamo(_cancelar), isFalse);
      expect(find.text('Cancelar pedido'), findsOneWidget);
    });

    testWidgets('cancelar con éxito avisa y quita el botón', (tester) async {
      final api = await _montar(tester);
      api
        ..responder(_cancelar,
            {'success': true, 'message': 'Pedido cancelado; reembolso en proceso'})
        ..responder(_detalle, _respuestaDetalle('cancelado'));

      await _abrirCancelacion(tester);
      await tester.tap(find.text('Sí, cancelar'));
      await _asentar(tester);

      expect(find.text('Pedido cancelado; reembolso en proceso'),
          findsOneWidget);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.text('Cancelado'), findsNWidgets(2)); // chip y estado
    });

    testWidgets('si el backend rechaza la cancelación, muestra el motivo',
        (tester) async {
      final api = await _montar(tester);
      api.fallar(_cancelar, 'Un repartidor ya tomó tu pedido');

      await _abrirCancelacion(tester);
      await tester.tap(find.text('Sí, cancelar'));
      await _asentar(tester);

      expect(find.text('Un repartidor ya tomó tu pedido'), findsOneWidget);
    });

    testWidgets('en la app crea su propio ViewModel, refresca al abrir y '
        'avisa si el estado cambió', (tester) async {
      final api = FakeApiClient(respuestas: {
        _detalle: _respuestaDetalle('asignado'),
      });
      final avisos = <Order>[];
      await tester.pumpApp(
        OrderDetailScreen(order: _pedido(), alCambiar: avisos.add),
        api: api,
      );
      await _asentar(tester);

      expect(api.llamo(_detalle, metodo: 'GET-Auth'), isTrue);
      expect(find.text('Productos (1)'), findsOneWidget);
      expect(avisos.single.status, OrderStatus.assigned);
    });
  });
}
