// test/widget/comandas/agenda_comandas_screen_test.dart — agenda de comandas
// de producción (#127) sin red: agrupada por día y sin montos, pendientes
// del área, vistas, búsqueda, estados vacío y de error, actualización al
// volver a la app y cierre de sesión (manual o porque la cuenta cambió).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/agenda_comandas_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

const _proximas = '/comandas?vista=proximas';
const _activas = '/comandas?vista=activas';

final Map<String, dynamic> _firmada = firmaJson(
  vigente: true,
  version: 1,
  usuario: 'Rosa Pérez',
);

FakeApiClient _backend() => FakeApiClient()
  ..responder(
    _proximas,
    agendaJson([
      comandaJson(
        fecha: '2026-10-12',
        dias: 0,
        hora: '16:00',
        semaforo: 'rojo',
        imagenes: 2,
      ),
      comandaJson(
        id: 2,
        folio: 5002,
        cliente: 'Juan Ruiz',
        hornos: _firmada,
        decoracion: firmaJson(version: 1, usuario: 'Leo'),
      ),
    ]),
  )
  ..responder(
    _activas,
    agendaJson([
      comandaJson(fecha: '2026-10-12', dias: 0, cliente: 'Ana'),
      comandaJson(id: 2, folio: 5002, hornos: _firmada, cliente: 'Beto'),
      comandaJson(id: 3, folio: 5003, dias: 5, cliente: 'Carla'),
      comandaJson(id: 4, folio: 5004, dias: 6, cliente: 'Dora'),
      comandaJson(id: 5, folio: 5005, dias: 7, cliente: 'Eva'),
    ]),
  )
  ..responder('/auth/logout', {'success': true});

