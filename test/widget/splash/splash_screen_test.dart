// test/widget/splash/splash_screen_test.dart — el splash espera su mínimo,
// navega a su destino y, cuando ese destino ya quedó a la vista, avisa que
// el arranque terminó (#353: Sentry mide hasta ahí, no solo el primer
// cuadro).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/splash/widgets/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

/// Monta el splash en un router de dos rutas: la suya y la del destino de un
/// visitante sin sesión (AppRoutes.main), con un texto en lugar del Inicio.
/// [alVerseElDestino] toma el lugar del aviso a Sentry.
Future<void> _montar(
  WidgetTester tester, {
  required Future<void> Function() alVerseElDestino,
}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => SplashScreen(alVerseElDestino: alVerseElDestino),
      ),
      GoRoute(
        path: AppRoutes.main,
        builder: (_, _) => const Scaffold(body: Text('destino')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: dependencias(FakeApiClient()),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

/// Desmonta el árbol para que el tema de temporada cancele su temporizador.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('SplashScreen', () {
    testWidgets('avisa una sola vez, cuando el destino ya quedó a la vista '
        '(#353)', (tester) async {
      var avisos = 0;
      await _montar(tester, alVerseElDestino: () async => avisos++);

      // Durante la espera mínima sigue el splash y nadie avisa.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(avisos, 0);

      // Pasa la espera mínima: el splash navega, pero mientras el destino va
      // entrando (el splash sigue debajo) todavía no avisa.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('destino'), findsOneWidget);
      expect(find.byType(SplashScreen, skipOffstage: false), findsOneWidget);
      expect(avisos, 0);

      // El destino termina de entrar y el splash se desmonta: avisa.
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen, skipOffstage: false), findsNothing);
      expect(find.text('destino'), findsOneWidget);
      expect(avisos, 1);

      await _desmontar(tester);
      expect(avisos, 1);
    });

    testWidgets('si se desmonta antes de navegar, no avisa', (tester) async {
      var avisos = 0;
      await _montar(tester, alVerseElDestino: () async => avisos++);

      await _desmontar(tester);
      // La espera mínima termina con el splash ya desmontado: no navega.
      await tester.pump(const Duration(seconds: 2));

      expect(avisos, 0);
    });
  });
}
