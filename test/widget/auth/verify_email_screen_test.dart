// test/widget/auth/verify_email_screen_test.dart — pruebas de widget de la
// verificación del correo (MVVM, Fase 5, #99), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/auth/widgets/verify_email_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const _email = 'ana@pier.mx';

Finder _caja(int i) => find.byType(TextFormField).at(i);

Future<void> _capturar(WidgetTester tester, String codigo) async {
  for (var i = 0; i < codigo.length; i++) {
    await tester.enterText(_caja(i), codigo[i]);
  }
  await tester.pump();
}

void main() {
  group('VerifyEmailScreen', () {
    testWidgets('muestra el correo y no verifica un código incompleto',
        (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const VerifyEmailScreen(email: _email), api: api);

      expect(find.text(_email), findsOneWidget);
      await _capturar(tester, '123');
      await tester.tap(find.text('Verificar'));
      await tester.pump();

      expect(find.text('Ingresa el código completo de 6 dígitos'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.verifyEmail), isFalse);
    });

    testWidgets('al completar el código verifica solo; si falla, lo borra',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.verifyEmail, 'Código inválido');
      await tester.pumpApp(const VerifyEmailScreen(email: _email), api: api);

      await _capturar(tester, '654321');
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.verifyEmail)?.body,
          {'email': _email, 'codigo': '654321'});
      expect(find.text('Código inválido'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(tester.widget<TextFormField>(_caja(i)).controller?.text, '');
      }
    });

    testWidgets('reenviar muestra el mensaje del backend', (tester) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.resendVerification,
            {'success': true, 'message': 'Te mandamos otro código'});
      await tester.pumpApp(const VerifyEmailScreen(email: _email), api: api);

      await tester.tap(find.text('Reenviar'));
      await tester.pumpAndSettle();

      expect(find.text('Te mandamos otro código'), findsOneWidget);
    });

    testWidgets('si reenviar falla, muestra el error', (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.resendVerification, 'Espera un minuto');
      await tester.pumpApp(const VerifyEmailScreen(email: _email), api: api);

      await tester.tap(find.text('Reenviar'));
      await tester.pumpAndSettle();

      expect(find.text('Espera un minuto'), findsOneWidget);
    });
  });
}