/// Monta la agenda con sesión de [rol] dentro de un router con login.
Future<void> _montar(
  WidgetTester tester,
  FakeApiClient api, {
  String rol = 'hornos',
}) async {
  tester.view
    ..physicalSize = const Size(1080, 6000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Sin plugin de Google en pruebas: su signOut (al cerrar sesión) responde
  // al instante.
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  final mensajero = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(google, (_) async => null);
  addTearDown(() => mensajero.setMockMethodCallHandler(google, null));
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: AppRoutes.produccion,
    routes: [
      GoRoute(
        path: AppRoutes.produccion,
        builder: (_, _) => const AgendaComandasScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  // La sesión se abre fuera del build; luego se monta el router.
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

void main() {
  group('AgendaComandasScreen', () {
    testWidgets(
      'agrupa por día con folio, hora, urgencia y firmas, sin montos',
      (tester) async {
        await _montar(tester, _backend());

        expect(find.text('Comandas · Hornos'), findsOneWidget);
        expect(find.text('Hoy · lunes 12 de octubre'), findsOneWidget);
        expect(find.text('Miércoles 14 de octubre'), findsOneWidget);
        expect(find.text('#5001'), findsWidgets);
        expect(find.text('4:00 p. m.'), findsOneWidget);
        expect(find.text('Urgente'), findsOneWidget);
        expect(find.text('María López'), findsOneWidget);
        expect(find.text('Hornos: confirmó'), findsOneWidget);
        expect(find.text('Decoración: falta re-confirmar'), findsOneWidget);
        expect(find.text('2 fotos'), findsOneWidget);
        expect(find.textContaining(r'$'), findsNothing);
      },
    );

    testWidgets('pendientes de mi área: las 3 más urgentes y «Ver las N»', (
      tester,
    ) async {
      await _montar(tester, _backend());

      expect(find.text('Pendientes de tu confirmación (4)'), findsOneWidget);
      expect(find.text('#5005'), findsNothing);
      await tester.tap(find.text('Ver las 4 pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('#5005'), findsOneWidget);
      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();
      expect(find.text('#5005'), findsNothing);
    });

    testWidgets('mi área al día: lo dice en lugar de la lista', (tester) async {
      final api = _backend()
        ..responder(_activas, agendaJson([comandaJson(hornos: _firmada)]));
      await _montar(tester, api);

      expect(find.text('Tu área está al día'), findsOneWidget);
    });

    testWidgets('cambiar de vista consulta esa vista', (tester) async {
      final api = _backend()
        ..responder(
          '/comandas?vista=canceladas',
          agendaJson([
            comandaJson(
              folio: 5009,
              estado: 'cancelada',
              semaforo: null,
              canceladaAt: '2026-10-11T20:00:00.000Z',
            ),
          ]),
        );
      await _montar(tester, api);

      await tester.ensureVisible(find.text('Canceladas'));
      await tester.tap(find.text('Canceladas'));
      await tester.pumpAndSettle();

      expect(api.llamo('/comandas?vista=canceladas'), isTrue);
      expect(find.text('#5009'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
    });

    testWidgets('buscar espera a que termine de escribir', (tester) async {
      final api = _backend()
        ..responder(
          '/comandas?vista=proximas&busqueda=Juan',
          agendaJson([comandaJson(folio: 5002, cliente: 'Juan Ruiz')]),
        );
      await _montar(tester, api);

      await tester.enterText(find.byType(TextField), 'Juan');
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.llamo('/comandas?vista=proximas&busqueda=Juan'), isFalse);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(api.llamo('/comandas?vista=proximas&busqueda=Juan'), isTrue);
      expect(find.text('María López'), findsNothing);
    });

    testWidgets('sin resultados de la búsqueda', (tester) async {
      final api = _backend()
        ..responder(
          '/comandas?vista=proximas&busqueda=Zoe',
          agendaJson(const []),
        );
      await _montar(tester, api);

      await tester.enterText(find.byType(TextField), 'Zoe');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('Sin resultados para «Zoe»'), findsOneWidget);
    });

    testWidgets('vista vacía', (tester) async {
      final api = _backend()..responder(_proximas, agendaJson(const []));
      await _montar(tester, api);

      expect(find.text('No hay comandas en esta vista'), findsOneWidget);
    });

    testWidgets('error al cargar: mensaje y Reintentar', (tester) async {
      final api = _backend()
        ..fallar(_proximas, 'Error al obtener las comandas');
      await _montar(tester, api);

      expect(find.text('No pudimos cargar las comandas'), findsOneWidget);
      expect(find.text('Error al obtener las comandas'), findsOneWidget);

      api.responder(_proximas, agendaJson([comandaJson(folio: 5007)]));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('#5007'), findsWidgets);
    });

    testWidgets('si falla al actualizar conserva la lista y avisa', (
      tester,
    ) async {
      final api = _backend();
      await _montar(tester, api);
      api
        ..fallar(_proximas, 'Sin conexión')
        ..llamadas.clear();

      // Jalar hacia abajo (largo: la pantalla de prueba es muy alta).
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();

      expect(api.llamo(_proximas), isTrue);

      expect(find.text('María López'), findsOneWidget);
      expect(find.text('No se pudo actualizar: Sin conexión'), findsOneWidget);
    });

    testWidgets('al volver a la app vuelve a consultar', (tester) async {
      final api = _backend();
      await _montar(tester, api);
      api.llamadas.clear();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(api.llamo(_proximas), isTrue);
    });

    testWidgets('cuenta desactivada: cierra la sesión y vuelve al login', (
      tester,
    ) async {
      final api = _backend()
        ..responder(_proximas, {
          'success': false,
          'codigo': 'SESION_INVALIDA',
          'message': 'Tu cuenta está desactivada o cambió.',
        });
      await _montar(tester, api);

      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('Tu cuenta está desactivada o cambió.'), findsOneWidget);
      expect(api.llamo('/auth/logout'), isTrue);
    });

    testWidgets('cerrar sesión desde el menú', (tester) async {
      final api = _backend();
      await _montar(tester, api);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir sitio web'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
      expect(api.llamo('/auth/logout'), isTrue);
    });

    testWidgets('decoración ve su área en el título', (tester) async {
      await _montar(tester, _backend(), rol: 'decoracion');

      expect(find.text('Comandas · Decoración'), findsOneWidget);
      expect(find.text('Pendientes de tu confirmación (5)'), findsOneWidget);
    });
  });
}
