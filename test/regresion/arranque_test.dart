// test/regresion/arranque_test.dart — #198: lib/main.dart esperaba
// GET /pagos/config (la llave pública de Stripe) antes de runApp. Con el
// servidor dormido, Flutter no dibujaba la primera pantalla y Android marcaba
// la app como congelada si el cliente tocaba la pantalla. Aquí el servidor
// nunca contesta /pagos/config: la primera pantalla tiene que dibujarse igual
// y el arranque no debe pedir esa ruta.
@Tags(['regresion'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/main.dart' as app;
import 'package:pier_reposteria/ui/splash/widgets/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      '#198: la primera pantalla se dibuja aunque /pagos/config no responda',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final rutasPedidas = <String>[];
    final nuncaResponde = Completer<http.Response>();
    // Cualquier otra ruta falla rápido, como un servidor caído.
    final servidor = MockClient((peticion) {
      rutasPedidas.add(peticion.url.path);
      if (peticion.url.path.endsWith(ApiConstants.stripeConfig)) {
        return nuncaResponde.future;
      }
      return Future.value(http.Response('{"success":false}', 503));
    });

    await http.runWithClient(() async {
      // Sin esperar a main(): con el defecto, se quedaba esperando la
      // respuesta y nunca llegaba a runApp.
      unawaited(app.main());
      await tester.pump();
    }, () => servidor);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Pier Repostería'), findsOneWidget);
    expect(
      rutasPedidas.where((ruta) => ruta.endsWith(ApiConstants.stripeConfig)),
      isEmpty,
    );
    expect(tester.takeException(), isNull);

    // Deja que el splash termine y desmonta, para no dejar timers vivos.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
