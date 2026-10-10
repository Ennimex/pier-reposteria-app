// test/widget/public/faq_screen_test.dart — la vista de «Preguntas
// Frecuentes» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/ui/public/view_model/faq_view_model.dart';
import 'package:pier_pasteleria/ui/public/widgets/faq_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _endpoint = ApiConstants.configuracionSeccion('faq');

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      FAQScreen(
        viewModel: FaqViewModel(repo: ConfiguracionRepositoryRemote(api: api)),
      ),
      api: api,
    );

void main() {
  group('FAQScreen', () {
    testWidgets('pinta las preguntas del panel y filtra por categoría',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {
              'preguntas': [
                {
                  'categoria': 'Envíos',
                  'pregunta': '¿Llegan a Tehuetlán?',
                  'respuesta': 'Sí',
                },
                {
                  'categoria': 'Pagos',
                  'pregunta': '¿Aceptan vales?',
                  'respuesta': 'No',
                },
              ],
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('¿Llegan a Tehuetlán?'), findsOneWidget);
      expect(find.text('¿Aceptan vales?'), findsOneWidget);
      expect(find.text('¿Dónde están ubicados?'), findsNothing);

      await tester.tap(find.text('Envíos'));
      await tester.pump();

      expect(find.text('¿Llegan a Tehuetlán?'), findsOneWidget);
      expect(find.text('¿Aceptan vales?'), findsNothing);
    });

    testWidgets('si el backend falla muestra las preguntas por defecto',
        (tester) async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sin conexión');
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('¿Ofrecen servicio de entrega a domicilio?'),
          findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
    });
  });
}
