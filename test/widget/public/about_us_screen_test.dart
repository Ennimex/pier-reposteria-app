// test/widget/public/about_us_screen_test.dart — la vista de «Nosotros» pinta
// lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/ui/public/view_model/about_us_view_model.dart';
import 'package:pier_pasteleria/ui/public/widgets/about_us_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _endpoint = ApiConstants.configuracionSeccion('nosotros');

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      AboutUsScreen(
        viewModel: AboutUsViewModel(repo: ConfiguracionRepository(api: api)),
      ),
      api: api,
    );

void main() {
  group('AboutUsScreen', () {
    testWidgets('pinta lo capturado en el panel', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {
              'historia': {'titulo': 'Desde 2015'},
              'mision': 'Endulzar Huejutla',
              'valores': ['Calidad suprema'],
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Desde 2015'), findsOneWidget);
      expect(find.text('Endulzar Huejutla'), findsOneWidget);
      expect(find.text('Calidad suprema', skipOffstage: false), findsOneWidget);
      expect(find.text('Ingredientes Frescos', skipOffstage: false),
          findsNothing);
    });

    testWidgets('si el backend falla muestra los textos por defecto',
        (tester) async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sin conexión');
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Nuestra Historia'), findsOneWidget);
      expect(find.text('Ingredientes Frescos', skipOffstage: false),
          findsOneWidget);
    });
  });
}
