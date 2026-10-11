// test/unit/entregas_repository_test.dart — EntregasRepositoryRemote tipado
// (MVVM, Fase 5) sin red: convierte las respuestas en modelos y lanza
// ApiException con el mensaje del backend o uno por defecto.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';

import '../fakes/fake_api_client.dart';

/// Falla si [llamada] no lanza ApiException con [mensaje].
Future<void> _esperaError(Future<Object?> llamada, String mensaje) =>
    expectLater(
      llamada,
      throwsA(isA<ApiException>().having((e) => e.message, 'message', mensaje)),
    );

void main() {
  late FakeApiClient api;
  late EntregasRepositoryRemote repo;

  setUp(() {
    api = FakeApiClient();
    repo = EntregasRepositoryRemote(api: api);
  });

  group('consultas', () {
    test('misEntregas convierte cada entrega e ignora lo que no es Map',
        () async {
      api.responder(ApiConstants.misEntregas, {
        'success': true,
        'entregas': [
          {'id': 1, 'estado': 'asignada', 'numero': 'PIER-1'},
          'basura',
        ],
      });

      final entregas = await repo.misEntregas();

      expect(entregas.single.numero, 'PIER-1');
      expect(entregas.single.estado, EstadoEntrega.asignada);
    });

    test('sin lista devuelve vacío', () async {
      api
        ..responder(ApiConstants.misEntregas, {'success': true})
        ..responder(ApiConstants.entregasDisponibles, {'success': true});

      expect(await repo.misEntregas(), isEmpty);
      expect(await repo.disponibles(), isEmpty);
    });

    test('disponibles convierte el pool', () async {
      api.responder(ApiConstants.entregasDisponibles, {
        'success': true,
        'pedidos': [
          {'pedido_id': 41, 'numero': 'PIER-41', 'total': 300},
        ],
      });

      final pool = await repo.disponibles();

      expect(pool.single.pedidoId, '41');
      expect(pool.single.total, 300);
    });

    test('disponibilidad lee el booleano', () async {
      api.responder(
          ApiConstants.disponibilidad, {'success': true, 'disponible': true});
      expect(await repo.disponibilidad(), isTrue);
    });

    test('cada consulta fallida lanza su mensaje por defecto', () async {
      await _esperaError(
          repo.misEntregas(), 'Sin respuesta configurada: /entregas/mis-entregas');

      api
        ..responder(ApiConstants.misEntregas, {'success': false})
        ..responder(ApiConstants.disponibilidad, {'success': false})
        ..responder(ApiConstants.entregasDisponibles, {'success': false});
      await _esperaError(
          repo.misEntregas(), 'No se pudieron cargar tus entregas');
      await _esperaError(
          repo.disponibilidad(), 'No se pudo consultar tu disponibilidad');
      await _esperaError(repo.disponibles(),
          'No se pudieron cargar los pedidos disponibles');
    });
  });

  group('acciones', () {
    test('cambiarDisponibilidad manda el valor y devuelve el guardado',
        () async {
      api.responder(
          ApiConstants.disponibilidad, {'success': true, 'disponible': false});

      final guardado = await repo.cambiarDisponibilidad(disponible: true);

      expect(guardado, isFalse);
      expect(api.ultima(ApiConstants.disponibilidad)!.body,
          {'disponible': true});
    });

    test('cambiarDisponibilidad rechazada lanza el mensaje', () async {
      api.responder(ApiConstants.disponibilidad, {'success': false});
      await _esperaError(repo.cambiarDisponibilidad(disponible: true),
          'No se pudo cambiar la disponibilidad');
    });

    test('aceptar devuelve el mensaje del backend o uno por defecto',
        () async {
      api.responder(ApiConstants.entregasAceptar,
          {'success': true, 'message': 'Tomaste el pedido #PIER-41'});
      expect(await repo.aceptar('41'), 'Tomaste el pedido #PIER-41');
      expect(api.ultima(ApiConstants.entregasAceptar)!.body,
          {'pedido_id': '41'});

      api.responder(ApiConstants.entregasAceptar, {'success': true});
      expect(await repo.aceptar('41'), 'Pedido tomado');

      api.fallar(ApiConstants.entregasAceptar, 'Otro repartidor ya tomó este pedido');
      await _esperaError(
          repo.aceptar('41'), 'Otro repartidor ya tomó este pedido');

      api.responder(ApiConstants.entregasAceptar, {'success': false});
      await _esperaError(repo.aceptar('41'), 'No se pudo tomar el pedido');
    });

    test('cambiarEstado manda solo los campos presentes', () async {
      final ruta = ApiConstants.entregaEstado('9');
      api.responder(ruta, {'success': true});

      await repo.cambiarEstado('9', EstadoEntrega.enCamino);
      expect(api.ultima(ruta)!.body, {'estado': 'en_camino'});

      await repo.cambiarEstado('9', EstadoEntrega.entregada,
          recibioNombre: 'María', evidenciaUrl: 'https://cdn/f.jpg');
      expect(api.ultima(ruta)!.body, {
        'estado': 'entregada',
        'evidencia_url': 'https://cdn/f.jpg',
        'recibio_nombre': 'María',
      });

      await repo.cambiarEstado('9', EstadoEntrega.fallida,
          motivoFallo: 'No contestó: nadie abrió');
      expect(api.ultima(ruta)!.body,
          {'estado': 'fallida', 'motivo_fallo': 'No contestó: nadie abrió'});
      expect(api.ultima(ruta)!.metodo, 'PUT-Auth');
    });

    test('cambiarEstado rechazado lanza un mensaje según el estado', () async {
      api.responder(ApiConstants.entregaEstado('9'), {'success': false});

      await _esperaError(repo.cambiarEstado('9', EstadoEntrega.enCamino),
          'No se pudo actualizar');
      await _esperaError(
          repo.cambiarEstado('9', EstadoEntrega.entregada, recibioNombre: 'A'),
          'No se pudo confirmar la entrega');
      await _esperaError(
          repo.cambiarEstado('9', EstadoEntrega.fallida, motivoFallo: 'x'),
          'No se pudo reportar');

      api.fallar(ApiConstants.entregaEstado('9'), 'Indica quién recibió el pedido');
      await _esperaError(repo.cambiarEstado('9', EstadoEntrega.entregada),
          'Indica quién recibió el pedido');
    });

    test('avisarLlegada devuelve el mensaje del backend o uno por defecto',
        () async {
      final ruta = ApiConstants.entregaLlegue('9');
      api.responder(
          ruta, {'success': true, 'message': 'Cliente avisado de tu llegada'});
      expect(await repo.avisarLlegada('9'), 'Cliente avisado de tu llegada');
      expect(api.llamo(ruta, metodo: 'POST-Auth'), isTrue);

      api.responder(ruta, {'success': true});
      expect(await repo.avisarLlegada('9'), 'Cliente avisado');

      api.responder(ruta, {'success': false});
      await _esperaError(repo.avisarLlegada('9'), 'No se pudo avisar');
    });

    test('subirEvidencia devuelve la URL o lanza si no llegó', () async {
      api.responder(ApiConstants.uploadImagen, {
        'success': true,
        'imagen': {'url': 'https://cdn/f.jpg'},
      });
      expect(await repo.subirEvidencia('/tmp/f.jpg'), 'https://cdn/f.jpg');
      expect(api.ultima(ApiConstants.uploadImagen)!.body,
          {'filePath': '/tmp/f.jpg', 'tipo': 'entrega'});

      api.responder(ApiConstants.uploadImagen, {'success': true});
      await _esperaError(
          repo.subirEvidencia('/tmp/f.jpg'), 'No se pudo subir la foto');

      api.fallar(ApiConstants.uploadImagen, 'Error al subir imagen');
      await _esperaError(
          repo.subirEvidencia('/tmp/f.jpg'), 'Error al subir imagen');
    });
  });
}
