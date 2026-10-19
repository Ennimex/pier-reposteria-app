// test/widget/more/profile_screen_test.dart — la vista de «Mi Perfil» pinta
// lo que expone su ViewModel (MVVM, Fase 3), sin red. La foto de un favorito
// vuela al detalle con su propio ámbito (Mis Favoritos usa la etiqueta de
// siempre: al regresar de ahí no se cruzan fotos).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/profile_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/profile_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_galeria.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    ProfileScreen(
      viewModel: ProfileViewModel(
        favoritosRepo: FavoritosRepositoryRemote(api: api),
        pedidosRepo: PedidosRepositoryRemote(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProfileScreen', () {
    testWidgets('sin datos muestra las dos secciones vacías', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {'success': true, 'favoritos': <Object>[]},
          ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
        },
      );
      await _montar(tester, api);

      expect(find.text('Sin favoritos aún'), findsOneWidget);
      expect(find.text('Sin pedidos aún'), findsOneWidget);
    });

    testWidgets('pinta el pedido con su estado legible y su resumen',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {'success': true, 'favoritos': <Object>[]},
          ApiConstants.misPedidos: {
            'success': true,
            'pedidos': [
              {
                'id': 9,
                'numero': 'PIER-9',
                'estado': 'en_preparacion',
                'total': '640',
                'items': [
                  {'nombre_producto': 'Fresa Matcha Bliss', 'cantidad': 2},
                  {'nombre_producto': 'Pay de queso', 'cantidad': 1},
                ],
              },
            ],
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('PIER-9'), findsOneWidget);
      expect(find.text('En preparación'), findsOneWidget);
      expect(find.text('2x Fresa Matcha..., 1x más'), findsOneWidget);
      expect(find.text(r'$640'), findsOneWidget);
    });

    testWidgets('la foto de un favorito vuela al detalle con el ámbito del '
        'perfil, no con la etiqueta de Mis Favoritos', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {
            'success': true,
            'favoritos': [
              {'id': 36, 'nombre': 'Fresa Matcha Bliss', 'categoria': 'Pasteles'},
            ],
          },
          ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
        },
      );
      await _montar(tester, api);
      await tester.pump(const Duration(seconds: 1));

      final heroe = tester.widget<Hero>(
        find.descendant(
          of: find.byType(FotoProductoHero),
          matching: find.byType(Hero),
        ),
      );
      expect(heroe.tag, FotoProductoHero.etiqueta('36', ambito: 'perfil'));
      expect(heroe.tag, isNot(FotoProductoHero.etiqueta('36')));

      await tester.tap(find.text('Fresa Matcha Bliss'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      final galeria = tester.widget<FotoProductoHero>(
        find.descendant(
          of: find.byType(DetalleGaleria),
          matching: find.byType(FotoProductoHero),
        ),
      );
      expect(galeria.ambito, 'perfil');
    });
  });
}
