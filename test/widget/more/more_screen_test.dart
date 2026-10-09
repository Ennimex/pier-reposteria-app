// test/widget/more/more_screen_test.dart — la pestaña «Más» pinta lo que
// expone su ViewModel (MVVM, Fase 3), sin red. Sin sesión guardada: invitado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/ui/more/view_model/more_view_model.dart';
import 'package:pier_pasteleria/ui/more/widgets/more_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(
    MoreScreen(
      viewModel: MoreViewModel(
        configRepo: ConfiguracionRepository(api: api),
        pedidosRepo: PedidosRepository(api: api),
        favoritosRepo: FavoritosRepository(api: api),
        resenasRepo: ResenasRepository(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MoreScreen (invitado)', () {
    testWidgets('pinta el contacto del backend y no muestra contadores',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.configuracionSeccion('contacto'): {
            'success': true,
            'config': {
              'telefono': '921 000 0000',
              'direccion': 'Av. Siempre Viva 742',
            },
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('Encuéntranos'), findsOneWidget);
      expect(find.textContaining('921 000 0000'), findsWidgets);
      expect(find.textContaining('Av. Siempre Viva 742'), findsWidgets);
      expect(find.text('Acceso requerido'), findsOneWidget);
      expect(find.text('Pedidos'), findsNothing);
      expect(api.llamo(ApiConstants.misPedidos), isFalse);
    });

    testWidgets('si el contacto falla usa los datos de BusinessInfo',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.configuracionSeccion('contacto'), 'Caído');
      await _montar(tester, api);

      expect(find.textContaining(BusinessInfo.telefono), findsWidgets);
    });
  });
}
