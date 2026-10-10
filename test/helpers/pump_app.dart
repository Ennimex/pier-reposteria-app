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
//   await tester.iniciarSesion(find.byType(HomeScreen));     // con sesión
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
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

  /// Inicia sesión como lo hace la pantalla de login: el AuthRepository
  /// manda las credenciales al backend falso (que debe responder a
  /// ApiConstants.login) y la sesión se abre en AuthProvider. [en] es
  /// cualquier widget ya montado con [pumpApp].
  Future<void> iniciarSesion(
    Finder en, {
    String email = 'ana@pier.mx',
    String password = 'secreta',
  }) async {
    final contexto = element(en);
    final usuario = await contexto
        .read<AuthRepository>()
        .iniciarSesion(email: email, password: password);
    contexto.read<AuthProvider>().abrirSesion(usuario);
  }
}
