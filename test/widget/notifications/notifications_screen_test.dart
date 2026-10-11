// test/widget/notifications/notifications_screen_test.dart — la vista de
// «Notificaciones» pinta lo que expone su ViewModel (MVVM, Fase 5), marca
// como leídas y avisa los rechazos del backend, sin red. También el sondeo
// cada 2 minutos del NotificationProvider, con tiempo simulado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/notifications/view_model/notifications_view_model.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notificaciones_partes.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _leer1 = ApiConstants.marcarNotificacionLeida('1');

Map<String, dynamic> get _lista => {
      'success': true,
      'notificaciones': [
        {
          'id': 1,
          'tipo': 'pedido',
          'titulo': 'Tu pedido está listo',
          'mensaje': 'Pasa por él a la sucursal',
          'leida': false,
          'created_at': '2026-10-10T17:30:00',
        },
        {
          'id': 2,
          'tipo': 'promocion',
          'titulo': 'Temporada de fresas',
          'mensaje': '2x1 en pays',
          'leida': true,
          'created_at': '2026-10-01T12:00:00',
        },
      ],
    };

/// Pantalla de celular (412×869 lógicos, como el Note 10+).
void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

Future<(FakeApiClient, NotificationProvider)> _montar(
  WidgetTester tester, {
  Map<String, dynamic>? respuestas,
}) async {
  _celular(tester);
  final api = FakeApiClient(respuestas: {
    ApiConstants.notificaciones: _lista,
    _leer1: {'success': true},
    ApiConstants.notificacionesLeerTodas: {'success': true},
    ...?respuestas,
  });
  final provider =
      NotificationProvider(repo: NotificacionesRepositoryRemote(api: api));
  await tester.pumpApp(
    NotificationsScreen(
      viewModel: NotificationsViewModel(
        notificaciones: provider,
        ahora: () => DateTime(2026, 10, 10, 18),
      ),
    ),
    api: api,
  );
  await tester.pump();
  return (api, provider);
}

/// Pantalla de inicio de prueba que abre «Notificaciones» con push, como la
/// campana de inicio.
class _Inicio extends StatelessWidget {
  const _Inicio();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen()),
          ),
          child: const Text('Abrir'),
        ),
      );
}

