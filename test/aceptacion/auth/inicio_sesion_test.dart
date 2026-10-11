// test/aceptacion/auth/inicio_sesion_test.dart — pruebas de aceptación del
// inicio de sesión con correo o Google y de la recuperación de contraseña
// (#56; historia #34), sin red.
//
// Cada testWidgets es un escenario Gherkin de la historia #34: arranca la app
// completa (MyApp con su router) en el login, contra un backend falso
// (FakeApiClient), y comprueba a qué pantalla llega el usuario según su rol
// (AppRoutes.homeForRole) y qué se mandó al backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository_remote.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/forgot_password_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/reset_password_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/main/widgets/main_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_main_screen.dart';
import 'package:pier_pasteleria/ui/roles/widgets/panel_web_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_google_sign_in.dart';
import '../../helpers/pump_app.dart';

const _correo = 'ana@pier.mx';

/// Respuesta del backend a un inicio de sesión correcto con [rol].
Map<String, dynamic> _sesionAbierta(String rol) => {
      'success': true,
      'token': 'jwt',
      'user': {
        'id': 9,
        'nombre': 'Ana',
        'apellido': 'López',
        'email': _correo,
        'rol': rol,
      },
    };

/// Backend falso con lo que piden las pantallas de inicio de cada rol
/// (catálogo vacío para el cliente; entregas vacías para el repartidor).
FakeApiClient _backend() => FakeApiClient(respuestas: {
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
      ApiConstants.misEntregas: {
        'success': true,
        'entregas': <Map<String, dynamic>>[],
      },
      ApiConstants.disponibilidad: {'success': true, 'disponible': true},
      ApiConstants.entregasDisponibles: {
        'success': true,
        'pedidos': <Map<String, dynamic>>[],
      },
    });

/// Pantalla de celular: los paneles de inicio no caben en los 800×600 de
/// las pruebas con la fuente Ahem.
void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

/// Como pumpMyApp, pero el AuthRepository que ven las pantallas usa
/// [google] en lugar del plugin real (en pruebas no hay plugin).
Future<void> _montarConGoogle(
  WidgetTester tester,
  FakeApiClient api,
  FakeGoogleSignIn google,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: dependencias(api),
      child: Provider<AuthRepository>(
        create: (_) => AuthRepositoryRemote(api: api, google: google),
        child: const MyApp(initialLocation: AppRoutes.login),
      ),
    ),
  );
}

Future<void> _escribirCredenciales(
  WidgetTester tester, {
  required String correo,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), correo);
  await tester.enterText(find.byType(TextFormField).at(1), password);
}

