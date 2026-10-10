// test/widget/auth/reset_password_screen_test.dart — pruebas de widget de
// «Nueva contraseña» (MVVM, Fase 5, #99), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/auth/widgets/reset_password_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const _email = 'ana@pier.mx';

// Las 6 cajas del código van primero; luego contraseña y confirmación.
Finder _campo(int i) => find.byType(TextFormField).at(i);
Finder get _boton => find.text('Restablecer contraseña');

Future<void> _llenar(
  WidgetTester tester, {
  String codigo = '123456',
  String password = 'pastel1',
  String? confirmacion,
}) async {
  for (var i = 0; i < codigo.length; i++) {
    await tester.enterText(_campo(i), codigo[i]);
  }
  await tester.enterText(_campo(6), password);
  await tester.enterText(_campo(7), confirmacion ?? password);
}

Future<void> _restablecer(WidgetTester tester) async {
  await tester.ensureVisible(_boton);
  await tester.tap(_boton);
  await tester.pumpAndSettle();
}

String? _texto(WidgetTester tester, int i) =>
    tester.widget<TextFormField>(_campo(i)).controller?.text;

void main() {
  group('ResetPasswordScreen', () {
    testWidgets('contraseñas distintas avisan y no llaman al backend',
        (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const ResetPasswordScreen(email: _email), api: api);

      await _llenar(tester, confirmacion: 'pastel2');
      await _restablecer(tester);

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(api.llamo(ApiConstants.resetPassword), isFalse);
      expect(_texto(tester, 0), '1'); // lo capturado se conserva
    });

    testWidgets('un código rechazado se borra y muestra el mensaje',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.resetPassword, 'Código expirado');
      await tester.pumpApp(const ResetPasswordScreen(email: _email), api: api);

      await _llenar(tester);
      await _restablecer(tester);

      expect(find.text('Código expirado'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(_texto(tester, i), '');
      }
    });

    testWidgets('al restablecer muestra el diálogo de éxito', (tester) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.resetPassword, {'success': true});
      await tester.pumpApp(const ResetPasswordScreen(email: _email), api: api);

      await _llenar(tester);
      await _restablecer(tester);

      expect(find.text('¡Contraseña restablecida!'), findsOneWidget);
      expect(find.text('Ir al Login'), findsOneWidget);
      expect(api.ultima(ApiConstants.resetPassword)?.body, {
        'email': _email,
        'codigo': '123456',
        'nuevaPassword': 'pastel1',
      });
    });

    testWidgets('los ojitos muestran cada contraseña por separado',
        (tester) async {
      await tester.pumpApp(const ResetPasswordScreen(email: _email));

      bool oculta(int i) => tester
          .widget<EditableText>(
              find.descendant(of: _campo(i), matching: find.byType(EditableText)))
          .obscureText;

      expect(oculta(6), isTrue);
      expect(oculta(7), isTrue);
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();

      expect(oculta(6), isFalse);
      expect(oculta(7), isTrue);
    });
  });
}
