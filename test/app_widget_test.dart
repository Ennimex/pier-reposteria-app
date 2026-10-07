// test/app_widget_test.dart — pruebas de widget (sin red, con FakeApiClient) de
// los puntos de entrada que el PR #77 hizo inyectables: MyApp.initialLocation,
// AppRoutes.router(initialLocation:) y ProductsScreen con repositorios. Viven
// en test/ para que entren en el lcov que lee SonarCloud.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

import 'fakes/fake_api_client.dart';

FakeApiClient _apiConCatalogoVacio() => FakeApiClient()
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

List<ChangeNotifierProvider> _providers(FakeApiClient api) => [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(auth: AuthRepository(api: api)),
      ),
      ChangeNotifierProvider<TemaProvider>(
        create: (_) => TemaProvider(repo: ConfiguracionRepository(api: api)),
      ),
      ChangeNotifierProvider<CartProvider>(
        create: (_) => CartProvider(repo: CarritoRepository(api: api)),
      ),
      ChangeNotifierProvider<ProductProvider>(
        create: (_) => ProductProvider(repo: ProductosRepository(api: api)),
      ),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
    ];

void main() {
  group('MyApp', () {
    testWidgets('arranca en initialLocation y procesa un login inválido',
        (tester) async {
      final api = _apiConCatalogoVacio();

      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(api),
          child: MyApp(initialLocation: AppRoutes.login),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'cliente@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'incorrecta');
      await tester.ensureVisible(find.text('Iniciar Sesión'));
      await tester.tap(find.text('Iniciar Sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(api.llamo(ApiConstants.login, metodo: 'POST'), isTrue);
    });
  });

  group('AppRoutes.router', () {
    Future<GoRouter> montar(
      WidgetTester tester,
      FakeApiClient api,
      String initialLocation,
    ) async {
      late GoRouter router;
      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(api),
          child: Builder(builder: (context) {
            router = AppRoutes.router(
              context,
              initialLocation: initialLocation,
            );
            return MaterialApp.router(routerConfig: router);
          }),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('respeta initialLocation en una ruta pública', (tester) async {
      final router = await montar(tester, _apiConCatalogoVacio(),
          AppRoutes.login);

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.login,
      );
      expect(find.text('Iniciar Sesión'), findsWidgets);
    });

    testWidgets('una ruta protegida sin sesión redirige al login',
        (tester) async {
      final router = await montar(tester, _apiConCatalogoVacio(),
          AppRoutes.checkout);

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.login,
      );
    });
  });

  group('ProductsScreen', () {
    testWidgets('usa los repositorios inyectados en lugar de la red',
        (tester) async {
      final api = _apiConCatalogoVacio();

      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(api),
          child: MaterialApp(
            home: ProductsScreen(
              productosRepository: ProductosRepository(api: api),
              favoritosRepository: FavoritosRepository(api: api),
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