/// Toca «Iniciar Sesión» y avanza el reloj a mano: el inicio de cada rol
/// tiene animaciones continuas, así que no se usa pumpAndSettle.
Future<void> _iniciarSesion(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Iniciar Sesión'));
  await tester.tap(find.text('Iniciar Sesión'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Pide el código de restablecimiento desde el login para [correo].
Future<void> _pedirCodigo(WidgetTester tester, String correo) async {
  await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
  await tester.tap(find.text('¿Olvidaste tu contraseña?'));
  await tester.pumpAndSettle();
  expect(find.byType(ForgotPasswordScreen), findsOneWidget);

  await tester.enterText(find.byType(TextFormField), correo);
  await tester.tap(find.text('Enviar código'));
  await tester.pumpAndSettle();
}

/// En «Nueva contraseña»: las 6 cajas del código y luego los dos campos.
Future<void> _restablecer(
  WidgetTester tester, {
  required String codigo,
  required String password,
}) async {
  for (var i = 0; i < codigo.length; i++) {
    await tester.enterText(find.byType(TextFormField).at(i), codigo[i]);
  }
  await tester.enterText(find.byType(TextFormField).at(6), password);
  await tester.enterText(find.byType(TextFormField).at(7), password);
  await tester.ensureVisible(find.text('Restablecer contraseña'));
  await tester.tap(find.text('Restablecer contraseña'));
  await tester.pumpAndSettle();
}

AuthProvider _sesion(WidgetTester tester) =>
    tester.element(find.byType(MyApp)).read<AuthProvider>();

/// Ruta en la que está el router de la app (p. ej. /main o /repartidor).
String _ruta(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

void main() {
  group('#34 Inicio de sesión y recuperación de contraseña', () {
    // Escenario: credenciales válidas
    //   Dado que tengo una cuenta verificada
    //   Cuando inicio sesión con mi correo y mi contraseña
    //   Entonces entro a la pantalla de inicio que corresponde a mi rol
    //     (cliente → /main, repartidor → /repartidor, empleado, gerencia y
    //     dirección general → /panel-web).
    final destinos = <String, (String, Type)>{
      'cliente': (AppRoutes.main, MainScreen),
      'repartidor': (AppRoutes.repartidor, RepartidorMainScreen),
      'empleado': (AppRoutes.panelWeb, PanelWebScreen),
      'gerencia': (AppRoutes.panelWeb, PanelWebScreen),
      'direccion_general': (AppRoutes.panelWeb, PanelWebScreen),
    };
    for (final MapEntry(key: rol, value: (ruta, pantalla))
        in destinos.entries) {
      testWidgets('Escenario: credenciales válidas ($rol → $ruta)',
          (tester) async {
        _celular(tester);
        final api = _backend()
          ..responder(ApiConstants.login, _sesionAbierta(rol));
        await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
        await tester.pumpAndSettle();

        await _escribirCredenciales(tester,
            correo: _correo, password: 'pastel123');
        await _iniciarSesion(tester);

        expect(api.ultima(ApiConstants.login)?.body,
            {'email': _correo, 'password': 'pastel123'});
        expect(_sesion(tester).isAuthenticated, isTrue);
        expect(_sesion(tester).rol, rol);
        expect(_ruta(tester), ruta);
        expect(find.byType(pantalla), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      });
    }

    // Escenario: credenciales inválidas
    //   Dado que tengo una cuenta verificada
    //   Cuando envío una contraseña incorrecta
    //   Entonces la app muestra el mensaje de error
    //     y sigo en la misma pantalla.
    testWidgets('Escenario: credenciales inválidas', (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.login, 'Credenciales inválidas');
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
      await tester.pumpAndSettle();

      await _escribirCredenciales(tester,
          correo: _correo, password: 'incorrecta');
      await _iniciarSesion(tester);
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.login)?.body,
          {'email': _correo, 'password': 'incorrecta'});
      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_ruta(tester), AppRoutes.login);
      expect(_sesion(tester).isAuthenticated, isFalse);
    });

    // Escenario (error): correo no registrado al iniciar sesión
    //   Dado que no tengo cuenta con ese correo
    //   Cuando intento iniciar sesión con él
    //   Entonces la app muestra el aviso del backend y sigo en el login.
    testWidgets('Escenario: correo no registrado al iniciar sesión',
        (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.login, 'No existe una cuenta con ese correo');
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
      await tester.pumpAndSettle();

      await _escribirCredenciales(tester,
          correo: 'nadie@pier.mx', password: 'pastel123');
      await _iniciarSesion(tester);
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.login)?.body?['email'], 'nadie@pier.mx');
      expect(find.text('No existe una cuenta con ese correo'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_sesion(tester).isAuthenticated, isFalse);
    });

    // Escenario: inicio de sesión con Google
    //   Dado que estoy en el inicio de sesión
    //   Cuando elijo continuar con Google y autorizo mi cuenta
    //   Entonces entro a la app con mi sesión iniciada.
    testWidgets('Escenario: inicio de sesión con Google', (tester) async {
      final api = _backend()
        ..responder(ApiConstants.googleMobile, _sesionAbierta('cliente'));
      await _montarConGoogle(
          tester, api, FakeGoogleSignIn(idToken: 'id-token-google'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continuar con Google'));
      await tester.tap(find.text('Continuar con Google'));
      // Al abrirse la sesión, el router saca al usuario del login.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.ultima(ApiConstants.googleMobile)?.body,
          {'idToken': 'id-token-google'});
      expect(_sesion(tester).isAuthenticated, isTrue);
      expect(_sesion(tester).currentUser?['email'], _correo);
      expect(_ruta(tester), AppRoutes.main);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    // Escenario: restablecer la contraseña
    //   Dado que pedí restablecer mi contraseña
    //     y recibí un código de 6 dígitos
    //   Cuando capturo el código y una contraseña nueva de al menos
    //     6 caracteres
    //   Entonces puedo iniciar sesión con la contraseña nueva.
    testWidgets('Escenario: restablecer la contraseña', (tester) async {
      final api = _backend()
        ..responder(ApiConstants.requestPasswordReset, {'success': true})
        ..responder(ApiConstants.resetPassword, {'success': true})
        ..responder(ApiConstants.login, _sesionAbierta('cliente'));
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
      await tester.pumpAndSettle();

      // Dado: pedí el código para mi correo.
      await _pedirCodigo(tester, _correo);
      expect(api.ultima(ApiConstants.requestPasswordReset)?.body,
          {'email': _correo});
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      // Cuando: capturo el código y la contraseña nueva.
      await _restablecer(tester, codigo: '731904', password: 'nueva123');
      expect(api.ultima(ApiConstants.resetPassword)?.body, {
        'email': _correo,
        'codigo': '731904',
        'nuevaPassword': 'nueva123',
      });
      expect(find.text('¡Contraseña restablecida!'), findsOneWidget);
      await tester.tap(find.text('Ir al Login'));
      await tester.pumpAndSettle();

      // Entonces: vuelvo al login y entro con la contraseña nueva.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
      await _escribirCredenciales(tester,
          correo: _correo, password: 'nueva123');
      await _iniciarSesion(tester);

      expect(api.ultima(ApiConstants.login)?.body,
          {'email': _correo, 'password': 'nueva123'});
      expect(_sesion(tester).isAuthenticated, isTrue);
      expect(find.byType(MainScreen), findsOneWidget);
    });

    // Escenario (error): correo no registrado al restablecer
    //   Dado que olvidé mi contraseña
    //   Cuando pido el código para un correo que no tiene cuenta
    //   Entonces la app muestra el aviso del backend
    //     y no paso a capturar la contraseña nueva.
    testWidgets('Escenario: correo no registrado al restablecer',
        (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.requestPasswordReset, 'Correo no registrado');
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
      await tester.pumpAndSettle();

      await _pedirCodigo(tester, 'nadie@pier.mx');

      expect(api.ultima(ApiConstants.requestPasswordReset)?.body,
          {'email': 'nadie@pier.mx'});
      expect(find.text('Correo no registrado'), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
    });

    // Escenario (error): código de restablecimiento incorrecto
    //   Dado que pedí restablecer mi contraseña
    //   Cuando capturo un código que no es el que recibí
    //   Entonces la app muestra el error, borra el código
    //     y no cambia la contraseña.
    testWidgets('Escenario: código de restablecimiento incorrecto',
        (tester) async {
      final api = _backend()
        ..responder(ApiConstants.requestPasswordReset, {'success': true})
        ..fallar(ApiConstants.resetPassword, 'Código inválido o expirado');
      await tester.pumpMyApp(api: api, initialLocation: AppRoutes.login);
      await tester.pumpAndSettle();
      await _pedirCodigo(tester, _correo);

      await _restablecer(tester, codigo: '000000', password: 'nueva123');

      expect(find.text('Código inválido o expirado'), findsOneWidget);
      expect(find.text('¡Contraseña restablecida!'), findsNothing);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(i))
              .controller
              ?.text,
          '',
        );
      }
    });
  });
}
