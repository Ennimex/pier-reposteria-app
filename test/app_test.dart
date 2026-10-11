// test/app_test.dart — prueba de arranque (#15): monta la app completa, con
// los 7 providers globales sobre FakeApiClient, y comprueba que el splash se
// pinta y luego navega sin excepciones.
//
// Ojo: tras el splash, las pantallas del shell todavía crean sus propios
// repositorios (se inyectan en las Fases 3 y 4 de MVVM). En flutter_test toda
// petición HTTP real recibe un 400 sin salir a la red, así que la segunda
// prueba equivale a «arrancar con el backend caído».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_screen.dart';
import 'package:pier_pasteleria/ui/splash/widgets/splash_screen.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_api_client.dart';
import 'helpers/pump_app.dart';

/// Deja correr la espera mínima del splash (1.8 s) y desmonta el árbol para
/// que las pantallas cancelen sus timers antes de que termine la prueba.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  // Vacía los timers de duración cero que flutter_animate deja en el inicio.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Arranque de la app', () {
    testWidgets('pinta el splash sin excepciones', (tester) async {
      await tester.pumpMyApp(api: FakeApiClient());

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Pier Repostería'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _desmontar(tester);
    });

    testWidgets('sin sesión y sin backend, del splash pasa al inicio',
        (tester) async {
      await tester.pumpMyApp(api: FakeApiClient());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _desmontar(tester);
    });
  });

  group('pumpApp', () {
    testWidgets('expone los 7 providers globales al widget montado',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpApp(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }));

      expect(ctx.read<AuthProvider>(), isNotNull);
      expect(ctx.read<CartProvider>(), isNotNull);
      expect(ctx.read<ProductProvider>(), isNotNull);
      expect(ctx.read<NavigationProvider>(), isNotNull);
      expect(ctx.read<NotificationProvider>(), isNotNull);
      expect(ctx.read<EntregasProvider>(), isNotNull);
      expect(ctx.read<TemaProvider>(), isNotNull);
    });

    testWidgets('los providers hablan con el FakeApiClient recibido',
        (tester) async {
      final api = FakeApiClient();
      late BuildContext ctx;
      await tester.pumpApp(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }), api: api);

      await ctx.read<ProductProvider>().cargarProductos();

      expect(api.llamadas, isNotEmpty);
    });
  });
}
