// test/widget/auth/forgot_password_screen_test.dart — pruebas de widget de
// «¿Olvidaste tu contraseña?» (MVVM, Fase 5, #99), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/auth/widgets/forgot_password_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/reset_password_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _enviar(WidgetTester tester, String correo) async {
  await tester.enterText(find.byType(TextFormField), correo);
  await tester.tap(find.text('Enviar código'));
  await tester.pumpAndSettle();
}

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('un correo sin @ avisa y no llama al backend', (tester) async {
      final api = FakeApiClient();
      await tester.pumpApp(const ForgotPasswordScreen(), api: api);

      await _enviar(tester, 'ana.pier.mx');

      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
      expect(api.llamo(ApiConstants.requestPasswordReset), isFalse);
    });

    testWidgets('si el backend falla, muestra su mensaje', (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.requestPasswordReset, 'Correo no registrado');
      await tester.pumpApp(const ForgotPasswordScreen(), api: api);

      await _enviar(tester, 'ana@pier.mx');

      expect(find.text('Correo no registrado'), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
    });

    testWidgets('con el código enviado pasa a «Nueva contraseña»',
        (tester) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.requestPasswordReset, {'success': true});
      await tester.pumpApp(const ForgotPasswordScreen(), api: api);

      await _enviar(tester, '  ana@pier.mx ');

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('ana@pier.mx'), findsOneWidget);
      expect(api.ultima(ApiConstants.requestPasswordReset)?.body,
          {'email': 'ana@pier.mx'});
    });
  });
}
