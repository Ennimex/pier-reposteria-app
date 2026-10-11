// test/unit/notification_provider_test.dart — notificaciones compartidas
// (campana de inicio y «Notificaciones») sin red: carga, marcar como leídas
// con reversión si el backend lo rechaza, y limpieza al cerrar sesión. El
// sondeo cada 2 minutos se prueba con tiempo simulado en
// test/widget/notifications/notifications_screen_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';

import '../fakes/fake_api_client.dart';

final String _leer1 = ApiConstants.marcarNotificacionLeida('1');

Map<String, dynamic> _lista({bool leida1 = false, bool conTercera = false}) => {
      'success': true,
      'notificaciones': [
        if (conTercera) {'id': 3, 'titulo': 'Nueva', 'leida': false},
        {'id': 1, 'titulo': 'Pedido listo', 'leida': leida1},
        {'id': 2, 'titulo': 'Promo', 'leida': false},
      ],
    };

(NotificationProvider, FakeApiClient) _armar([Map<String, dynamic>? extra]) {
  final api = FakeApiClient(respuestas: {
    ApiConstants.notificaciones: _lista(),
    ...?extra,
  });
  return (NotificationProvider(repo: NotificacionesRepositoryRemote(api: api)), api);
}

/// Cuenta los avisos del provider.
int Function() _contarAvisos(NotificationProvider p) {
  var avisos = 0;
  p.addListener(() => avisos++);
  return () => avisos;
}

void main() {
  group('NotificationProvider: carga', () {
    test('carga la lista y cuenta las no leídas', () async {
      final (p, _) = _armar();
      final avisos = _contarAvisos(p);

      await p.cargar();

      expect(p.notificaciones.map((n) => n.titulo), ['Pedido listo', 'Promo']);
      expect(p.noLeidas, 2);
      expect(avisos(), 1);
    });

    test('si nada cambió no vuelve a avisar', () async {
      final (p, api) = _armar();
      await p.cargar();
      final avisos = _contarAvisos(p);

      await p.cargar();
      expect(avisos(), 0);

      api.responder(ApiConstants.notificaciones, _lista(leida1: true));
      await p.cargar();
      expect(avisos(), 1);
      expect(p.noLeidas, 1);

      api.responder(
          ApiConstants.notificaciones, _lista(leida1: true, conTercera: true));
      await p.cargar();
      expect(avisos(), 2);
      expect(p.notificaciones.first.titulo, 'Nueva');
    });

    test('si falla lanza ApiException y conserva lo que tenía', () async {
      final (p, api) = _armar();
      await p.cargar();
      api.fallar(ApiConstants.notificaciones, 'Sin conexión');

      await expectLater(p.cargar(), throwsA(isA<ApiException>()));
      expect(p.notificaciones, hasLength(2));
    });

    test('la lista expuesta no se puede modificar desde fuera', () async {
      final (p, _) = _armar();
      await p.cargar();

      expect(() => p.notificaciones.clear(), throwsUnsupportedError);
    });
  });

  group('NotificationProvider: marcar como leídas', () {
    test('marcar una se ve al instante y se confirma con el backend',
        () async {
      final (p, api) = _armar({_leer1: {'success': true}});
      await p.cargar();

      final pendiente = p.marcarLeida('1');
      expect(p.notificaciones.first.leida, isTrue);
      expect(p.noLeidas, 1);

      expect(await pendiente, isNull);
      expect(api.llamo(_leer1, metodo: 'PUT-Auth'), isTrue);
      expect(p.noLeidas, 1);
    });

    test('si el backend la rechaza se revierte y devuelve el motivo',
        () async {
      final (p, _) = _armar({
        _leer1: {'success': false, 'message': 'Error al marcar'},
      });
      await p.cargar();

      expect(await p.marcarLeida('1'), 'Error al marcar');
      expect(p.notificaciones.first.leida, isFalse);
      expect(p.noLeidas, 2);
    });

    test('una ya leída o desconocida no llama al backend', () async {
      final (p, api) = _armar();
      api.responder(ApiConstants.notificaciones, _lista(leida1: true));
      await p.cargar();

      expect(await p.marcarLeida('1'), isNull);
      expect(await p.marcarLeida('99'), isNull);
      expect(api.llamadas.where((l) => l.metodo == 'PUT-Auth'), isEmpty);
    });

    test('marcar todas deja el badge en cero', () async {
      final (p, api) = _armar({
        ApiConstants.notificacionesLeerTodas: {'success': true},
      });
      await p.cargar();

      expect(await p.marcarTodasLeidas(), isNull);
      expect(p.noLeidas, 0);
      expect(p.notificaciones.every((n) => n.leida), isTrue);
      expect(api.llamo(ApiConstants.notificacionesLeerTodas, metodo: 'PUT-Auth'),
          isTrue);
    });

    test('si marcar todas falla vuelven a quedar sin leer', () async {
      final (p, api) = _armar();
      api.responder(ApiConstants.notificaciones, _lista(leida1: true));
      await p.cargar();
      api.fallar(ApiConstants.notificacionesLeerTodas, 'Error al marcar');

      expect(await p.marcarTodasLeidas(), 'Error al marcar');
      expect(p.notificaciones.map((n) => n.leida), [true, false]);
      expect(p.noLeidas, 1);
    });

    test('sin no leídas «marcar todas» no llama al backend', () async {
      final (p, api) = _armar();

      expect(await p.marcarTodasLeidas(), isNull);
      expect(api.llamo(ApiConstants.notificacionesLeerTodas), isFalse);
    });
  });

  group('NotificationProvider: sesión', () {
    test('stopPolling vacía la lista y el badge', () async {
      final (p, _) = _armar();
      await p.cargar();

      p.stopPolling();

      expect(p.notificaciones, isEmpty);
      expect(p.noLeidas, 0);
    });

    test('una respuesta que llega tras cerrar sesión se descarta', () async {
      final (p, api) = _armar();
      api.demorar(ApiConstants.notificaciones, const Duration(milliseconds: 20));

      final pendiente = p.cargar();
      p.stopPolling();
      await pendiente;

      expect(p.notificaciones, isEmpty);
    });

    test('startPolling consulta de inmediato y solo una vez', () async {
      final (p, api) = _armar();

      p
        ..startPolling()
        ..startPolling();
      await Future<void>.delayed(Duration.zero);

      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.notificaciones),
          hasLength(1));
      expect(p.noLeidas, 2);
      p.stopPolling();
    });

    test('si el sondeo falla no lanza y conserva la lista', () async {
      final (p, api) = _armar();
      await p.cargar();
      api.fallar(ApiConstants.notificaciones, 'Sin conexión');

      p.startPolling();
      await Future<void>.delayed(Duration.zero);

      expect(p.notificaciones, hasLength(2));
      p.stopPolling();
    });

    test('tras dispose una respuesta pendiente no avisa', () async {
      final (p, api) = _armar();
      api.demorar(ApiConstants.notificaciones, const Duration(milliseconds: 20));
      final pendiente = p.cargar();

      p.dispose();

      await expectLater(pendiente, completes);
    });

    test('dispose cancela el sondeo', () {
      final (p, _) = _armar();
      p.startPolling();

      expect(p.dispose, returnsNormally);
    });
  });

  test('intervalo de sondeo de 2 minutos', () {
    expect(NotificationProvider.intervalo, const Duration(minutes: 2));
  });
}
