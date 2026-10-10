// test/widget/more/quejas_screen_test.dart — la vista de «Mis Quejas» pinta
// lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository_remote.dart';
import 'package:pier_pasteleria/ui/more/view_model/quejas_view_model.dart';
import 'package:pier_pasteleria/ui/more/widgets/quejas_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  // Pantalla de celular: la hoja del formulario no cabe en 800×600.
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(
    QuejasScreen(
      viewModel: QuejasViewModel(
        quejasRepo: QuejasRepositoryRemote(api: api),
        pedidosRepo: PedidosRepositoryRemote(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
}

final Map<String, dynamic> _sinPedidos = {
  ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('QuejasScreen', () {
    testWidgets('sin quejas muestra el estado vacío', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ..._sinPedidos,
          ApiConstants.misQuejas: {'success': true, 'quejas': <Object>[]},
        },
      );
      await _montar(tester, api);

      expect(find.text('Sin quejas registradas'), findsOneWidget);
    });

    testWidgets('pinta la queja y al abrirla muestra detalle y respuesta',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misPedidos: {
            'success': true,
            'pedidos': [
              {'id': 9, 'numero': 'PIER-9', 'estado': 'entregado', 'total': '640'},
            ],
          },
          ApiConstants.misQuejas: {
            'success': true,
            'quejas': [
              {
                'id': 7,
                'ticket': 'QJ-0007',
                'pedido_id': 9,
                'tipo': 'sugerencia',
                'categoria': 'servicio',
                'asunto': 'Más horarios',
                'descripcion': 'Abran los domingos',
                'estado': 'resuelto',
                'respuesta': 'Desde noviembre abrimos',
                'created_at': '2026-10-02T15:00:00',
              },
            ],
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('1 registro'), findsOneWidget);
      expect(find.text('QJ-0007'), findsOneWidget);
      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.text('Sugerencia'), findsOneWidget);
      expect(find.text('Servicio'), findsOneWidget);
      expect(find.text('2 Oct, 2026'), findsOneWidget);
      expect(find.text('Abran los domingos'), findsNothing);

      await tester.tap(find.text('Más horarios'));
      await tester.pump();

      expect(find.text('Abran los domingos'), findsOneWidget);
      expect(find.text('Pedido #PIER-9'), findsOneWidget);
      expect(find.text('Desde noviembre abrimos'), findsOneWidget);
    });

    testWidgets('la hoja Nueva avisa si faltan campos', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ..._sinPedidos,
          ApiConstants.misQuejas: {'success': true, 'quejas': <Object>[]},
        },
      );
      await _montar(tester, api);

      await tester.tap(find.text('Nueva'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva queja o sugerencia'), findsOneWidget);

      await tester.tap(find.text('Enviar queja'));
      await tester.pump();

      expect(find.text('Completa todos los campos obligatorios'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.crearQueja), isFalse);
    });
  });
}
