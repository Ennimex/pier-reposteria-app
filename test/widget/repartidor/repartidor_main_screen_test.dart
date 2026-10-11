// test/widget/repartidor/repartidor_main_screen_test.dart — el panel del
// repartidor (MVVM, Fase 5) sin red: sus pestañas Entregas, Historial y
// Perfil pintan lo que expone RepartidorViewModel, toman pedidos, cambian la
// disponibilidad y cierran sesión.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_main_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const Map<String, Object> _usuario = {
  'id': 9,
  'nombre': 'Luis',
  'apellido': 'Hernández',
  'email': 'luis@pier.mx',
  'telefono': '7711234567',
  'rol': 'repartidor',
};

Map<String, dynamic> _entrega(String id, String estado,
        {num total = 100, String? pago, String? finalizado}) =>
    {
      'id': id,
      'estado': estado,
      'numero': 'PIER-$id',
      'total': total,
      'metodo_pago': pago,
      'cliente_nombre': 'Cliente',
      'cliente_apellido': id,
      'horario_entrega': '2026-10-10T09:00:00',
      'finalizado_at': finalizado,
      'direccion_entrega': {'colonia': 'Colonia $id'},
    };

FakeApiClient _backend({
  List<Map<String, dynamic>>? entregas,
  List<Map<String, dynamic>>? pool,
  bool disponible = true,
}) =>
    FakeApiClient(respuestas: {
      ApiConstants.login: {'success': true, 'token': 'jwt', 'user': _usuario},
      ApiConstants.misEntregas: {
        'success': true,
        'entregas': entregas ??
            [
              _entrega('1', 'asignada', pago: 'efectivo'),
              _entrega('2', 'en_camino', total: 1250, pago: 'tarjeta'),
              _entrega('3', 'entregada',
                  total: 250, finalizado: '2026-10-10T15:30:00'),
              _entrega('4', 'fallida'),
            ],
      },
      ApiConstants.disponibilidad: {
        'success': true,
        'disponible': disponible,
      },
      ApiConstants.entregasDisponibles: {
        'success': true,
        'pedidos': pool ??
            [
              {
                'pedido_id': 41,
                'numero': 'PIER-41',
                'total': 300,
                'cliente_nombre': 'Ana',
                'cliente_apellido': 'López',
                'horario_entrega': '2026-10-10T11:00:00',
                'direccion_entrega': {'colonia': 'Aviación'},
              },
            ],
      },
    });

Future<FakeApiClient> _montar(
  WidgetTester tester, {
  FakeApiClient? api,
  RepartidorViewModel? viewModel,
}) async {
  // Pantalla de celular (412×869 lógicos, como el Note 10+).
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final backend = api ?? _backend();
  await tester.pumpApp(RepartidorMainScreen(viewModel: viewModel),
      api: backend);
  await tester.iniciarSesion(find.byType(RepartidorMainScreen));
  await tester.pump();
  await tester.pump();
  return backend;
}