Future<void> _abrirDesdeInicio(WidgetTester tester, FakeApiClient api) async {
  _celular(tester);
  await tester.pumpApp(const _Inicio(), api: api);
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NotificationsScreen', () {
    testWidgets('agrupa por día y muestra cuántas faltan por leer',
        (tester) async {
      await _montar(tester);

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // badge
      expect(find.text('Leer todas'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ayer'), findsNothing);
      expect(find.text('Anteriores'), findsOneWidget);
      expect(find.text('Tu pedido está listo'), findsOneWidget);
      expect(find.text('Hace 30 min'), findsOneWidget);
      expect(find.text('1 Oct 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('punto-no-leida')), findsOneWidget);
    });

    testWidgets('tocar una la marca como leída', (tester) async {
      final (api, _) = await _montar(tester);

      await tester.tap(find.text('Tu pedido está listo'));
      await tester.pumpAndSettle();

      expect(api.llamo(_leer1, metodo: 'PUT-Auth'), isTrue);
      expect(find.byKey(const ValueKey('punto-no-leida')), findsNothing);
      expect(find.text('Leer todas'), findsNothing);
    });

    testWidgets('si no se puede marcar avisa y la deja sin leer',
        (tester) async {
      await _montar(tester, respuestas: {
        _leer1: {'success': false, 'message': 'Error al marcar'},
      });

      await tester.tap(find.text('Tu pedido está listo'));
      await tester.pumpAndSettle();

      expect(find.text('Error al marcar'), findsOneWidget);
      expect(find.byKey(const ValueKey('punto-no-leida')), findsOneWidget);
    });

    testWidgets('«Leer todas» confirma y quita el badge', (tester) async {
      final (api, _) = await _montar(tester);

      await tester.tap(find.text('Leer todas'));
      await tester.pumpAndSettle();

      expect(find.text('Todas marcadas como leídas'), findsOneWidget);
      expect(find.text('Leer todas'), findsNothing);
      expect(api.llamo(ApiConstants.notificacionesLeerTodas), isTrue);
    });

    testWidgets('si «Leer todas» falla avisa el motivo', (tester) async {
      await _montar(tester, respuestas: {
        ApiConstants.notificacionesLeerTodas: {
          'success': false,
          'message': 'Error al marcar',
        },
      });

      await tester.tap(find.text('Leer todas'));
      await tester.pumpAndSettle();

      expect(find.text('Error al marcar'), findsOneWidget);
      expect(find.text('Todas marcadas como leídas'), findsNothing);
      expect(find.text('Leer todas'), findsOneWidget);
    });

    testWidgets('pull-to-refresh avisa si el backend no respondió',
        (tester) async {
      final (api, _) = await _montar(tester);
      api.fallar(ApiConstants.notificaciones, 'Sin conexión');

      // show() termina cuando termina el refresco: no se espera, se bombea.
      unawaited(tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show());
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Tu pedido está listo'), findsOneWidget);
    });

    testWidgets('mientras carga muestra el spinner', (tester) async {
      _celular(tester);
      final api = FakeApiClient(respuestas: {ApiConstants.notificaciones: _lista})
        ..demorar(ApiConstants.notificaciones, const Duration(seconds: 1));
      await tester.pumpApp(const NotificationsScreen(), api: api);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Tu pedido está listo'), findsOneWidget);
    });

    testWidgets('si no carga avisa y deja reintentar', (tester) async {
      final (api, _) = await _montar(tester, respuestas: {
        ApiConstants.notificaciones: {'success': false, 'message': 'Sin conexión'},
      });
      expect(find.text('Sin conexión'), findsOneWidget);

      api.responder(ApiConstants.notificaciones, _lista);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(find.text('Tu pedido está listo'), findsOneWidget);
    });

    testWidgets('vacía invita a explorar el menú y lleva al catálogo',
        (tester) async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.notificaciones: {'success': true, 'notificaciones': []},
      });
      await _abrirDesdeInicio(tester, api);

      expect(find.text('Sin notificaciones'), findsOneWidget);
      expect(find.text('Leer todas'), findsNothing);

      await tester.tap(find.text('Explorar Menú'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsNothing);
      expect(
          tester.element(find.byType(_Inicio)).read<NavigationProvider>()
              .selectedIndex,
          1);
    });

    testWidgets('la flecha regresa a la pantalla anterior', (tester) async {
      await _abrirDesdeInicio(tester, FakeApiClient(respuestas: {
        ApiConstants.notificaciones: _lista,
      }));

      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });
  });

  group('NotificationProvider: sondeo', () {
    testWidgets('consulta cada 2 minutos hasta cerrar sesión',
        (tester) async {
      final (api, provider) = await _montar(tester);
      int consultas() => api.llamadas
          .where((l) => l.endpoint == ApiConstants.notificaciones)
          .length;
      final antes = consultas();

      provider.startPolling();
      await tester.pump();
      expect(consultas(), antes + 1);

      await tester.pump(NotificationProvider.intervalo);
      expect(consultas(), antes + 2);

      provider.stopPolling();
      await tester.pump(NotificationProvider.intervalo);
      expect(consultas(), antes + 2);
      expect(find.text('Sin notificaciones'), findsOneWidget);
    });
  });

  test('ícono según el tipo de notificación', () {
    expect(NotificacionTarjeta.icono('pedido'), LucideIcons.shoppingBag);
    expect(NotificacionTarjeta.icono('promocion'), LucideIcons.tag);
    expect(NotificacionTarjeta.icono('resena'), Icons.star_outline_rounded);
    expect(NotificacionTarjeta.icono('reembolso'), LucideIcons.rotateCcw);
    expect(NotificacionTarjeta.icono('producto'), LucideIcons.cake);
    expect(NotificacionTarjeta.icono('aviso'), LucideIcons.bell);
  });
}
