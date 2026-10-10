// test/app_widget_test.dart — pruebas de widget (sin red, con FakeApiClient) de
// los puntos de entrada que el PR #77 hizo inyectables: MyApp.initialLocation,
// AppRoutes.router(initialLocation:) y ProductsScreen con sus dependencias. Viven
// en test/ para que entren en el lcov que lee SonarCloud.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/verify_email_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_api_client.dart';
import 'helpers/pump_app.dart';

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

void main() {
  group('MyApp', () {
    testWidgets('arranca en initialLocation y procesa un login inválido',
        (tester) async {
      final api = _apiConCatalogoVacio();

      await tester.pumpWidget(
        MultiProvider(
          providers: dependencias(api),
          child: const MyApp(initialLocation: AppRoutes.login),
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

    testWidgets('un login correcto abre la sesión y sale del login',
        (tester) async {
      final api = _apiConCatalogoVacio()
        ..responder(ApiConstants.login, {
          'success': true,
          'token': 'jwt',
          'user': {'id': 9, 'nombre': 'Ana', 'rol': 'cliente'},
        });
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), 'cliente@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'pastel123');
      await tester.ensureVisible(find.text('Iniciar Sesión'));
      await tester.tap(find.text('Iniciar Sesión'));
      // El inicio tiene animaciones continuas: se avanza el reloj a mano.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final contexto = tester.element(find.byType(MyApp));
      expect(contexto.read<AuthProvider>().isAuthenticated, isTrue);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('un registro correcto pasa a verificar el correo',
        (tester) async {
      final api = _apiConCatalogoVacio()
        ..responder(ApiConstants.register, {'success': true});
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.registro);
      await tester.pumpAndSettle();

      final datos = [
        'Ana', 'López', 'ana@example.com', '7711234567', 'pastel123',
        'pastel123', //
      ];
      for (var i = 0; i < datos.length; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), datos[i]);
      }
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.text('Registrarse'));
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
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
          providers: dependencias(api),
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
    testWidgets('pide catálogo, categorías y filtros al repositorio inyectado',
        (tester) async {
      final api = _apiConCatalogoVacio();

      await tester.pumpWidget(
        MultiProvider(
          providers: dependencias(api),
          child: const MaterialApp(home: ProductsScreen()),
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
