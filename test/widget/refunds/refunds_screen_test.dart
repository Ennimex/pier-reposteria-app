// test/widget/refunds/refunds_screen_test.dart — la vista de «Reembolsos»
// pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_pasteleria/ui/refunds/view_model/refunds_view_model.dart';
import 'package:pier_pasteleria/ui/refunds/widgets/refunds_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    RefundsScreen(
      viewModel: RefundsViewModel(
        reembolsosRepo: ReembolsosRepositoryRemote(api: api),
        pedidosRepo: PedidosRepositoryRemote(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RefundsScreen', () {
    testWidgets('sin solicitudes muestra el estado vacío', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misReembolsos: {
            'success': true,
            'reembolsos': <Object>[],
          },
          ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
        },
      );
      await _montar(tester, api);

      expect(find.text('Sin solicitudes'), findsOneWidget);
    });

    testWidgets('pinta la solicitud con su estado, monto y respuesta',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misReembolsos: {
            'success': true,
            'reembolsos': [
              {
                'id': 3,
                'pedido_numero': 'PIER-9',
                'monto': '640',
                'motivo': 'Producto dañado',
                'estado': 'procesado',
                'respuesta_admin': 'Ya se devolvió a tu tarjeta',
                'created_at': '2026-10-01T18:00:00',
              },
            ],
          },
          ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
        },
      );
      await _montar(tester, api);

      expect(find.text('Pedido #PIER-9'), findsOneWidget);
      expect(find.text('01 Oct, 2026'), findsOneWidget);
      expect(find.text('Procesado'), findsOneWidget);
      expect(find.text('Producto dañado'), findsOneWidget);
      expect(find.text(r'$640.00'), findsOneWidget);
      expect(find.text('Ya se devolvió a tu tarjeta'), findsOneWidget);
    });

    testWidgets('el formulario ya trae el primer pedido completado',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misReembolsos: {
            'success': true,
            'reembolsos': <Object>[],
          },
          ApiConstants.misPedidos: {
            'success': true,
            'pedidos': [
              {'id': 10, 'numero': 'PIER-10', 'estado': 'entregado', 'total': '300'},
              {'id': 9, 'numero': 'PIER-9', 'estado': 'completado', 'total': '640'},
            ],
          },
        },
      );
      await _montar(tester, api);

      await tester.tap(find.text('Nueva Solicitud').first);
      await tester.pumpAndSettle();

      expect(find.text(r'#PIER-9 — $640.00'), findsOneWidget);
      expect(find.textContaining('PIER-10'), findsNothing);
    });
  });
}
