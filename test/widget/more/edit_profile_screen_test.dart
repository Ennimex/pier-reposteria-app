// test/widget/more/edit_profile_screen_test.dart — la vista de «Editar
// Perfil» refleja su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_pasteleria/ui/more/view_model/edit_profile_view_model.dart';
import 'package:pier_pasteleria/ui/more/widgets/edit_profile_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const String _endpoint = ApiConstants.updateProfileData;

Future<void> _montar(WidgetTester tester, FakeApiClient api) =>
    tester.pumpApp(
      EditProfileScreen(
        viewModel: EditProfileViewModel(
          repo: CuentaRepositoryRemote(api: api),
          usuario: const {
            'nombre': 'Ana',
            'apellido': 'López',
            'email': 'ana@pier.mx',
          },
        ),
      ),
      api: api,
    );

ElevatedButton _boton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

// El botón queda bajo el pliegue en la pantalla de prueba (800x600).
Future<void> _tocarGuardar(WidgetTester tester) async {
  final boton = find.text('Guardar cambios');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
}

void main() {
  group('EditProfileScreen', () {
    testWidgets('el botón se habilita al editar y las iniciales cambian',
        (tester) async {
      await _montar(tester, FakeApiClient());

      expect(find.text('AL'), findsOneWidget);
      expect(_boton(tester).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Ana'), 'Beto');
      await tester.pump();

      expect(find.text('BL'), findsOneWidget);
      expect(_boton(tester).onPressed, isNotNull);
    });

    testWidgets('al guardar con éxito muestra el aviso y se deshabilita',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          _endpoint: {
            'success': true,
            'user': {'nombre': 'Beto', 'apellido': 'López'},
          },
        },
      );
      await _montar(tester, api);
      await tester.enterText(find.widgetWithText(TextFormField, 'Ana'), 'Beto');
      await tester.pump();

      await _tocarGuardar(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Perfil actualizado'), findsOneWidget);
      expect(_boton(tester).onPressed, isNull);
    });

    testWidgets('si el backend falla muestra su mensaje', (tester) async {
      final api = FakeApiClient()..fallar(_endpoint, 'Token inválido');
      await _montar(tester, api);
      await tester.enterText(find.widgetWithText(TextFormField, 'Ana'), 'Beto');
      await tester.pump();

      await _tocarGuardar(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Token inválido'), findsOneWidget);
    });

    testWidgets('sin nombre no guarda', (tester) async {
      final api = FakeApiClient();
      await _montar(tester, api);
      await tester.enterText(find.widgetWithText(TextFormField, 'Ana'), '');
      await tester.pump();

      await _tocarGuardar(tester);
      await tester.pump();

      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(api.llamo(_endpoint, metodo: 'PUT-Auth'), isFalse);
    });
  });
}
