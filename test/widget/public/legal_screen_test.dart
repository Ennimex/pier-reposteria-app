// test/widget/public/legal_screen_test.dart — la vista de «Marco Legal» pinta
// lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/ui/public/view_model/legal_view_model.dart';
import 'package:pier_pasteleria/ui/public/widgets/legal_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _endpoint = ApiConstants.configuracionSeccion('legales');

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      LegalScreen(
        viewModel: LegalViewModel(repo: ConfiguracionRepositoryRemote(api: api)),
      ),
      api: api,
    );

void main() {
  group('LegalScreen', () {
    testWidgets('pinta el texto del panel y cambia de pestaña',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {
              'privacidad': 'Cuidamos tus datos. Nunca los vendemos.',
              'terminos': 'Al comprar aceptas.',
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Cuidamos tus datos.'), findsOneWidget);
      expect(find.text('Nunca los vendemos.'), findsOneWidget);
      expect(find.text('Responsable del Tratamiento'), findsNothing);

      await tester.tap(find.text('Términos'));
      await tester.pumpAndSettle();

      expect(find.text('Al comprar aceptas.'), findsOneWidget);
    });

    testWidgets('si el backend falla muestra las secciones por defecto',
        (tester) async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sin conexión');
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Responsable del Tratamiento'), findsOneWidget);
    });
  });
}
