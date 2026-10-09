// test/widget/public/contact_screen_test.dart — la vista de «Contacto»
// refleja su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/ui/public/view_model/contact_view_model.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const String _mensaje = 'Quiero un pastel de 3 pisos';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    ContactScreen(
      viewModel: ContactViewModel(
        configRepo: ConfiguracionRepository(api: api),
        cuentaRepo: CuentaRepository(api: api),
      ),
    ),
    api: api,
  );
  await tester.pump();
}

/// Llena nombre, correo y mensaje (sin sesión los campos son editables).
Future<void> _llenar(WidgetTester tester) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), 'Ana López');
  await tester.enterText(campos.at(1), 'ana@pier.mx');
  await tester.enterText(campos.at(3), _mensaje);
  await tester.pump();
}

Future<void> _tocarEnviar(WidgetTester tester) async {
  final boton = find.text('Enviar Mensaje');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ContactScreen', () {
    testWidgets('pinta el teléfono del panel y el contador del mensaje',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.configuracionSeccion('contacto'): {
            'success': true,
            'config': {'telefono': '771 555 0000'},
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('771 555 0000'), findsOneWidget);
      expect(find.text('0 / mín. 20'), findsOneWidget);
      await _llenar(tester);
      expect(find.text('${_mensaje.length} / mín. 20'), findsOneWidget);
    });

    testWidgets('un horario largo del panel no se sale del recuadro',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.configuracionSeccion('contacto'): {
            'success': true,
            'config': {
              'horarios': [
                {
                  'sucursal': 'Sucursal Centro Huejutla',
                  'horario': 'Lunes a sábado de 9:00 a 21:00 hrs, domingo cerrado',
                },
                {
                  'sucursal': 'Sucursal Parque Poniente',
                  'horario': 'Lunes a domingo de 10:00 a 20:00 hrs',
                },
              ],
            },
          },
        },
      );
      await _montar(tester, api);
      await tester.ensureVisible(find.text('Horario de atención'));
      await tester.pump();

      // Un RenderFlex desbordado se reporta como excepción de la prueba.
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Sucursal Parque Poniente'),
        findsOneWidget,
      );
    });

    testWidgets('enviar muestra el diálogo y limpia el mensaje',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.enviarContacto: {'success': true},
        },
      );
      await _montar(tester, api);
      await _llenar(tester);

      await _tocarEnviar(tester);

      expect(find.text('¡Mensaje enviado!'), findsOneWidget);
      expect(find.text('0 / mín. 20'), findsOneWidget);
      expect(
        api.llamo(ApiConstants.enviarContacto, metodo: 'POST'),
        isTrue,
      );
    });

    testWidgets('si el backend falla muestra su mensaje', (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.enviarContacto, 'Demasiados mensajes');
      await _montar(tester, api);
      await _llenar(tester);

      await _tocarEnviar(tester);

      expect(find.text('Demasiados mensajes'), findsOneWidget);
      expect(find.text('¡Mensaje enviado!'), findsNothing);
    });
  });
}