Future<void> _irA(WidgetTester tester, String pestana) async {
  await tester.tap(find.text(pestana).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('RepartidorMainScreen: Entregas', () {
    testWidgets('pinta disponibilidad, el pool y las entregas en curso',
        (tester) async {
      await _montar(tester);

      expect(find.text('Mis entregas'), findsOneWidget);
      expect(find.text('LH'), findsOneWidget); // iniciales de la sesión
      expect(find.text('Tienes 2 entregas activas para hoy'), findsOneWidget);
      expect(find.text('Disponibles'), findsOneWidget);
      expect(find.text('PIER-41'), findsOneWidget);
      expect(find.text('Ana López'), findsOneWidget);
      expect(find.text('Aviación'), findsOneWidget);
      expect(find.text('10 oct · 11:00 AM'), findsOneWidget);
      expect(find.text('En curso'), findsOneWidget);
      expect(find.text('PIER-1'), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Asignada'), findsOneWidget);
      expect(find.text('Colonia 1'), findsOneWidget);
      expect(find.text('PIER-3'), findsNothing); // ya finalizada

      await tester.scrollUntilVisible(find.text('PIER-2'), 200);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text(r'$1,250 MXN'), findsOneWidget);
      expect(find.text('En camino'), findsOneWidget);
    });

    testWidgets('mientras carga muestra el indicador', (tester) async {
      final api = _backend()
        ..demorar(ApiConstants.misEntregas, const Duration(seconds: 1));
      await _montar(tester, api: api);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('PIER-1'), findsOneWidget);
    });

    testWidgets('sin entregas ni disponibilidad invita a activarse',
        (tester) async {
      await _montar(tester,
          api: _backend(entregas: [], pool: [], disponible: false));

      expect(find.text('No estás recibiendo entregas'), findsOneWidget);
      expect(find.text('No estás disponible'), findsOneWidget);
      expect(find.text('Disponibles'), findsNothing);
    });

    testWidgets('disponible y sin entregas lo dice', (tester) async {
      await _montar(tester, api: _backend(entregas: [], pool: []));
      expect(find.text('Sin entregas activas por ahora'), findsOneWidget);
      expect(find.text('Sin entregas por ahora'), findsOneWidget);
    });

    testWidgets('con una sola entrega habla en singular', (tester) async {
      await _montar(tester,
          api: _backend(entregas: [_entrega('1', 'asignada')], pool: []));
      expect(find.text('Tienes 1 entrega activa para hoy'), findsOneWidget);
    });

    testWidgets('si no se pudieron cargar las entregas lo avisa',
        (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.misEntregas, 'Error al obtener entregas');
      await _montar(tester, api: api);

      expect(
        find.text(
            'Error al obtener entregas. Desliza hacia abajo para reintentar.'),
        findsOneWidget,
      );
    });

    testWidgets('jalar hacia abajo vuelve a pedir las entregas',
        (tester) async {
      final api = await _montar(tester);
      final antes = api.llamadas
          .where((l) => l.endpoint == ApiConstants.misEntregas)
          .length;

      await tester.fling(
          find.text('Disponible para entregas'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final despues = api.llamadas
          .where((l) => l.endpoint == ApiConstants.misEntregas)
          .length;
      expect(despues, greaterThan(antes));
    });

    testWidgets('tomar un pedido lo avisa con el mensaje del backend',
        (tester) async {
      final api = await _montar(tester);
      api
        ..responder(ApiConstants.entregasAceptar, {
          'success': true,
          'message': 'Tomaste el pedido #PIER-41',
        })
        ..demorar(ApiConstants.entregasAceptar, const Duration(seconds: 1));

      await tester.tap(find.text('Tomar entrega'));
      await tester.pump();
      expect(find.text('Tomando…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Tomaste el pedido #PIER-41'), findsOneWidget);
      expect(api.ultima(ApiConstants.entregasAceptar)!.body,
          {'pedido_id': '41'});
    });

    testWidgets('si otro repartidor lo tomó lo avisa', (tester) async {
      final api = await _montar(tester);
      api.fallar(
          ApiConstants.entregasAceptar, 'Otro repartidor ya tomó este pedido');

      await tester.tap(find.text('Tomar entrega'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Otro repartidor ya tomó este pedido'), findsOneWidget);
      expect(find.text('Tomar entrega'), findsOneWidget);
    });

    testWidgets('si no se puede cambiar la disponibilidad lo avisa',
        (tester) async {
      final api = await _montar(tester);
      api.fallar(ApiConstants.disponibilidad, 'Error al cambiar disponibilidad');

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(find.text('No se pudo cambiar la disponibilidad'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('tocar una entrega abre su detalle', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('PIER-1'));
      await tester.pumpAndSettle();

      expect(find.byType(EntregaDetailScreen), findsOneWidget);
      expect(find.text('Salir en camino'), findsOneWidget);
    });
  });

  group('RepartidorMainScreen: Historial', () {
    testWidgets('lista las finalizadas con el total del día', (tester) async {
      await _montar(tester);
      await _irA(tester, 'Historial');

      expect(find.text('Entregas finalizadas hoy'), findsOneWidget);
      expect(find.text('PIER-3'), findsOneWidget);
      expect(find.text('PIER-4'), findsOneWidget);
      expect(find.text('Fallida'), findsOneWidget);
      expect(find.text('3:30 PM'), findsOneWidget);
      expect(find.text('—'), findsOneWidget); // fallida sin hora
      expect(find.text('Total del día'), findsOneWidget);
      expect(find.text(r'$250 MXN'), findsNWidgets(2)); // fila y total
      expect(find.text('1 entrega'), findsOneWidget);
      expect(find.text('1 fallo'), findsOneWidget);

      await tester.tap(find.text('PIER-3'));
      await tester.pumpAndSettle();
      expect(find.byType(EntregaDetailScreen), findsOneWidget);
      expect(find.text('Reportar'), findsNothing); // ya no hay acciones
    });

    testWidgets('deslizar a la izquierda desde Entregas lo abre',
        (tester) async {
      await _montar(tester);

      await tester.fling(find.text('Mis entregas'), const Offset(-300, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Entregas finalizadas hoy'), findsOneWidget);
    });

    testWidgets('sin finalizadas lo dice y no muestra el total',
        (tester) async {
      final viewModel = RepartidorViewModel(
        repo: EntregasRepositoryRemote(
          api: _backend(entregas: [_entrega('1', 'asignada')]),
        ),
      );
      await _montar(tester, viewModel: viewModel);
      await _irA(tester, 'Historial');

      expect(find.text('Aún no hay entregas finalizadas hoy'), findsOneWidget);
      expect(find.text('Total del día'), findsNothing);
    });

    testWidgets('varias entregas y fallos van en plural', (tester) async {
      await _montar(tester,
          api: _backend(entregas: [
            _entrega('3', 'entregada'),
            _entrega('5', 'entregada'),
            _entrega('4', 'fallida'),
            _entrega('6', 'fallida'),
          ]));
      await _irA(tester, 'Historial');

      expect(find.text('2 entregas'), findsOneWidget);
      expect(find.text('2 fallos'), findsOneWidget);
    });
  });

  group('RepartidorMainScreen: Perfil', () {
    testWidgets('pinta la sesión, el estado de servicio y las métricas',
        (tester) async {
      final api = await _montar(tester);
      await _irA(tester, 'Perfil');

      expect(find.text('Luis Hernández'), findsOneWidget);
      expect(find.text('ID: PIER-REP-009'), findsOneWidget);
      expect(find.text('luis@pier.mx'), findsOneWidget);
      expect(find.text('7711234567'), findsOneWidget);
      expect(find.text('Disponible para entregas'), findsOneWidget);
      expect(find.text('Entregas hoy'), findsOneWidget);

      // El switch también vive en esta pestaña.
      api.responder(
          ApiConstants.disponibilidad, {'success': true, 'disponible': false});
      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      await tester.pump();
      expect(find.text('No disponible'), findsOneWidget);
    });

    testWidgets('cancelar el cierre de sesión no sale', (tester) async {
      await _montar(tester);
      await _irA(tester, 'Perfil');

      await tester.dragUntilVisible(
        find.text('Cerrar sesión'), find.byType(ListView), const Offset(0, -300));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Luis Hernández'), findsOneWidget);
    });
  });

  testWidgets('cerrar sesión vuelve al login', (tester) async {
    // Más ancho que el celular: el login no cabe con la fuente de pruebas.
    tester.view
      ..physicalSize = const Size(1440, 3040)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Sin plugin de Google en pruebas: su signOut responde al instante.
    const google = MethodChannel('plugins.flutter.io/google_sign_in');
    final mensajero = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(google, (_) async => null);
    addTearDown(() => mensajero.setMockMethodCallHandler(google, null));
    await tester.pumpMyApp(api: _backend(), initialLocation: AppRoutes.login);
    await tester.pumpAndSettle();
    await tester.iniciarSesion(find.byType(LoginScreen));
    await tester.pumpAndSettle();
    expect(find.byType(RepartidorMainScreen), findsOneWidget);

    await _irA(tester, 'Perfil');
    await tester.dragUntilVisible(
        find.text('Cerrar sesión'), find.byType(ListView), const Offset(0, -300));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RepartidorMainScreen), findsNothing);
  });
}
