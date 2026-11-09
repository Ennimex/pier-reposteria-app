// test/widget/more/more_screen_test.dart — la pestaña «Más» pinta lo que
// expone su ViewModel (MVVM, Fase 3), sin red. Sin sesión guardada: invitado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/ui/more/view_model/more_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/more_screen.dart';
import 'package:pier_reposteria/ui/more/widgets/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// [aLaVista]: si se da, la pantalla está en una pestaña que se ve o no
/// (TickerMode), como en MainScreen.
Future<void> _montar(
  WidgetTester tester,
  FakeApiClient api, {
  ValueNotifier<bool>? aLaVista,
}) async {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final pantalla = MoreScreen(
    viewModel: MoreViewModel(
      configRepo: ConfiguracionRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
      favoritosRepo: FavoritosRepositoryRemote(api: api),
      resenasRepo: ResenasRepositoryRemote(api: api),
    ),
  );
  await tester.pumpApp(
    aLaVista == null
        ? pantalla
        : ValueListenableBuilder<bool>(
            valueListenable: aLaVista,
            builder: (_, visible, hijo) =>
                TickerMode(enabled: visible, child: hijo!),
            child: pantalla,
          ),
    api: api,
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MoreScreen (con sesión, #345)', () {
    testWidgets('la cabecera no tiene foto de fondo y toda la franja lleva '
        'a «Mi perfil»', (tester) async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.login: {
          'success': true,
          'token': 'jwt',
          'user': {
            'id': 9,
            'nombre': 'Ana',
            'apellido': 'García',
            'email': 'ana@pier.mx',
            'rol': 'cliente',
          },
        },
      });
      await _montar(tester, api);
      await tester.iniciarSesion(find.byType(MoreScreen));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Sin foto: las iniciales, el nombre y «Mi perfil»; ya no el correo.
      expect(find.text('AG'), findsOneWidget);
      expect(find.text('Mi perfil'), findsOneWidget);
      expect(find.text('ana@pier.mx'), findsNothing);
      expect(
        find.byWidgetPredicate(
            (w) => w is Image && w.image is NetworkImage),
        findsNothing,
      );

      // El nombre (no solo un botón chico) abre «Mi perfil».
      await tester.tap(find.text('Ana'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  group('MoreScreen (invitado)', () {
    testWidgets('pinta el contacto del backend y no muestra contadores',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.configuracionSeccion('contacto'): {
            'success': true,
            'config': {
              'telefono': '921 000 0000',
              'direccion': 'Av. Siempre Viva 742',
            },
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('Encuéntranos'), findsOneWidget);
      expect(find.textContaining('921 000 0000'), findsWidgets);
      expect(find.textContaining('Av. Siempre Viva 742'), findsWidgets);
      expect(find.text('Acceso requerido'), findsOneWidget);
      expect(find.text('Pedidos'), findsNothing);
      expect(api.llamo(ApiConstants.misPedidos), isFalse);
    });

    testWidgets('si el contacto falla usa los datos de BusinessInfo',
        (tester) async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.configuracionSeccion('contacto'), 'Caído');
      await _montar(tester, api);

      expect(find.textContaining(BusinessInfo.telefono), findsWidgets);
    });

    // #312: sin red al abrir, «Encuéntranos» mostraba un teléfono de relleno
    // (771 123 4567) y no se actualizaba al volver la red.
    testWidgets('sin red no muestra el teléfono de relleno y al volver a la '
        'pestaña con red se actualiza', (tester) async {
      final contacto = ApiConstants.configuracionSeccion('contacto');
      final api = FakeApiClient()..fallar(contacto, 'Sin conexión');
      final aLaVista = ValueNotifier(true);
      addTearDown(aLaVista.dispose);
      await _montar(tester, api, aLaVista: aLaVista);

      expect(find.textContaining('771 123 4567'), findsNothing);
      expect(find.textContaining('789 896 5413'), findsWidgets);

      // Vuelve la red; se va a otra pestaña y regresa a «Más».
      api.responder(contacto, {
        'success': true,
        'config': {'telefono': '921 000 0000'},
      });
      aLaVista.value = false;
      await tester.pump();
      aLaVista.value = true;
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('921 000 0000'), findsWidgets);
    }, tags: 'regresion');
  });
}
