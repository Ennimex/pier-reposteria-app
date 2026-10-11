// test/aceptacion/auth/registro_verificacion_test.dart — pruebas de aceptación
// del registro y la verificación del correo con código (#56; historia #33),
// sin red.
//
// Cada testWidgets es un escenario Gherkin de la historia #33: recorre las
// pantallas reales (router completo o la pantalla suelta) contra un backend
// falso (FakeApiClient) y comprueba lo que el usuario ve y lo que la app
// manda al backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/verify_email_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/main/widgets/main_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const _correo = 'ana@pier.mx';
const _codigo = '482915';

/// Backend falso con lo mínimo para que el inicio (catálogo vacío) cargue
/// después de entrar, más el registro aceptado.
FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.register: {'success': true},
      ApiConstants.productos: {
        'success': true,
        'productos': <Map<String, dynamic>>[],
      },
      ApiConstants.promocionesActivas: {
        'success': true,
        'promociones': <Map<String, dynamic>>[],
      },
      ApiConstants.categorias: {
        'success': true,
        'categorias': <Map<String, dynamic>>[],
      },
      ApiConstants.filtros: {
        'success': true,
        'filtros': <String, dynamic>{},
      },
      ApiConstants.configuracionSeccion('personalizacion'): {
        'success': true,
        'config': <String, dynamic>{},
      },
    });

/// Las 6 cajas del código son los únicos TextFormField de la verificación.
Finder _caja(int i) => find.byType(TextFormField).at(i);

/// Captura [codigo] dígito por dígito, como lo haría el usuario.
Future<void> _capturar(WidgetTester tester, String codigo) async {
  for (var i = 0; i < codigo.length; i++) {
    await tester.enterText(_caja(i), codigo[i]);
  }
  await tester.pump();
}

/// Llena el formulario de registro con un correo válido y lo envía.
Future<void> _registrarse(WidgetTester tester) async {
  final datos = [
    'Ana', 'López', _correo, '7711234567', 'pastel123', 'pastel123', //
  ];
  for (var i = 0; i < datos.length; i++) {
    await tester.enterText(find.byType(TextFormField).at(i), datos[i]);
  }
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.ensureVisible(find.text('Registrarse'));
  await tester.tap(find.text('Registrarse'));
  await tester.pumpAndSettle();
}

AuthProvider _sesion(WidgetTester tester) =>
    tester.element(find.byType(MyApp)).read<AuthProvider>();

void main() {
  group('#33 Registro y verificación de correo', () {
    // Escenario: verificación correcta
    //   Dado que me registré con un correo válido
    //     y recibí un código de 6 dígitos
    //   Cuando capturo los 6 dígitos
    //   Entonces la app verifica el código sin pulsar otro botón
    //     y entro a la pantalla principal.
    testWidgets('Escenario: verificación correcta', (tester) async {
      final api = _backend()
        ..responder(ApiConstants.verifyEmail, {
          'success': true,
          'token': 'jwt',
          'user': {'id': 9, 'nombre': 'Ana', 'rol': 'cliente'},
        });
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.registro);
      await tester.pumpAndSettle();

      // Dado: el registro se acepta y la app pide el código del correo.
      await _registrarse(tester);
      expect(api.ultima(ApiConstants.register)?.body?['email'], _correo);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text(_correo), findsOneWidget);

      // Cuando: capturo los 6 dígitos (sin tocar «Verificar»).
      await _capturar(tester, _codigo);
      // El inicio tiene animaciones continuas: se avanza el reloj a mano.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Entonces: se verificó solo y estoy en la pantalla principal.
      expect(api.ultima(ApiConstants.verifyEmail)?.body,
          {'email': _correo, 'codigo': _codigo});
      expect(find.byType(VerifyEmailScreen), findsNothing);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(_sesion(tester).isAuthenticated, isTrue);
      expect(_sesion(tester).currentUser?['nombre'], 'Ana');
    });

    // Escenario: código incompleto
    //   Dado que estoy en la pantalla de verificación
    //   Cuando intento verificar con menos de 6 dígitos
    //   Entonces la app muestra un aviso y no envía la verificación.
    testWidgets('Escenario: código incompleto', (tester) async {
      final api = _backend();
      await tester.pumpApp(const VerifyEmailScreen(email: _correo), api: api);

      await _capturar(tester, '4829');
      await tester.tap(find.text('Verificar'));
      await tester.pump();

      expect(find.text('Ingresa el código completo de 6 dígitos'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.verifyEmail), isFalse);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    // Escenario: reenviar el código
    //   Dado que no me llegó el código
    //   Cuando pido reenviarlo
    //   Entonces la app solicita un código nuevo para el mismo correo.
    testWidgets('Escenario: reenviar el código', (tester) async {
      final api = _backend()
        ..responder(ApiConstants.resendVerification,
            {'success': true, 'message': 'Te enviamos un código nuevo'});
      await tester.pumpApp(const VerifyEmailScreen(email: _correo), api: api);

      await tester.tap(find.text('Reenviar'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.resendVerification)?.body,
          {'email': _correo});
      expect(find.text('Te enviamos un código nuevo'), findsOneWidget);
    });

    // Escenario (error): código incorrecto
    //   Dado que estoy en la pantalla de verificación
    //   Cuando capturo 6 dígitos que no corresponden a mi código
    //   Entonces la app muestra el error del backend, borra las cajas
    //     y sigo en la verificación sin sesión.
    testWidgets('Escenario: código incorrecto', (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.verifyEmail, 'Código inválido o expirado');
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.registro);
      await tester.pumpAndSettle();
      await _registrarse(tester);

      await _capturar(tester, '000000');
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.verifyEmail)?.body,
          {'email': _correo, 'codigo': '000000'});
      expect(find.text('Código inválido o expirado'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(tester.widget<TextFormField>(_caja(i)).controller?.text, '');
      }
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
      expect(_sesion(tester).isAuthenticated, isFalse);
    });
  });
}
