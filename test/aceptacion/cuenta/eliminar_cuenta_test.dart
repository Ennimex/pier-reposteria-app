// test/aceptacion/cuenta/eliminar_cuenta_test.dart — escenarios Gherkin de
// «Eliminar mi cuenta» (derechos ARCO, #222): la baja desde «Mis datos» con
// DELETE /usuarios/perfil, sin red.
//
// Con la sesión del cliente iniciada, la prueba entra a «Mis datos» como
// desde «Más» (la pantalla arma su ViewModel con los repositorios de
// dependencies.dart), contra un backend falso que contesta la baja como el
// de producción: 200 si se eliminó y 409 `PEDIDOS_EN_CURSO` si hay pedidos
// sin entregar; sin conexión, ApiService contesta su mensaje.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/more/widgets/mis_datos_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart' show capturarUrls;
import '../../helpers/pump_app.dart';

const Map<String, dynamic> _cliente = {
  'id': 1,
  'nombre': 'Ana',
  'apellido': 'López',
  'email': 'ana@pier.mx',
  'rol': 'cliente',
};

/// Backend falso: el login y el perfil del cliente, y [baja] como respuesta
/// de DELETE /usuarios/perfil.
FakeApiClient _backend(Map<String, dynamic> baja) => FakeApiClient(
      respuestas: {
        ApiConstants.login: {'success': true, 'token': 'jwt', 'user': _cliente},
        ApiConstants.profile: {'success': true, 'user': _cliente},
        ApiConstants.eliminarCuenta: baja,
      },
    );

/// Página de partida: la opción «Mis datos» de «Más», que abre la pantalla
/// sin ViewModel inyectado, como la app.
class _Mas extends StatelessWidget {
  const _Mas();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const MisDatosScreen()),
            ),
            child: const Text('Mis datos'),
          ),
        ),
      );
}

/// Dado que inicié sesión: monta «Más» (la pestaña que se ve) y abre la
/// sesión del cliente con el login del backend falso.
Future<void> _iniciarSesion(WidgetTester tester, FakeApiClient api) async {
  // Sin plugin de Google en pruebas: su signOut (al cerrar la sesión)
  // responde al instante.
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  final mensajero = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(google, (_) async => null);
  addTearDown(() => mensajero.setMockMethodCallHandler(google, null));
  await tester.pumpApp(const _Mas(), api: api);
  await tester.iniciarSesion(find.byType(_Mas));
  tester.element(find.byType(_Mas, skipOffstage: false)).read<NavigationProvider>().goMore();
  await tester.pump();
  expect(_sesion(tester).isAuthenticated, isTrue);
}

AuthProvider _sesion(WidgetTester tester) =>
    tester.element(find.byType(_Mas, skipOffstage: false)).read<AuthProvider>();

/// Entra a «Mis datos», toca «Eliminar mi cuenta» y lo confirma.
Future<void> _eliminarMiCuenta(WidgetTester tester) async {
  await tester.tap(find.text('Mis datos'));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(find.text('Eliminar mi cuenta'),
      find.byType(ListView), const Offset(0, -200));
  await tester.tap(find.text('Eliminar mi cuenta'));
  await tester.pumpAndSettle();
  expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
  await tester.tap(find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Eliminar mi cuenta'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('#222 Derechos ARCO: eliminar mi cuenta', () {
    // Escenario: eliminar la cuenta
    //   Dado que inicié sesión y no tengo pedidos en curso
    //   Cuando elimino mi cuenta desde «Mis datos» y lo confirmo
    //   Entonces la app me avisa que se eliminó, cierra mi sesión en el
    //   teléfono y me lleva al Inicio
    testWidgets('Escenario: eliminar la cuenta', (tester) async {
      // Dado que inicié sesión y no tengo pedidos en curso
      final api =
          _backend({'success': true, 'message': 'Tu cuenta se eliminó'});
      await _iniciarSesion(tester, api);

      // Cuando elimino mi cuenta desde «Mis datos» y lo confirmo
      await _eliminarMiCuenta(tester);

      // Entonces la app me avisa que se eliminó, cierra mi sesión en el
      // teléfono y me lleva al Inicio
      expect(api.ultima(ApiConstants.eliminarCuenta)!.metodo, 'DELETE-Auth');
      expect(find.text('Tu cuenta se eliminó'), findsOneWidget);
      expect(_sesion(tester).isAuthenticated, isFalse);
      // El token ya no sirve: no se pide al servidor cerrar la sesión.
      expect(api.llamo(ApiConstants.logout), isFalse);
      expect(find.byType(MisDatosScreen), findsNothing);
      expect(
        tester.element(find.byType(_Mas, skipOffstage: false)).read<NavigationProvider>()
            .selectedIndex,
        0,
      );
    });

    // Escenario: pedidos en curso
    //   Dado que tengo pedidos sin entregar
    //   Cuando intento eliminar mi cuenta
    //   Entonces la app me dice que espere a que se entreguen o que los
    //   cancele, y mi sesión sigue abierta
    testWidgets('Escenario: pedidos en curso', (tester) async {
      // Dado que tengo pedidos sin entregar
      const mensaje =
          'Tienes pedidos en curso; espera a que se entreguen o cancélalos';
      final api = _backend({
        'success': false,
        'codigo': 'PEDIDOS_EN_CURSO',
        'message': mensaje,
      });
      await _iniciarSesion(tester, api);

      // Cuando intento eliminar mi cuenta
      await _eliminarMiCuenta(tester);

      // Entonces la app me dice que espere a que se entreguen o que los
      // cancele, y mi sesión sigue abierta
      expect(find.text('No se eliminó tu cuenta'), findsOneWidget);
      expect(find.text(mensaje), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(MisDatosScreen), findsOneWidget);
      expect(_sesion(tester).isAuthenticated, isTrue);
    });

    // Escenario: sin conexión
    //   Dado que no hay conexión con Pier
    //   Cuando intento eliminar mi cuenta
    //   Entonces la app me ofrece pedir la baja por correo, ya escrito con
    //   los datos de mi cuenta
    testWidgets('Escenario: sin conexión', (tester) async {
      // Dado que no hay conexión con Pier
      final urls = capturarUrls(tester);
      final api = _backend(
          {'success': false, 'message': ApiService.mensajeSinConexion});
      await _iniciarSesion(tester, api);

      // Cuando intento eliminar mi cuenta
      await _eliminarMiCuenta(tester);

      // Entonces la app me ofrece pedir la baja por correo, ya escrito con
      // los datos de mi cuenta
      expect(find.textContaining(ApiService.mensajeSinConexion),
          findsOneWidget);
      await tester.tap(find.text('Pedirlo por correo'));
      await tester.pumpAndSettle();
      final correo = Uri.parse(urls.single! as String);
      expect(correo.path, BusinessInfo.email);
      expect(correo.queryParameters['subject'], 'Eliminar mi cuenta');
      expect(correo.queryParameters['body'],
          contains('Correo de la cuenta: ana@pier.mx'));
      expect(_sesion(tester).isAuthenticated, isTrue);
    });
  });
}
