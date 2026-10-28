// test/widget/public/about_us_screen_test.dart — la vista de «Nosotros» pinta
// lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/ui/public/view_model/about_us_view_model.dart';
import 'package:pier_reposteria/ui/public/widgets/about_us_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _endpoint = ApiConstants.configuracionSeccion('nosotros');

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      AboutUsScreen(
        viewModel: AboutUsViewModel(repo: ConfiguracionRepositoryRemote(api: api)),
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

    testWidgets('pinta el recorrido con su foto cuando la tiene (#170)',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {
              'timeline': [
                {
                  'year': '2015',
                  'title': 'El inicio',
                  'description': 'Una cocina familiar',
                  'image': 'local:producto1.webp',
                },
                {'year': '2020', 'title': 'Primera sucursal'},
              ],
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Nuestro Recorrido', skipOffstage: false),
          findsOneWidget);
      for (final texto in [
        '2015',
        'El inicio',
        'Una cocina familiar',
        '2020',
        'Primera sucursal',
      ]) {
        expect(find.text(texto, skipOffstage: false), findsOneWidget);
      }
      // Solo la primera etapa trae foto.
      final fotos = tester
          .widgetList<Image>(find.byType(Image, skipOffstage: false))
          .where((i) => i.image is AssetImage)
          .map((i) => (i.image as AssetImage).assetName);
      expect(fotos, ['assets/images/sitio/producto1.webp']);
    });

    testWidgets('integrante con foto: foto redonda, nombre y puesto',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {
              'equipo': [
                {
                  'name': 'Pier',
                  'role': 'Fundadora',
                  'description': 'Repostera',
                  'emoji': '🧁',
                  'photo': 'local:producto3.jpg',
                },
              ],
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Conoce al Equipo', skipOffstage: false),
          findsOneWidget);
      expect(find.text('Pier', skipOffstage: false), findsOneWidget);
      expect(find.text('Fundadora', skipOffstage: false), findsOneWidget);
      final foto = find.descendant(
        of: find.byType(ClipOval, skipOffstage: false),
        matching: find.byType(Image, skipOffstage: false),
      );
      expect(foto, findsOneWidget);
      expect((tester.widget<Image>(foto).image as AssetImage).assetName,
          'assets/images/sitio/producto3.webp');
      // Con foto, el emoji no se ve.
      expect(find.text('🧁', skipOffstage: false), findsNothing);
    });

    testWidgets('integrante sin foto: su emoji (o su inicial)',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {
              'equipo': [
                {'name': 'Ana', 'role': 'Repostera', 'emoji': '🧁'},
                {'name': 'luis', 'role': 'Ventas'},
              ],
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('🧁', skipOffstage: false), findsOneWidget);
      expect(find.text('L', skipOffstage: false), findsOneWidget);
      expect(find.byType(ClipOval, skipOffstage: false), findsNothing);
    });

    testWidgets('sin equipo ni recorrido no aparecen sus secciones',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'config': {'equipo': <Object>[], 'mision': 'Endulzar'},
          },
        },
      );
      await _montar(tester, api);
      await tester.pump();

      expect(find.text('Endulzar'), findsOneWidget);
      expect(find.text('Conoce al Equipo', skipOffstage: false), findsNothing);
      expect(find.text('Nuestro Recorrido', skipOffstage: false),
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
