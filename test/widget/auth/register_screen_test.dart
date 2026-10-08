// test/widget/auth/register_screen_test.dart — pruebas de widget del registro
// (#17), sin red: el backend es un FakeApiClient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/register_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/verify_email_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Finder _campo(int i) => find.byType(TextFormField).at(i);
Finder get _botonRegistrarse => find.byType(ElevatedButton);

/// Llena los 6 campos en el orden de la pantalla: nombre, apellido, email,
/// teléfono, contraseña y confirmación.
Future<void> _llenar(
  WidgetTester tester, {
  String confirmacion = 'pastel123',
}) async {
  await tester.enterText(_campo(0), 'Ana');
  await tester.enterText(_campo(1), 'López');
  await tester.enterText(_campo(2), 'ana@example.com');
  await tester.enterText(_campo(3), '7711234567');
  await tester.enterText(_campo(4), 'pastel123');
  await tester.enterText(_campo(5), confirmacion);
}

Future<void> _aceptarTerminos(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Future<void> _tocarRegistrarse(WidgetTester tester) async {
  await tester.ensureVisible(_botonRegistrarse);
  await tester.tap(_botonRegistrarse);
}

void main() {
  group('RegisterScreen', () {
    testWidgets('contraseñas distintas muestran error y no llaman al backend',
        (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const RegisterScreen(), api: api);

      await _llenar(tester, confirmacion: 'pastel124');
      await _aceptarTerminos(tester);
      await _tocarRegistrarse(tester);
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(api.llamo(ApiConstants.register), isFalse);
    });

    testWidgets('sin aceptar los términos avisa y no llama al backend',
        (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const RegisterScreen(), api: api);

      await _llenar(tester);
      await _tocarRegistrarse(tester);
      await tester.pump();

      expect(
        find.text('Debes aceptar los términos y condiciones'),
        findsOneWidget,
      );
      expect(api.llamo(ApiConstants.register), isFalse);
    });

    testWidgets('un formulario válido envía los datos y pasa a verificar email',
        (tester) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.register, {
          'success': true,
          'message': 'Revisa tu correo',
        });
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.registro);
      await tester.pumpAndSettle();

      await _llenar(tester);
      await _aceptarTerminos(tester);
      await _tocarRegistrarse(tester);
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.register)?.body, {
        'nombre': 'Ana',
        'apellido': 'López',
        'email': 'ana@example.com',
        'telefono': '7711234567',
        'password': 'pastel123',
      });
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets('si el backend rechaza el registro, muestra su mensaje',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.register, 'El email ya está registrado');
      await tester.pumpApp(const RegisterScreen(), api: api);

      await _llenar(tester);
      await _aceptarTerminos(tester);
      await _tocarRegistrarse(tester);
      await tester.pumpAndSettle();

      expect(find.text('El email ya está registrado'), findsOneWidget);
      expect(find.byType(VerifyEmailScreen), findsNothing);
    });
  });
}
