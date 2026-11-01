// test/aceptacion/alexa/vincular_alexa_test.dart — escenarios Gherkin de
// «Vincular con Alexa»: generar el código de un solo uso con su vigencia y,
// cuando vence, generar otro (#68; historia #47), sin red.
//
// Con la sesión del cliente iniciada, la prueba entra a la pantalla como
// desde «Más» (la pantalla arma su ViewModel con el CuentaRepository de
// dependencies.dart), contra un backend falso que entrega un código
// distinto en cada POST /auth/alexa/generar-codigo. La vigencia corre con el
// reloj de la prueba (tester.pump), así que no depende de la hora ni del
// huso de la máquina.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/more/widgets/vincular_alexa_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Backend falso: el login del cliente y, por cada petición, el siguiente
/// código de [codigos] (código, segundos de vigencia).
FakeApiClient _backend(List<(String, int)> codigos) {
  var siguiente = 0;
  return FakeApiClient(
    respuestas: {
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {
          'id': 1,
          'nombre': 'Ana',
          'email': 'ana@pier.mx',
          'rol': 'cliente',
        },
      },
      ApiConstants.alexaGenerarCodigo: (LlamadaApi _) {
        final (codigo, segundos) = codigos[siguiente++];
        return <String, dynamic>{
          'success': true,
          'codigo': codigo,
          'expira_en_segundos': segundos,
        };
      },
    },
  );
}

/// Página de partida: la opción «Vincular con Alexa» de «Más», que abre la
/// pantalla sin ViewModel inyectado, como la app.
class _Mas extends StatelessWidget {
  const _Mas();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const VincularAlexaScreen()),
        ),
        child: const Text('Vincular con Alexa'),
      ),
    ),
  );
}

/// Dado que inicié sesión: monta «Más» y abre la sesión del cliente con el
/// login del backend falso.
Future<void> _iniciarSesion(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(const _Mas(), api: api);
  await tester.iniciarSesion(find.byType(_Mas));
  await tester.pump();
  expect(
    tester.element(find.byType(_Mas)).read<AuthProvider>().isAuthenticated,
    isTrue,
  );
}

/// Entra a «Vincular con Alexa» desde «Más».
Future<void> _abrirVincular(WidgetTester tester) async {
  await tester.tap(find.text('Vincular con Alexa'));
  await tester.pumpAndSettle();
}

/// Pide un código. Sin pumpAndSettle: con un código vigente la cuenta
/// regresiva avisa cada segundo y lo dejaría vencer.
Future<void> _generar(WidgetTester tester) async {
  await tester.tap(find.text('Generar código de vinculación'));
  await tester.pump();
}

/// La vigencia que muestra la tarjeta del código.
Finder _vigencia(String tiempo) =>
    find.text('Expira en $tiempo · un solo uso');

void main() {
  group('#47 Alexa: vincular la cuenta mediante un código', () {
    // Escenario: generar el código
    //   Dado que inicié sesión
    //   Cuando pido un código de vinculación
    //   Entonces la app muestra el código y el tiempo que le queda de
    //   vigencia
    testWidgets('Escenario: generar el código', (tester) async {
      // Dado que inicié sesión
      final api = _backend([('482913', 300)]);
      await _iniciarSesion(tester, api);
      await _abrirVincular(tester);

      // Cuando pido un código de vinculación
      await _generar(tester);

      // Entonces la app muestra el código y el tiempo que le queda de
      // vigencia
      final peticion = api.ultima(ApiConstants.alexaGenerarCodigo)!;
      expect(peticion.metodo, 'POST-Auth');
      expect(peticion.body, isEmpty);
      expect(find.text('TU CÓDIGO DE VINCULACIÓN'), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);
      expect(_vigencia('5:00'), findsOneWidget);
      expect(
        find.text('Dile: "vincula mi cuenta con el código 4 8 2 9 1 3"'),
        findsOneWidget,
      );
      expect(find.text('Generar código de vinculación'), findsNothing);
      // La vigencia baja cada segundo.
      await tester.pump(const Duration(seconds: 1));
      expect(_vigencia('4:59'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(_vigencia('3:59'), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);
    });

    // Escenario: código vencido
    //   Dado que el tiempo de vigencia del código llegó a cero
    //   Cuando vuelvo a la pantalla
    //   Entonces puedo generar un código nuevo
    testWidgets('Escenario: código vencido', (tester) async {
      final api = _backend([('482913', 3), ('615204', 300)]);
      await _iniciarSesion(tester, api);
      await _abrirVincular(tester);
      await _generar(tester);
      expect(find.text('482913'), findsOneWidget);
      expect(_vigencia('0:03'), findsOneWidget);

      // Dado que el tiempo de vigencia del código llegó a cero
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      // El código vencido deja de mostrarse (ya no sirve para dictárselo a
      // Alexa) y el botón regresa ahí mismo, sin salir de la pantalla.
      expect(find.text('482913'), findsNothing);
      expect(find.text('TU CÓDIGO DE VINCULACIÓN'), findsNothing);
      expect(find.text('Generar código de vinculación'), findsOneWidget);

      // Cuando vuelvo a la pantalla
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _abrirVincular(tester);

      // Entonces puedo generar un código nuevo
      expect(find.text('482913'), findsNothing);
      await _generar(tester);
      expect(find.text('615204'), findsOneWidget);
      expect(_vigencia('5:00'), findsOneWidget);
      expect(
        api.llamadas.where((l) => l.endpoint == ApiConstants.alexaGenerarCodigo),
        hasLength(2),
      );
    });
  });
}
