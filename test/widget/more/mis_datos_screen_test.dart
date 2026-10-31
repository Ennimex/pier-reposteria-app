// test/widget/more/mis_datos_screen_test.dart — «Mis datos» (#221): muestra
// lo que el servidor tiene de la cuenta y lleva a corregirlo; «Eliminar mi
// cuenta» (#222) abre el correo a Pier ya escrito.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/ui/more/view_model/mis_datos_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/edit_profile_screen.dart';
import 'package:pier_reposteria/ui/more/widgets/mis_datos_screen.dart';

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
    /// Abre «Mis datos» y toca «Eliminar mi cuenta» (va al final de la lista).
    Future<void> pedirBaja(WidgetTester tester) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': _usuario});
      await tester.pumpApp(const MisDatosScreen(), api: api);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Eliminar mi cuenta'),
          find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
    }

    testWidgets('pide confirmar y «Cancelar» no abre el correo',
        (tester) async {
      final urls = capturarUrls(tester);
      await pedirBaja(tester);

      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
      expect(find.text(MisDatosScreen.confirmarBaja), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar tu cuenta?'), findsNothing);
      expect(urls, isEmpty);
    });

    testWidgets('al confirmar abre el correo a Pier ya escrito',
        (tester) async {
      final urls = capturarUrls(tester);
      await pedirBaja(tester);

      await tester.tap(find.text('Escribir el correo'));
      await tester.pumpAndSettle();

      final correo = Uri.parse(urls.single! as String);
      expect(correo.scheme, 'mailto');
      expect(correo.path, BusinessInfo.email);
      expect(correo.queryParameters['subject'], MisDatosViewModel.asuntoBaja);
      expect(correo.queryParameters['body'],
          contains('Correo de la cuenta: ana@pier.mx'));
      expect(find.text(MisDatosScreen.sinAppDeCorreo), findsNothing);
    });

    testWidgets('sin app de correo dice a dónde escribir', (tester) async {
      // url_launcher contesta que no hubo app que abriera el correo.
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (_) async => false);
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await pedirBaja(tester);

      await tester.tap(find.text('Escribir el correo'));
      await tester.pumpAndSettle();

      expect(find.text(MisDatosScreen.sinAppDeCorreo), findsOneWidget);
    });
  });
}
