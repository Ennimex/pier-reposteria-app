// test/widget/comandas/detalle_comanda_screen_test.dart — detalle de una
// comanda para producción y «Enterado» (#128) sin red: lo que hay que hacer
// sin montos, confirmar con diálogo, la comanda cambió mientras se leía, ya
// la confirmó un compañero, volver a firmar, fotos a pantalla completa y
// abrir el detalle desde la agenda.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/agenda_comandas_screen.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/detalle_comanda_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

const _detalle = '/comandas/7';
const _confirmar = '/comandas/7/confirmar';

final Map<String, dynamic> _firmaHornos = firmaJson(
  vigente: true,
  version: 1,
  usuario: 'Rosa Pérez',
  fecha: 'f',
);

/// Monta [pantalla] con sesión de [rol] dentro de un router con login.
Future<void> _montar(
  WidgetTester tester,
  FakeApiClient api, {
  Widget pantalla = const DetalleComandaScreen(id: 7),
  String rol = 'hornos',
}) async {
  tester.view
    ..physicalSize = const Size(1080, 7200)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  final mensajero = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(google, (_) async => null);
  addTearDown(() => mensajero.setMockMethodCallHandler(google, null));
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: AppRoutes.produccion,
    routes: [
      GoRoute(path: AppRoutes.produccion, builder: (_, _) => pantalla),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  final listo = ValueNotifier(false);
  late BuildContext contexto;
  await tester.pumpWidget(
    MultiProvider(
      providers: dependencias(api),
      child: ValueListenableBuilder<bool>(
        valueListenable: listo,
        builder: (context, montar, _) {
          contexto = context;
          return montar
              ? MaterialApp.router(routerConfig: router)
              : const SizedBox();
        },
      ),
    ),
  );
  contexto.read<AuthProvider>().abrirSesion({
    'id': 1,
    'nombre': 'Rosa',
    'rol': rol,
  });
  listo.value = true;
  await tester.pumpAndSettle();
}

Future<void> _tocarEnterado(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Enterado'));
  await tester.pumpAndSettle();
}

void main() {
  group('DetalleComandaScreen', () {
    testWidgets('muestra lo que hay que hacer, sin montos', (tester) async {
      final api = FakeApiClient()..responder(_detalle, detalleJson());
      await _montar(tester, api);

      expect(find.text('Comanda #5003'), findsOneWidget);
      expect(find.text('Muy pronto'), findsOneWidget);
      expect(find.textContaining('Faltan 2 días'), findsOneWidget);
      expect(find.text('Pastel de chocolate'), findsOneWidget);
      expect(find.text('Feliz cumpleaños Ana'), findsOneWidget);
      expect(find.text('Chocolate'), findsOneWidget);
      expect(find.text('2 pisos'), findsOneWidget);
      expect(find.text('Flores naturales'), findsOneWidget);
      expect(
        find.text('Sin especificar'),
        findsOneWidget,
        reason: 'pared o fondo sin indicar',
      );
      expect(find.text('Tart Bites 24 piezas'), findsOneWidget);
      expect(find.text('× 2 · grande'), findsOneWidget);
      expect(find.text('Sin azúcar glass'), findsOneWidget);
      expect(find.text('Dorado'), findsOneWidget);
      expect(find.text('Entregar en salón Las Palmas'), findsOneWidget);
      expect(find.text('María López'), findsOneWidget);
      expect(find.text('Tomó la comanda: Laura Cruz'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('Enterado: diálogo, Volver no confirma', (tester) async {
      final api = FakeApiClient()..responder(_detalle, detalleJson());
      await _montar(tester, api);

      expect(find.text('Al terminar de leerla, confirma'), findsOneWidget);
      await _tocarEnterado(tester);
      expect(find.text('¿Confirmas de enterado?'), findsOneWidget);
      expect(
        find.textContaining('Confirmo que leí la comanda #5003 (versión 1)'),
        findsOneWidget,
      );
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(api.llamo(_confirmar), isFalse);
    });

    testWidgets('Enterado: confirma, avisa y muestra mi firma', (tester) async {
      final api = FakeApiClient()
        ..responder(_detalle, detalleJson())
        ..responder(_confirmar, {
          'success': true,
          'confirmacion': {'area': 'hornos', 'version': 1},
          'message': 'Enterado registrado',
        });
      await _montar(tester, api);

      await _tocarEnterado(tester);
      api.responder(
        _detalle,
        detalleJson(confirmar: null, hornos: _firmaHornos),
      );
      await tester.tap(find.text('Sí, enterado'));
      await tester.pumpAndSettle();

      expect(api.ultima(_confirmar)!.body, {'version': 1});
      expect(find.text('Enterado registrado'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Enterado'), findsNothing);
      expect(find.text('Rosa Pérez'), findsOneWidget);
    });

    testWidgets('la comanda cambió mientras la leía: muestra qué cambió', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(_detalle, detalleJson())
        ..responder(_confirmar, {
          'success': false,
          'codigo': 'VERSION_DESACTUALIZADA',
          'version_actual': 2,
          'message':
              'La comanda cambió. Revisa los cambios antes de confirmar.',
        });
      await _montar(tester, api);

      await _tocarEnterado(tester);
      api.responder(
        _detalle,
        detalleJson(
          version: 2,
          historial: [
            eventoJson(
              cambios: [cambioJson('Hora de entrega', '10:00', '11:00')],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Sí, enterado'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta comanda cambió mientras la veías'),
        findsOneWidget,
      );
      expect(find.text('Hora de entrega: 10:00 → 11:00'), findsOneWidget);
      expect(
        find.text('La comanda cambió. Revisa los cambios antes de confirmar.'),
        findsOneWidget,
      );

      await _tocarEnterado(tester);
      expect(find.text('Confirmas también este cambio:'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ocultar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Esta comanda cambió mientras la veías'), findsNothing);
    });

    testWidgets('ya la confirmó un compañero: lo avisa y muestra su firma', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(_detalle, detalleJson())
        ..responder(_confirmar, {
          'success': false,
          'codigo': 'YA_CONFIRMADA',
          'message': 'Esta versión ya la confirmó Rosa Pérez (Hornos).',
        });
      await _montar(tester, api);

      await _tocarEnterado(tester);
      api.responder(
        _detalle,
        detalleJson(confirmar: null, hornos: _firmaHornos),
      );
      await tester.tap(find.text('Sí, enterado'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta versión ya la confirmó Rosa Pérez (Hornos).'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Enterado'), findsNothing);
    });

    testWidgets('otro error al confirmar: lo avisa y deja reintentar', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(_detalle, detalleJson())
        ..fallar(_confirmar, 'Error al registrar el enterado');
      await _montar(tester, api);

      await _tocarEnterado(tester);
      await tester.tap(find.text('Sí, enterado'));
      await tester.pumpAndSettle();

      expect(find.text('Error al registrar el enterado'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Enterado'), findsOneWidget);
    });

    testWidgets('volver a firmar: qué cambió desde mi última confirmación', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(
          _detalle,
          detalleJson(
            version: 2,
            hornos: firmaJson(version: 1, usuario: 'Rosa Pérez'),
            cambiosPendientes: [
              cambioJson('Pastel 1 · Sabor', 'Vainilla', 'Chocolate'),
            ],
          ),
        );
      await _montar(tester, api);

      expect(
        find.text('Qué cambió desde tu última confirmación'),
        findsOneWidget,
      );
      expect(
        find.text('Pastel 1 · Sabor: Vainilla → Chocolate'),
        findsOneWidget,
      );
      expect(
        find.text('Cambió: revisa los cambios y vuelve a confirmar'),
        findsOneWidget,
      );
    });

    testWidgets('comanda cancelada: aviso con el motivo y sin Enterado', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(
          _detalle,
          detalleJson(
            estado: 'cancelada',
            semaforo: null,
            confirmar: null,
            motivoCancelacion: 'El cliente ya no lo quiere',
          ),
        );
      await _montar(tester, api);

      expect(
        find.text('Comanda cancelada: El cliente ya no lo quiere'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Enterado'), findsNothing);
    });

    testWidgets('tocar una foto la abre a pantalla completa', (tester) async {
      final api = FakeApiClient()
        ..responder(
          _detalle,
          detalleJson(
            imagenes: [
              'https://res.cloudinary.com/a.webp',
              'https://res.cloudinary.com/b.webp',
            ],
          ),
        );
      await _montar(tester, api);

      expect(find.text('Imágenes de referencia (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('foto-1')));
      await tester.pumpAndSettle();

      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsNothing);
    });

    testWidgets('error al abrir: mensaje y Reintentar', (tester) async {
      final api = FakeApiClient()..fallar(_detalle, 'Comanda no encontrada');
      await _montar(tester, api);

      expect(find.text('No pudimos abrir la comanda'), findsOneWidget);
      expect(find.text('Comanda no encontrada'), findsOneWidget);
      api.responder(_detalle, detalleJson());
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Pastel de chocolate'), findsOneWidget);
    });

    testWidgets('cuenta desactivada: cierra la sesión y vuelve al login', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(_detalle, {
          'success': false,
          'codigo': 'SESION_INVALIDA',
          'message': 'Tu cuenta está desactivada o cambió.',
        })
        ..responder('/auth/logout', {'success': true});
      await _montar(tester, api);

      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('Tu cuenta está desactivada o cambió.'), findsOneWidget);
    });

    testWidgets('desde la agenda: tocar la tarjeta abre el detalle y al volver '
        'se actualiza', (tester) async {
      final api = FakeApiClient()
        ..responder(
          '/comandas?vista=proximas',
          agendaJson([comandaJson(id: 7, folio: 5003, hornos: _firmaHornos)]),
        )
        ..responder('/comandas?vista=activas', agendaJson(const []))
        ..responder(
          _detalle,
          detalleJson(confirmar: null, hornos: _firmaHornos),
        );
      await _montar(tester, api, pantalla: const AgendaComandasScreen());

      await tester.tap(find.text('#5003'));
      await tester.pumpAndSettle();
      expect(find.text('Comanda #5003'), findsOneWidget);

      api.llamadas.clear();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(api.llamo('/comandas?vista=proximas'), isTrue);
    });
  });
}
