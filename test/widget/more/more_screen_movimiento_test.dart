// test/widget/more/more_screen_movimiento_test.dart — movimiento de la
// pestaña «Más»: la cascada de la primera visita (oculta no deja entradas
// pendientes; al verse, las secciones suben en orden y una sola vez) y la
// caja de carga de «Encuéntranos», que se funde en su lugar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/more_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/more_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

final String _contacto = ApiConstants.configuracionSeccion('contacto');

FakeApiClient _api() => FakeApiClient(
  respuestas: {
    _contacto: {
      'success': true,
      'config': {'telefono': '921 000 0000', 'direccion': 'Av. Central 1'},
    },
  },
);

MoreScreen _pantalla(FakeApiClient api) => MoreScreen(
  viewModel: MoreViewModel(
    configRepo: ConfiguracionRepositoryRemote(api: api),
    pedidosRepo: PedidosRepositoryRemote(api: api),
    favoritosRepo: FavoritosRepositoryRemote(api: api),
    resenasRepo: ResenasRepositoryRemote(api: api),
  ),
);

void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

/// «Más» dentro de un TickerMode que la prueba enciende, como la pestaña
/// oculta del MainScreen (arranca apagado).
Future<ValueNotifier<bool>> _montarOculta(WidgetTester tester) async {
  _celular(tester);
  final aLaVista = ValueNotifier<bool>(false);
  addTearDown(aLaVista.dispose);
  final api = _api();
  await tester.pumpApp(
    ValueListenableBuilder<bool>(
      valueListenable: aLaVista,
      builder: (context, visible, pantalla) =>
          TickerMode(enabled: visible, child: pantalla!),
      child: _pantalla(api),
    ),
    api: api,
  );
  await tester.pump();
  return aLaVista;
}

Finder _seccion(String id) => find.byKey(ValueKey<String>(id));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MoreScreen — primera visita', () {
    testWidgets('oculta no monta entradas pendientes', (tester) async {
      await _montarOculta(tester);

      expect(find.text('Encuéntranos'), findsOneWidget);
      expect(find.byType(EntradaSuave, skipOffstage: false), findsNothing);
    });

    testWidgets('al verse, las secciones suben en orden y una sola vez', (
      tester,
    ) async {
      final aLaVista = await _montarOculta(tester);

      aLaVista.value = true;
      await tester.pump(); // se envuelven en ese mismo cuadro
      expect(opacidadEn(tester, _seccion('encuentranos')), 0);

      await tester.pump(); // primer tick
      await tester.pump(const Duration(milliseconds: 200));
      // En orden de arriba hacia abajo: «Encuéntranos» ya aparece y la
      // tarjeta de «Mi Cuenta» todavía espera su escalón.
      expect(opacidadEn(tester, _seccion('encuentranos')), greaterThan(0));
      expect(opacidadEn(tester, _seccion('mi-cuenta-opciones')), 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(opacidadEn(tester, _seccion('encuentranos')), 1);
      expect(opacidadEn(tester, _seccion('mi-cuenta-opciones')), 1);

      // Ocultarla y volver a mostrarla no repite la cascada.
      aLaVista.value = false;
      await tester.pump();
      aLaVista.value = true;
      await tester.pump();
      expect(opacidadEn(tester, _seccion('encuentranos')), 1);
      expect(opacidadEn(tester, _seccion('mi-cuenta-opciones')), 1);
    });
  });

  testWidgets('la caja de carga del contacto se apaga en su lugar', (
    tester,
  ) async {
    _celular(tester);
    final api = _api()..demorar(_contacto, const Duration(seconds: 1));
    await tester.pumpApp(_pantalla(api), api: api);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // cascada terminada

    final caja = find.byKey(const ValueKey<String>('cargando'));
    final arriba = tester.getTopLeft(caja).dy;

    await tester.pump(const Duration(milliseconds: 400)); // llega el contacto
    // La tarjeta entra encima y la caja sale sin moverse (centrada en la
    // tarjeta, bajaría fuera del recorte del espacio que crece).
    expect(find.byKey(const ValueKey<String>('contacto')), findsOneWidget);
    expect(caja, findsOneWidget);
    expect(tester.getTopLeft(caja).dy, arriba);

    await tester.pump(const Duration(milliseconds: 400));
    expect(caja, findsNothing);
    expect(find.textContaining('921 000 0000'), findsWidgets);
  });
}
