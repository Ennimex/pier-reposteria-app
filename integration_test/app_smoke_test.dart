import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_reposteria/app.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

import '../test/fakes/fake_api_client.dart';
import 'ayudas/esperas.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  toquesPerdidosFallan();

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
          providers: dependencias(api),
          child: const MyApp(initialLocation: AppRoutes.login),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'cliente@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'incorrecta');
      // En un celular real de pantalla chica (Galaxy A10 en Test Lab, #75) el
      // teclado tapa el botón: se cierra y se espera a que se vaya de verdad
      // (el cierre es nativo y pumpAndSettle no lo espera; con el teclado
      // aún arriba el aviso de error no cabía, PR #214 y #215).
      await cerrarTeclado(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Iniciar Sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar Sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(api.llamo(ApiConstants.login, metodo: 'POST'), isTrue);
    });

    testWidgets('el catálogo obtiene datos usando repositorios fake', (
      tester,
    ) async {
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
