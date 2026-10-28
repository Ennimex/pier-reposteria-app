// test/widget/pedidos_personal/pedidos_del_dia_screen_test.dart — «Pedidos
// del día» (#137) sin red: quién la abre desde la agenda, las secciones con
// su hora, confirmar marcar listo, el motivo al cancelar, asignar
// repartidor, aprobar y el error de carga.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/gestion_pedidos_repository_remote.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_screen.dart';
import 'package:pier_reposteria/ui/pedidos_personal/view_model/pedidos_del_dia_view_model.dart';
import 'package:pier_reposteria/ui/pedidos_personal/widgets/pedidos_del_dia_screen.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../fakes/pedidos_del_dia_json.dart';
import '../../helpers/montar_comandas.dart';

FakeApiClient _backend() => FakeApiClient()
  ..responder(ApiConstants.agendaComandas('proximas'), agendaJson([]))
  ..responder(pedidosAbiertos, abiertosJson)
  ..responder(ApiConstants.repartidores, repartidoresJson);

Future<void> _pantalla(WidgetTester tester, FakeApiClient api) =>
    montarComandas(
      tester,
      api,
      pantalla: PedidosDelDiaScreen(
        viewModel: PedidosDelDiaViewModel(
          repo: GestionPedidosRepositoryRemote(api: api),
          ahora: ahoraPedidos,
        ),
      ),
      rol: 'empleado',
    );

/// El botón [texto] de la tarjeta del pedido [id].
Finder _boton(String id, String texto) => find.descendant(
      of: find.byKey(ValueKey(id)),
      matching: find.text(texto),
    );

void main() {
  group('PedidosDelDiaScreen', () {
    testWidgets('el mostrador la abre desde la agenda; hornos no',
        (tester) async {
      final api = _backend();
      await montarComandas(tester, api,
          pantalla: const AgendaComandasScreen(), rol: 'gerencia');

      await tester.tap(find.byTooltip('Pedidos del día'));
      await tester.pumpAndSettle();

      expect(find.byType(PedidosDelDiaScreen), findsOneWidget);
      expect(api.llamo(pedidosAbiertos), isTrue);
    });

    testWidgets('producción no ve los pedidos', (tester) async {
      await montarComandas(tester, _backend(),
          pantalla: const AgendaComandasScreen());
      expect(find.byTooltip('Pedidos del día'), findsNothing);
    });

    testWidgets('secciones con su hora; los de otros días se ocultan',
        (tester) async {
      await _pantalla(tester, _backend());

      for (final seccion in [
        'Por confirmar (1)',
        'Por preparar (2)',
        'Listos para recoger (1)',
        'Listos para enviar (1)',
        'En reparto (1)',
        'Entrega fallida (1)',
      ]) {
        expect(find.text(seccion), findsOneWidget);
      }
      expect(find.text('Vencido · 11 Oct 16:00'), findsOneWidget);
      expect(find.text('1 pedido de otro día no se muestra'), findsOneWidget);
      expect(find.text('PIER-7'), findsNothing);
      expect(find.text('Repartidor: Luis P.'), findsOneWidget);

      await tester.tap(find.text('Todos los abiertos'));
      await tester.pumpAndSettle();
      expect(find.text('PIER-7'), findsOneWidget);
      expect(find.text('Por preparar (3)'), findsOneWidget);
    });

    testWidgets('marcar listo pide confirmación y avisa el resultado',
        (tester) async {
      final api = _backend()
        ..responder(ApiConstants.pedidoEstado('1'), {
          'success': true,
          'message': 'Estado actualizado',
        });
      await _pantalla(tester, api);

      await tester.tap(_boton('1', 'Marcar listo'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar como listo'), findsOneWidget);
      expect(find.textContaining('ya puede pasar por su pedido'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Marcar listo').last);
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.pedidoEstado('1'))!.body,
          {'estado': 'listo'});
      expect(find.text('Estado actualizado'), findsOneWidget);
    });

    testWidgets('volver no cambia nada', (tester) async {
      final api = _backend();
      await _pantalla(tester, api);

      await tester.tap(_boton('3', 'Entregar al cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(api.llamo(ApiConstants.pedidoEstado('3')), isFalse);
    });

    testWidgets('cancelar exige el motivo', (tester) async {
      final api = _backend()
        ..responder(ApiConstants.pedidoEstado('1'), {'success': true});
      await _pantalla(tester, api);

      await tester.tap(_boton('1', 'Cancelar pedido'));
      await tester.pumpAndSettle();
      expect(find.textContaining('se generará la solicitud de reembolso'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'No');
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el motivo (mínimo 5 caracteres).'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.pedidoEstado('1')), isFalse);

      await tester.enterText(find.byType(TextField), 'El cliente no vino');
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar pedido'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.pedidoEstado('1'))!.body, {
        'estado': 'cancelado',
        'nota_cancelacion': 'El cliente no vino',
      });
      expect(find.text('Pedido actualizado'), findsOneWidget);
    });

    testWidgets('asignar: elige un repartidor disponible', (tester) async {
      final api = _backend()
        ..responder(ApiConstants.asignarEntrega, {
          'success': true,
          'message': 'Pedido #4 asignado a Luis Pérez',
        });
      await _pantalla(tester, api);

      await tester.tap(_boton('4', 'Asignar repartidor'));
      await tester.pumpAndSettle();
      expect(find.text('2 entregas activas'), findsOneWidget);
      expect(find.text('No disponible'), findsOneWidget);
      final rosa = tester.widget<RadioListTile<int>>(
          find.widgetWithText(RadioListTile<int>, 'Rosa'));
      expect(rosa.enabled, isFalse);

      await tester.tap(find.text('Luis Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.asignarEntrega)!.body,
          {'pedido_id': 4, 'repartidor_id': 21});
      expect(find.text('Pedido #4 asignado a Luis Pérez'), findsOneWidget);
    });

    testWidgets('aprobar es directo y un rechazo del backend se avisa',
        (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.pedidoAprobar('2'),
            'Este pedido no está por confirmar');
      await _pantalla(tester, api);

      await tester.tap(_boton('2', 'Aprobar'));
      await tester.pumpAndSettle();

      expect(find.text('Este pedido no está por confirmar'), findsOneWidget);
    });

    testWidgets('si no cargan ofrece reintentar', (tester) async {
      final api = _backend()..fallar(pedidosAbiertos, 'Sin conexión');
      await _pantalla(tester, api);

      expect(find.text('Sin conexión'), findsOneWidget);
      api.responder(pedidosAbiertos, abiertosJson);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('PIER-1'), findsOneWidget);
    });
  });
}
