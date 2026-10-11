// test/unit/notificaciones_repository_test.dart — NotificacionesRepositoryRemote
// tipado (MVVM, Fase 5) y el modelo Notificacion, sin red: FakeApiClient
// registra cada llamada.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/notificacion.dart';

import '../fakes/fake_api_client.dart';

final String _leer5 = ApiConstants.marcarNotificacionLeida('5');

Matcher _falla(String mensaje) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', mensaje));

void main() {
  group('Notificacion.fromJson', () {
    test('lee los campos del backend', () {
      final n = Notificacion.fromJson({
        'id': 5,
        'usuario_id': 3,
        'tipo': 'pedido',
        'titulo': 'Tu pedido está listo',
        'mensaje': 'Pasa por él',
        'leida': false,
        'created_at': '2026-10-10T15:30:00.000Z',
      });

      expect(n.id, '5');
      expect(n.tipo, 'pedido');
      expect(n.titulo, 'Tu pedido está listo');
      expect(n.mensaje, 'Pasa por él');
      expect(n.leida, isFalse);
      expect(n.creadaEn, DateTime.utc(2026, 10, 10, 15, 30).toLocal());
      expect(n.creadaEn!.isUtc, isFalse);
    });

    test('tolera faltantes y fechas inválidas', () {
      final n = Notificacion.fromJson({'leida': 'true', 'created_at': 'ayer'});

      expect(n.id, '');
      expect(n.tipo, 'sistema');
      expect(n.titulo, '');
      expect(n.mensaje, '');
      expect(n.leida, isFalse);
      expect(n.creadaEn, isNull);
    });

    test('marcadaLeida conserva todo lo demás', () {
      final fecha = DateTime(2026, 10, 10);
      final n = Notificacion(
        id: '1',
        tipo: 'promocion',
        titulo: 'Promo',
        mensaje: '2x1',
        creadaEn: fecha,
      ).marcadaLeida();

      expect(n.leida, isTrue);
      expect(
          [n.id, n.tipo, n.titulo, n.mensaje], ['1', 'promocion', 'Promo', '2x1']);
      expect(n.creadaEn, fecha);
    });
  });

  group('NotificacionesRepositoryRemote', () {
    test('listar devuelve las notificaciones con sesión', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.notificaciones: {
          'success': true,
          'notificaciones': [
            {'id': 2, 'tipo': 'pago', 'titulo': 'Pago recibido', 'leida': true},
            'basura',
            {'id': 1, 'tipo': 'pedido', 'titulo': 'Pedido listo'},
          ],
          'no_leidas': 1,
        },
      });

      final lista = await NotificacionesRepositoryRemote(api: api).listar();

      expect(lista.map((n) => n.titulo), ['Pago recibido', 'Pedido listo']);
      expect(lista.map((n) => n.leida), [true, false]);
      expect(api.llamo(ApiConstants.notificaciones, metodo: 'GET-Auth'),
          isTrue);
    });

    test('listar sin lista en la respuesta devuelve vacío', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.notificaciones: {'success': true},
      });

      expect(await NotificacionesRepositoryRemote(api: api).listar(), isEmpty);
    });

    test('listar rechazado lanza ApiException con el mensaje del backend',
        () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.notificaciones, 'Token expirado');

      await expectLater(
          NotificacionesRepositoryRemote(api: api).listar(),
          _falla('Token expirado'));
    });

    test('listar sin mensaje usa uno por defecto', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.notificaciones: {'success': false},
      });

      await expectLater(NotificacionesRepositoryRemote(api: api).listar(),
          _falla('No se pudieron cargar tus notificaciones'));
    });

    test('marcar una y todas usan PUT con sesión', () async {
      final api = FakeApiClient(respuestas: {
        _leer5: {'success': true},
        ApiConstants.notificacionesLeerTodas: {'success': true},
      });
      final repo = NotificacionesRepositoryRemote(api: api);

      await repo.marcarLeida('5');
      await repo.marcarTodasLeidas();

      expect(api.llamo(_leer5, metodo: 'PUT-Auth'), isTrue);
      expect(api.llamo(ApiConstants.notificacionesLeerTodas, metodo: 'PUT-Auth'),
          isTrue);
    });

    test('marcar rechazado lanza ApiException (mensaje o por defecto)',
        () async {
      final api = FakeApiClient(respuestas: {
        _leer5: {'success': false},
      })
        ..fallar(ApiConstants.notificacionesLeerTodas, 'Error al marcar');
      final repo = NotificacionesRepositoryRemote(api: api);

      await expectLater(repo.marcarLeida('5'),
          _falla('No se pudo marcar la notificación como leída'));
      await expectLater(repo.marcarTodasLeidas(), _falla('Error al marcar'));
    });
  });
}
