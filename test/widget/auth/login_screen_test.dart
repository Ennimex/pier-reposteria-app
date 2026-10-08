// test/widget/auth/login_screen_test.dart — pruebas de widget del inicio de
// sesión (#17), sin red: el backend es un FakeApiClient montado con pumpApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Finder get _email => find.byType(TextFormField).at(0);
Finder get _password => find.byType(TextFormField).at(1);
Finder get _botonLogin => find.byType(ElevatedButton);

Future<void> _tocarIniciarSesion(WidgetTester tester) async {
  await tester.ensureVisible(_botonLogin);
  await tester.tap(_botonLogin);
}

void main() {
  group('LoginScreen', () {
    testWidgets('con campos vacíos muestra los errores y no llama al backend',
        (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const LoginScreen(), api: api);

      await _tocarIniciarSesion(tester);
      await tester.pump();

      expect(find.text('Ingresa tu email'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      expect(api.llamo(ApiConstants.login), isFalse);
    });

    testWidgets('un correo sin @ muestra «Email inválido»', (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const LoginScreen(), api: api);

      await tester.enterText(_email, 'cliente.example.com');
      await tester.enterText(_password, 'secreta1');
      await _tocarIniciarSesion(tester);
      await tester.pump();

      expect(find.text('Email inválido'), findsOneWidget);
      expect(api.llamo(ApiConstants.login), isFalse);
    });

    testWidgets('el botón se deshabilita mientras espera al backend',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas')
        ..demorar(ApiConstants.login, const Duration(seconds: 1));
      await tester.pumpApp(const LoginScreen(), api: api);

      await tester.enterText(_email, 'cliente@example.com');
      await tester.enterText(_password, 'secreta1');
      await _tocarIniciarSesion(tester);
      await tester.pump();

      expect(tester.widget<ElevatedButton>(_botonLogin).onPressed, isNull);
      expect(
        find.descendant(
          of: _botonLogin,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(tester.widget<ElevatedButton>(_botonLogin).onPressed, isNotNull);
      expect(find.text('Iniciar Sesión'), findsOneWidget);
    });

    testWidgets('muestra al usuario el mensaje de error del backend',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas');
      await tester.pumpApp(const LoginScreen(), api: api);

      await tester.enterText(_email, 'cliente@example.com');
      await tester.enterText(_password, 'incorrecta');
      await _tocarIniciarSesion(tester);
      await tester.pumpAndSettle();

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(api.ultima(ApiConstants.login)?.body, {
        'email': 'cliente@example.com',
        'password': 'incorrecta',
      });
    });
  });
}
