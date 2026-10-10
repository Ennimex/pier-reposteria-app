// test/widget/orders/orders_screen_test.dart — la vista de «Mis Pedidos»
// pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/orders/view_model/orders_view_model.dart';
import 'package:pier_pasteleria/ui/orders/widgets/orders_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      OrdersScreen(
        viewModel: OrdersViewModel(repo: PedidosRepository(api: api)),
      ),
      api: api,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OrdersScreen', () {
    testWidgets('sin sesión invita a iniciar sesión y no pide pedidos',
        (tester) async {
      final api = FakeApiClient();
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Inicia sesión'), findsWidgets);
      expect(api.llamo(ApiConstants.misPedidos, metodo: 'GET-Auth'), isFalse);
    });

    testWidgets('con sesión, al volver a la pestaña muestra los activos',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.login: {
            'success': true,
            'token': 'jwt',
            'user': {'id': 1, 'nombre': 'Ana', 'rol': 'cliente'},
          },
          ApiConstants.misPedidos: {
            'success': true,
            'pedidos': [
              {'id': 1, 'numero': 'PIER-ACTIVO', 'estado': 'pendiente'},
              {'id': 2, 'numero': 'PIER-VIEJO', 'estado': 'entregado'},
            ],
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      final contexto = tester.element(find.byType(OrdersScreen));
      await contexto.read<AuthProvider>().login('ana@pier.mx', 'x');
      contexto.read<NavigationProvider>().setSelectedIndex(3);
      await tester.pump();
      await tester.pump();

      expect(find.text('PIER-ACTIVO'), findsOneWidget);
      expect(find.text('PIER-VIEJO'), findsNothing);
      expect(find.text('1 activo'), findsOneWidget);

      // Deja terminar las animaciones de entrada (flutter_animate) de las
      // tarjetas para que no queden timers pendientes.
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
