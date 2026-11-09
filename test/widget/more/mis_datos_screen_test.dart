// test/widget/more/mis_datos_screen_test.dart — «Mis datos» (#221): muestra
// lo que el servidor tiene de la cuenta y lleva a corregirlo; «Eliminar mi
// cuenta» (#222) la da de baja al confirmar, cierra la sesión en el teléfono
// y vuelve al Inicio, y si la red o el servidor fallan ofrece pedirla por
// correo.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/more/view_model/mis_datos_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/edit_profile_screen.dart';
import 'package:pier_reposteria/ui/more/widgets/mis_datos_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart' show capturarUrls;
import '../../helpers/pump_app.dart';

const Map<String, dynamic> _usuario = {
  'nombre': 'Ana',
  'apellido': 'López',
  'email': 'ana@pier.mx',
  'telefono': '7711234567',
  'rol': 'cliente',
  'emailVerificado': true,
};

const _enCurso =
    'Tienes pedidos en curso; espera a que se entreguen o cancélalos';

/// «Más» de mentira: abre «Mis datos» como la pestaña de la app, sin
/// ViewModel inyectado.
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
            child: const Text('Abrir mis datos'),
          ),
        ),
      );
}

/// El botón «Eliminar mi cuenta» del diálogo de confirmación (la pantalla
/// tiene otro con el mismo texto).
final Finder _confirmar = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('Eliminar mi cuenta'),
);

