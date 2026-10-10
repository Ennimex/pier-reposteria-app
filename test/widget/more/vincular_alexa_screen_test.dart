// test/widget/more/vincular_alexa_screen_test.dart — la vista de «Vincular con
// Alexa» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_pasteleria/ui/more/view_model/vincular_alexa_view_model.dart';
import 'package:pier_pasteleria/ui/more/widgets/vincular_alexa_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      VincularAlexaScreen(
        viewModel: VincularAlexaViewModel(repo: CuentaRepositoryRemote(api: api)),
      ),
      api: api,
    );

Finder get _botonGenerar => find.text('Generar código de vinculación');

void main() {
  group('VincularAlexaScreen', () {
    testWidgets('al generar muestra el código y la cuenta regresiva',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.alexaGenerarCodigo: {
            'success': true,
            'codigo': '482913',
            'expira_en_segundos': 300,
          },
        },
      );
      await _montar(tester, api);

      await tester.tap(_botonGenerar);
      await tester.pump();

      expect(find.text('482913'), findsOneWidget);
      expect(find.textContaining('5:00', findRichText: true), findsOneWidget);
      expect(_botonGenerar, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('4:59', findRichText: true), findsOneWidget);
    });

    testWidgets('al expirar vuelve a mostrar el botón', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.alexaGenerarCodigo: {
            'success': true,
            'codigo': '482913',
            'expira_en_segundos': 2,
          },
        },
      );
      await _montar(tester, api);

      await tester.tap(_botonGenerar);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('482913'), findsNothing);
      expect(_botonGenerar, findsOneWidget);
    });

    testWidgets('si el backend falla muestra su mensaje', (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.alexaGenerarCodigo, 'Token expirado');
      await _montar(tester, api);

      await tester.tap(_botonGenerar);
      await tester.pump();

      expect(find.text('Token expirado'), findsOneWidget);
      expect(_botonGenerar, findsOneWidget);
    });

    testWidgets('mientras genera muestra «Generando...»', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.alexaGenerarCodigo: {
            'success': true,
            'codigo': '482913',
          },
        },
      )..demorar(ApiConstants.alexaGenerarCodigo, const Duration(seconds: 1));
      await _montar(tester, api);

      await tester.tap(_botonGenerar);
      await tester.pump();
      expect(find.text('Generando...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('482913'), findsOneWidget);
    });
  });
}
