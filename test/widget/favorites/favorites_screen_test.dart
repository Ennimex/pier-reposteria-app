// test/widget/favorites/favorites_screen_test.dart — la vista de «Mis
// Favoritos» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/ui/favorites/view_model/favorites_view_model.dart';
import 'package:pier_reposteria/ui/favorites/widgets/favorites_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pantalla_apretada.dart';
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

/// Sin favoritos guardados; las categorías sugeridas llegan del backend.
FakeApiClient _sinFavoritos() => FakeApiClient(
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FavoritesScreen', () {
    testWidgets('sin favoritos muestra el estado vacío con las categorías',
        (tester) async {
      await _montar(tester, _sinFavoritos());

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

    // Regresión de #111: Mis Favoritos decía «agregado» aunque el alta
    // fallara.
    testWidgets('confirma «agregado» solo si el backend acepta el alta',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {
            'success': true,
            'favoritos': [
              {'id': 36, 'nombre': 'Fresa Matcha Bliss', 'categoria': 'Pasteles'},
            ],
          },
          ApiConstants.login: {
            'success': true,
            'token': 'jwt',
            'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
          },
        },
      );
      await _montar(tester, api);
      await tester.iniciarSesion(find.byType(FavoritesScreen));

      api.fallar(ApiConstants.carrito, 'No hay stock suficiente');
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.textContaining('agregado'), findsNothing);
      expect(find.text('No hay stock suficiente'), findsOneWidget);

      api.responder(ApiConstants.carrito, {'success': true});
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.text('Fresa Matcha Bliss agregado al carrito'), findsOneWidget);
    }, tags: 'regresion');
  });

  // Regresión de #285: los estados vacíos medían justo lo que quedaba de
  // pantalla; si no cabían se desbordaban y lo de abajo quedaba cortado.
  group('Los estados vacíos de Favoritos caben en una pantalla apretada '
      '(#285)', () {
    for (final apreton in Apreton.values) {
      testWidgets(
          'sin favoritos, «Ver Menú» y las categorías se alcanzan '
          '${apreton.descripcion}', (tester) async {
        await _montar(tester, _sinFavoritos());
        await tester.apretar(apreton);

        await tester.alcanzar(find.text('Ver Menú'));
        await tester.alcanzar(find.text('Explora por categoría'));
      }, tags: 'regresion');
    }

    // Sin coincidencias solo hay un ícono y un renglón: deja de caber con el
    // teclado abierto, que es cuando se está buscando.
    testWidgets(
        'una búsqueda sin coincidencias se alcanza con el teclado abierto',
        (tester) async {
      await _montar(
        tester,
        FakeApiClient(
          respuestas: {
            ApiConstants.favoritos: {
              'success': true,
              'favoritos': [
                {'id': 40, 'nombre': 'Pay de queso', 'categoria': 'Pays'},
              ],
            },
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'brownie');
      await tester.apretar(Apreton.tecladoAbierto);

      await tester.alcanzar(find.text('Sin resultados para "brownie"'));
    }, tags: 'regresion');
  });
}