void main() {
  testWidgets('muestra los datos del servidor y cómo ejercer los demás '
      'derechos', (tester) async {
    final api = FakeApiClient()
      ..responder(ApiConstants.profile, {'success': true, 'user': _usuario});

    await tester.pumpApp(const MisDatosScreen(), api: api);
    await tester.pumpAndSettle();

    expect(find.text('Mis datos'), findsOneWidget);
    expect(find.text(MisDatosScreen.explicacion), findsOneWidget);
    expect(find.text('ana@pier.mx'), findsOneWidget);
    expect(find.text('7711234567'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    // Va al final de la lista: se baja hasta verlo.
    await tester.dragUntilVisible(find.text(MisDatosScreen.otrosDerechos),
        find.byType(ListView), const Offset(0, -200));
    expect(find.text(MisDatosScreen.otrosDerechos), findsOneWidget);
  });

  testWidgets('si falla, «Reintentar» vuelve a consultar', (tester) async {
    final api = FakeApiClient()
      ..fallar(ApiConstants.profile, 'Usuario no encontrado');

    await tester.pumpApp(const MisDatosScreen(), api: api);
    await tester.pumpAndSettle();
    expect(find.text('Usuario no encontrado'), findsOneWidget);

    api.responder(ApiConstants.profile, {'success': true, 'user': _usuario});
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('ana@pier.mx'), findsOneWidget);
    expect(
      api.llamadas.where((l) => l.endpoint == ApiConstants.profile),
      hasLength(2),
    );
  });

  testWidgets('«Corregir mis datos» abre Editar perfil y al volver recarga',
      (tester) async {
    final api = FakeApiClient()
      ..responder(ApiConstants.profile, {'success': true, 'user': _usuario});

    await tester.pumpApp(const MisDatosScreen(), api: api);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Corregir mis datos'));
    await tester.tap(find.text('Corregir mis datos'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    expect(find.byType(MisDatosScreen), findsOneWidget);
    expect(
      api.llamadas.where((l) => l.endpoint == ApiConstants.profile),
      hasLength(2),
    );
  });

  group('«Eliminar mi cuenta» (#222)', () {
    /// Con la sesión del cliente abierta y en la pestaña «Más», entra a
    /// «Mis datos» y toca «Eliminar mi cuenta» (va al final de la lista).
    /// [baja] es la respuesta de DELETE /usuarios/perfil.
    Future<FakeApiClient> pedirBaja(
      WidgetTester tester, {
      Map<String, dynamic> baja = const {'success': true},
    }) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': _usuario})
        ..responder(ApiConstants.eliminarCuenta, baja);
      // Sin plugin de Google en pruebas: su signOut (al cerrar la sesión)
      // responde al instante.
      const google = MethodChannel('plugins.flutter.io/google_sign_in');
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(google, (_) async => null);
      addTearDown(() => mensajero.setMockMethodCallHandler(google, null));
      await tester.pumpApp(const _Mas(), api: api, preferencias: {
        'pierreposteria_token': 'jwt',
        'pierreposteria_current_user': jsonEncode(_usuario),
      });
      tester.element(find.byType(_Mas, skipOffstage: false))
        ..read<AuthProvider>().abrirSesion(_usuario)
        ..read<NavigationProvider>().goMore();
      await tester.tap(find.text('Abrir mis datos'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Eliminar mi cuenta'),
          find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      return api;
    }

    AuthProvider sesion(WidgetTester tester) =>
        tester.element(find.byType(_Mas, skipOffstage: false)).read<AuthProvider>();

    testWidgets('pide confirmar, dice qué se borra y «Cancelar» no la '
        'elimina', (tester) async {
      final api = await pedirBaja(tester);

      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
      expect(find.textContaining(MisDatosScreen.confirmarBaja), findsOneWidget);
      expect(find.textContaining(MisDatosScreen.queSeBorra), findsOneWidget);
      expect(_confirmar, findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar tu cuenta?'), findsNothing);
      expect(api.llamo(ApiConstants.eliminarCuenta), isFalse);
      expect(sesion(tester).isAuthenticated, isTrue);
    });

    testWidgets('al confirmar la elimina, cierra la sesión solo en el '
        'teléfono y vuelve al Inicio', (tester) async {
      final api = await pedirBaja(tester,
          baja: {'success': true, 'message': 'Tu cuenta se eliminó'});

      await tester.tap(_confirmar);
      await tester.pumpAndSettle();

      expect(api.llamo(ApiConstants.eliminarCuenta, metodo: 'DELETE-Auth'),
          isTrue);
      expect(api.llamo(ApiConstants.logout), isFalse);
      expect(find.text(MisDatosScreen.cuentaEliminada), findsOneWidget);
      expect(find.byType(MisDatosScreen), findsNothing);
      final contexto = tester.element(find.byType(_Mas, skipOffstage: false));
      expect(contexto.read<AuthProvider>().isAuthenticated, isFalse);
      expect(contexto.read<AuthProvider>().sesionExpiro, isFalse);
      expect(contexto.read<NavigationProvider>().selectedIndex, 0);
    });

    testWidgets('con pedidos en curso muestra el mensaje del backend y '
        'conserva la sesión', (tester) async {
      final urls = capturarUrls(tester);
      await pedirBaja(tester, baja: {
        'success': false,
        'codigo': 'PEDIDOS_EN_CURSO',
        'message': _enCurso,
      });

      await tester.tap(_confirmar);
      await tester.pumpAndSettle();

      expect(find.text('No se eliminó tu cuenta'), findsOneWidget);
      expect(find.text(_enCurso), findsOneWidget);
      expect(find.text('Pedirlo por correo'), findsNothing);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(find.byType(MisDatosScreen), findsOneWidget);
      expect(find.text('Eliminar mi cuenta'), findsOneWidget);
      expect(sesion(tester).isAuthenticated, isTrue);
      expect(urls, isEmpty);
    });

    testWidgets('sin red ofrece «Pedirlo por correo», que abre el correo a '
        'Pier ya escrito', (tester) async {
      final urls = capturarUrls(tester);
      await pedirBaja(tester,
          baja: {'success': false, 'message': ApiService.mensajeSinConexion});

      await tester.tap(_confirmar);
      await tester.pumpAndSettle();
      expect(find.textContaining(ApiService.mensajeSinConexion), findsOneWidget);
      expect(find.textContaining(MisDatosScreen.respaldoCorreo), findsOneWidget);
      await tester.tap(find.text('Pedirlo por correo'));
      await tester.pumpAndSettle();

      final correo = Uri.parse(urls.single! as String);
      expect(correo.scheme, 'mailto');
      expect(correo.path, BusinessInfo.email);
      expect(correo.queryParameters['subject'], MisDatosViewModel.asuntoBaja);
      expect(correo.queryParameters['body'],
          contains('Correo de la cuenta: ana@pier.mx'));
      expect(find.text(MisDatosScreen.sinAppDeCorreo), findsNothing);
      expect(sesion(tester).isAuthenticated, isTrue);
    });

    testWidgets('si el servidor falla y no hay app de correo, dice a dónde '
        'escribir', (tester) async {
      // url_launcher contesta que no hubo app que abriera el correo.
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (_) async => false);
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await pedirBaja(tester, baja: {
        'success': false,
        'message': 'No se pudo eliminar tu cuenta',
      });

      await tester.tap(_confirmar);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedirlo por correo'));
      await tester.pumpAndSettle();

      expect(find.text(MisDatosScreen.sinAppDeCorreo), findsOneWidget);
    });

    testWidgets('mientras se elimina, el botón dice que trabaja y no se '
        'puede volver a tocar', (tester) async {
      final api = await pedirBaja(tester,
          baja: {'success': false, 'message': 'No se pudo eliminar tu cuenta'});
      api.demorar(ApiConstants.eliminarCuenta, const Duration(seconds: 2));

      await tester.tap(_confirmar);
      // El indicador gira sin parar: se avanza el reloj a mano.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(MisDatosScreen.eliminando), findsOneWidget);
      final boton = tester.widget<ButtonStyleButton>(find.ancestor(
          of: find.text(MisDatosScreen.eliminando),
          matching: find.bySubtype<ButtonStyleButton>()));
      expect(boton.onPressed, isNull);
      await tester.tap(find.text(MisDatosScreen.eliminando),
          warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        api.llamadas.where((l) => l.endpoint == ApiConstants.eliminarCuenta),
        hasLength(1),
      );
      expect(find.text('No se eliminó tu cuenta'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar mi cuenta'), findsOneWidget);
      expect(find.text(MisDatosScreen.eliminando), findsNothing);
    });
  });
}
