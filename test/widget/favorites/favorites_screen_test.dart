// test/widget/favorites/favorites_screen_test.dart — la vista de «Mis
// Favoritos» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:pier_pasteleria/ui/favorites/view_model/favorites_view_model.dart';
import 'package:pier_pasteleria/ui/favorites/widgets/favorites_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  // Pantalla de celular (412×869 lógicos, como el Note 10+): el estado vacío
  // no cabe en los 800×600 por defecto.
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(
    FavoritesScreen(
      viewModel: FavoritesViewModel(
        favoritosRepo: FavoritosRepositoryRemote(api: api),
        productosRepo: ProductosRepositoryRemote(api: api),
        registrarInteres: (_) {},
      ),
    ),
    api: api,
  );
  // Deja correr las animaciones de entrada de las tarjetas.
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FavoritesScreen', () {
    testWidgets('sin favoritos muestra el estado vacío con las categorías',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {'success': true, 'favoritos': <Object>[]},
          ApiConstants.categorias: {
            'success': true,
            'categorias': [
              {'nombre': 'Postres'},
              {'nombre': 'Panes'},
            ],
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('Sin favoritos aún'), findsOneWidget);
      expect(find.text('Postres'), findsOneWidget);
      expect(find.text('Panes'), findsOneWidget);
    });

    testWidgets('pinta el contador y filtra con la búsqueda', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {
            'success': true,
            'favoritos': [
              {'id': 36, 'nombre': 'Fresa Matcha Bliss', 'categoria': 'Pasteles'},
              {'id': 40, 'nombre': 'Pay de queso', 'categoria': 'Pays'},
            ],
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('2 productos guardados'), findsOneWidget);
      expect(find.text('Fresa Matcha Bliss'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'pay');
      await tester.pumpAndSettle();

      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('Fresa Matcha Bliss'), findsNothing);
      expect(find.text('Pay de queso'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'brownie');
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados para "brownie"'), findsOneWidget);
    });
  });
}
