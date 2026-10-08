import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

import '../test/fakes/fake_api_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke tests sin backend', () {
    late FakeApiClient api;

    setUp(() {
      api = FakeApiClient()
        ..responder(ApiConstants.login, {
          'success': false,
          'message': 'Credenciales inválidas',
        })
        ..responder(ApiConstants.productos, {
          'success': true,
          'productos': <Map<String, dynamic>>[],
        })
        ..responder(ApiConstants.promocionesActivas, {
          'success': true,
          'promociones': <Map<String, dynamic>>[],
        })
        ..responder(ApiConstants.categorias, {
          'success': true,
          'categorias': <Map<String, dynamic>>[],
        })
        ..responder(ApiConstants.filtros, {
          'success': true,
          'filtros': <String, dynamic>{},
        })
        ..responder(ApiConstants.configuracionSeccion('personalizacion'), {
          'success': true,
          'config': <String, dynamic>{},
        });
    });

    testWidgets('el login procesa credenciales inválidas con el fake', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(auth: AuthRepository(api: api)),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  TemaProvider(repo: ConfiguracionRepository(api: api)),
            ),
          ],
          child: const MyApp(initialLocation: AppRoutes.login),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'cliente@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'incorrecta');
      await tester.ensureVisible(find.text('Iniciar Sesión'));
      await tester.tap(find.text('Iniciar Sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(api.llamo(ApiConstants.login, metodo: 'POST'), isTrue);
    });

    testWidgets('el catálogo obtiene datos usando repositorios fake', (
      tester,
    ) async {
      final productosRepo = ProductosRepository(api: api);
      final favoritosRepo = FavoritosRepository(api: api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(auth: AuthRepository(api: api)),
            ),
            ChangeNotifierProvider(
              create: (_) => CartProvider(repo: CarritoRepository(api: api)),
            ),
            ChangeNotifierProvider(
              create: (_) => ProductProvider(repo: productosRepo),
            ),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
            ChangeNotifierProvider(
              create: (_) =>
                  TemaProvider(repo: ConfiguracionRepository(api: api)),
            ),
          ],
          child: MaterialApp(
            home: ProductsScreen(
              productosRepository: productosRepo,
              favoritosRepository: favoritosRepo,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(api.llamo(ApiConstants.productos), isTrue);
      expect(api.llamo(ApiConstants.categorias), isTrue);
      expect(api.llamo(ApiConstants.filtros), isTrue);
    });
  });
}
