// test/helpers/pump_app.dart — helper para pruebas de widget (#15).
//
// Monta widgets con el mismo árbol de dependencias que main.dart
// (lib/config/dependencies.dart: repositorios + providers globales), todo
// sobre un FakeApiClient (sin red), y simula SharedPreferences vacío (sin
// sesión guardada).
//
//   await tester.pumpApp(const LoginScreen());          // pantalla suelta
//   await tester.pumpApp(const LoginScreen(), api: api); // con respuestas
//   await tester.pumpMyApp(initialLocation: AppRoutes.login); // app completa
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api_client.dart';

extension PumpApp on WidgetTester {
  /// Monta [widget] dentro de un MaterialApp con los providers globales.
  Future<void> pumpApp(Widget widget, {FakeApiClient? api}) async {
    SharedPreferences.setMockInitialValues({});
    await pumpWidget(
      MultiProvider(
        providers: dependencias(api ?? FakeApiClient()),
        child: MaterialApp(home: widget),
      ),
    );
  }

  /// Monta la app completa (MyApp con su router) en [initialLocation].
  Future<void> pumpMyApp({
    FakeApiClient? api,
    String initialLocation = AppRoutes.splash,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await pumpWidget(
      MultiProvider(
        providers: dependencias(api ?? FakeApiClient()),
        child: MyApp(initialLocation: initialLocation),
      ),
    );
  }
}
