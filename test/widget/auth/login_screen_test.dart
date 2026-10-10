// test/widget/auth/login_screen_test.dart — pruebas de widget del inicio de
// sesión (#17), sin red: el backend es un FakeApiClient montado con pumpApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository_remote.dart';
import 'package:pier_pasteleria/ui/auth/view_model/login_view_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_google_sign_in.dart';
import '../../helpers/pump_app.dart';

Finder get _email => find.byType(TextFormField).at(0);
Finder get _password => find.byType(TextFormField).at(1);
Finder get _botonLogin => find.byType(ElevatedButton);

/// Login cuyo repositorio usa [google] en lugar del plugin real.
LoginScreen _conGoogle(FakeApiClient api, FakeGoogleSignIn google) =>
    LoginScreen(
      viewModel: LoginViewModel(
        repo: AuthRepositoryRemote(api: api, google: google),
      ),
    );

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

    testWidgets('si Google falla, avisa con el motivo', (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(
        _conGoogle(api, FakeGoogleSignIn(error: Exception('sin red'))),
        api: api,
      );

      await tester.ensureVisible(find.text('Continuar con Google'));
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error al iniciar sesión con Google'),
          findsOneWidget);
      final contexto = tester.element(find.byType(LoginScreen));
      expect(contexto.read<AuthProvider>().isAuthenticated, isFalse);
    });

    testWidgets('si se cierra el selector de Google, no avisa nada',
        (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(_conGoogle(api, FakeGoogleSignIn()), api: api);

      await tester.ensureVisible(find.text('Continuar con Google'));
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('con Google correcto abre la sesión', (tester) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.googleMobile, {
          'success': true,
          'token': 'jwt',
          'user': {'id': 9, 'nombre': 'Ana', 'rol': 'cliente'},
        });
      await tester.pumpApp(
        _conGoogle(api, FakeGoogleSignIn(idToken: 'id-token')),
        api: api,
      );

      await tester.ensureVisible(find.text('Continuar con Google'));
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      final contexto = tester.element(find.byType(LoginScreen));
      expect(contexto.read<AuthProvider>().currentUser?['nombre'], 'Ana');
    });

    testWidgets('el ojito muestra y oculta la contraseña', (tester) async {
      await tester.pumpApp(const LoginScreen());

      bool oculta() => tester
          .widget<EditableText>(find.descendant(
              of: _password, matching: find.byType(EditableText)))
          .obscureText;

      expect(oculta(), isTrue);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(oculta(), isFalse);
    });
  });
}
