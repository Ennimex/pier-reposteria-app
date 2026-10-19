// test/unitarias/feed/interaccion_test.dart — «Me encanta» y comentarios de
// las publicaciones (#133): repositorio, corazón optimista en FeedViewModel
// (revierte si falla, quita la publicación si ya no está) y
// ComentariosViewModel (páginas, comentar, borrar, antispam).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository_remote.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/feed/view_model/comentarios_view_model.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';

const _feed = '/publicaciones/feed?limite=8';
const _corazon = '/publicaciones/1/corazon';
const _comentarios = '/publicaciones/1/comentarios?limite=20';
const _comentar = '/publicaciones/1/comentarios';

Map<String, dynamic> _reaccion({required bool meEncanta, required int n}) => {
  'success': true,
  'me_encanta': meEncanta,
  'corazones': n,
};

const Map<String, dynamic> _noEncontrada = {
  'success': false,
  'message': 'Publicación no encontrada',
};

Publicacion _publicacion(FeedViewModel vm) =>
    (vm.elementos.first as ElementoPublicacion).publicacion;

void main() {
  late FakeApiClient api;
  late PublicacionesRepositoryRemote repo;

  setUp(() {
    api = FakeApiClient()
      ..responder('/publicaciones/promociones', promocionesFeedJson(const []))
      ..responder(
        _feed,
        feedJson([
          publicacionJson(
            totalComentarios: 2,
            comentarios: [
              comentarioJson(id: 10),
              comentarioJson(id: 11, texto: 'Mío', tuyo: true),
            ],
          ),
          publicacionJson(id: 2, texto: 'Otra'),
        ]),
      );
    repo = PublicacionesRepositoryRemote(api: api);
  });

  group('Repositorio', () {
    test(
      'Me encanta: PUT con cuerpo vacío para poner, DELETE para quitar',
      () async {
        api.responder(_corazon, _reaccion(meEncanta: true, n: 4));

        final puesta = await repo.meEncanta(1, poner: true);
        expect(puesta.meEncanta, isTrue);
        expect(puesta.corazones, 4);
        expect(api.ultima(_corazon)!.metodo, 'PUT-Auth');
        expect(api.ultima(_corazon)!.body, <String, dynamic>{});

        api.responder(_corazon, _reaccion(meEncanta: false, n: 3));
        await repo.meEncanta(1, poner: false);
        expect(api.ultima(_corazon)!.metodo, 'DELETE-Auth');
      },
    );

    test('publicación eliminada: PublicacionNoDisponibleException', () async {
      api.responder(_corazon, _noEncontrada);

      await expectLater(
        repo.meEncanta(1, poner: true),
        throwsA(isA<PublicacionNoDisponibleException>()),
      );
    });

    test('comentarios por páginas después del último', () async {
      api
        ..responder(
          _comentarios,
          {
            'success': true,
            'comentarios': [comentarioJson(id: 10)],
            'hay_mas': true,
          },
        )
        ..responder(
          '/publicaciones/1/comentarios?limite=20&despues_id=10',
          {
            'success': true,
            'comentarios': [comentarioJson(id: 12)],
            'hay_mas': false,
          },
        );

      final primera = await repo.comentarios(1);
      expect(primera.comentarios.single.id, 10);
      expect(primera.hayMas, isTrue);
      final siguiente = await repo.comentarios(1, despuesId: 10);
      expect(siguiente.comentarios.single.id, 12);
      expect(siguiente.hayMas, isFalse);
    });

    test('comentar manda el texto y devuelve el comentario', () async {
      api.responder(_comentar, {
        'success': true,
        'comentario': comentarioJson(id: 30, texto: 'Hola', tuyo: true),
      });

      final c = await repo.comentar(1, 'Hola');

      expect(c.id, 30);
      expect(c.esTuyo, isTrue);
      expect(api.ultima(_comentar)!.body, {'texto': 'Hola'});
      expect(api.ultima(_comentar)!.metodo, 'POST-Auth');
    });

    test('borrar un comentario', () async {
      api.responder('/publicaciones/comentarios/11', {'success': true});

      await repo.borrarComentario(11);

      expect(
        api.ultima('/publicaciones/comentarios/11')!.metodo,
        'DELETE-Auth',
      );
    });

    test('comentar de más: ApiException con el aviso del backend', () async {
      api.fallar(
        _comentar,
        'Escribiste varios comentarios seguidos. Espera un minuto y vuelve a intentarlo.',
      );

      await expectLater(
        repo.comentar(1, 'Otro'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Espera un minuto'),
          ),
        ),
      );
    });
  });

  group('FeedViewModel: Me encanta', () {
    late FeedViewModel vm;

    setUp(() async {
      vm = FeedViewModel(repo: repo);
      await vm.cargar();
    });

    test('se marca al instante y queda lo que dice el servidor', () async {
      api
        ..responder(_corazon, _reaccion(meEncanta: true, n: 9))
        ..demorar(_corazon, const Duration(milliseconds: 20));

      final toque = vm.alternarMeEncanta(1);
      expect(_publicacion(vm).meEncanta, isTrue);
      expect(_publicacion(vm).corazones, 4);
      final error = await toque;

      expect(error, isNull);
      expect(_publicacion(vm).corazones, 9);
    });

    test('si falla vuelve a como estaba y avisa', () async {
      api.fallar(_corazon, 'No se pudo guardar tu reacción');

      final error = await vm.alternarMeEncanta(1);

      expect(error, 'No se pudo guardar tu reacción');
      expect(_publicacion(vm).meEncanta, isFalse);
      expect(_publicacion(vm).corazones, 3);
    });

    test('toques rápidos: se manda el último que quedó', () async {
      api
        ..responder(_corazon, _reaccion(meEncanta: true, n: 4))
        ..demorar(_corazon, const Duration(milliseconds: 20));

      final primero = vm.alternarMeEncanta(1);
      api.responder(_corazon, _reaccion(meEncanta: false, n: 3));
      await vm.alternarMeEncanta(1);
      await primero;

      expect(_publicacion(vm).meEncanta, isFalse);
      expect(api.llamadas.where((l) => l.endpoint == _corazon), hasLength(2));
      expect(api.ultima(_corazon)!.metodo, 'DELETE-Auth');
    });

    test('publicación eliminada: desaparece del inicio', () async {
      api.responder(_corazon, _noEncontrada);

      final error = await vm.alternarMeEncanta(1);

      expect(error, 'Esta publicación ya no está disponible');
      expect(_publicacion(vm).id, 2);
    });

    test('una publicación que no existe no hace nada', () async {
      expect(await vm.alternarMeEncanta(99), isNull);
      expect(api.llamo(_corazon), isFalse);
    });

    test('aplicarComentarios: cuenta y recientes', () {
      final nuevo = ComentarioPublicacion.fromJson(
        comentarioJson(id: 40, texto: 'Nuevo', tuyo: true),
      );

      vm.aplicarComentarios(1, nuevos: [nuevo], borrados: {11});

      final p = _publicacion(vm);
      expect(p.totalComentarios, 2);
      expect(p.comentariosRecientes.map((c) => c.id), [10, 40]);
    });
  });

  group('ComentariosViewModel', () {
    late ComentariosViewModel vm;

    setUp(() {
      api.responder(_comentarios, {
        'success': true,
        'comentarios': [comentarioJson(id: 10)],
        'hay_mas': true,
      });
      vm = ComentariosViewModel(repo: repo, publicacionId: 1);
    });

    test('carga la primera página y luego más', () async {
      api.responder('/publicaciones/1/comentarios?limite=20&despues_id=10', {
        'success': true,
        'comentarios': [comentarioJson(id: 12)],
        'hay_mas': false,
      });
      final carga = vm.cargar();
      expect(vm.cargando, isTrue);
      await carga;
      expect(vm.comentarios.map((c) => c.id), [10]);
      expect(vm.hayMas, isTrue);

      await vm.cargarMas();
      expect(vm.comentarios.map((c) => c.id), [10, 12]);
      expect(vm.hayMas, isFalse);
      await vm.cargarMas();
      expect(api.llamadas, hasLength(2));
    });

    test('error al cargar', () async {
      api.fallar(_comentarios, 'Error al obtener los comentarios');
      await vm.cargar();

      expect(vm.error, 'Error al obtener los comentarios');
    });

    test('publicar agrega el comentario al final y lo recuerda', () async {
      await vm.cargar();
      api.responder(_comentar, {
        'success': true,
        'comentario': comentarioJson(id: 50, texto: 'Rico', tuyo: true),
      });

      await vm.publicar.execute('  Rico  ');

      expect(api.ultima(_comentar)!.body, {'texto': 'Rico'});
      expect(vm.comentarios.last.id, 50);
      expect(vm.nuevos.single.id, 50);
    });

    test('borrar lo quita y lo recuerda', () async {
      api.responder(_comentarios, {
        'success': true,
        'comentarios': [comentarioJson(id: 11, tuyo: true)],
        'hay_mas': false,
      });
      await vm.cargar();
      api.responder('/publicaciones/comentarios/11', {'success': true});

      await vm.borrar.execute(11);

      expect(vm.comentarios, isEmpty);
      expect(vm.borrados, {11});
    });

    test('borrar uno recién publicado no lo cuenta dos veces', () async {
      await vm.cargar();
      api
        ..responder(_comentar, {
          'success': true,
          'comentario': comentarioJson(id: 50, tuyo: true),
        })
        ..responder('/publicaciones/comentarios/50', {'success': true});
      await vm.publicar.execute('Hola');

      await vm.borrar.execute(50);

      expect(vm.nuevos, isEmpty);
      expect(vm.borrados, isEmpty);
    });

    test('la publicación ya no está: lo marca', () async {
      api.responder(_comentarios, _noEncontrada);
      await vm.cargar();

      expect(vm.noDisponible, isTrue);
    });

    test('comentar falla: el error queda en el comando', () async {
      await vm.cargar();
      api.fallar(_comentar, 'Escribiste varios comentarios seguidos.');

      await vm.publicar.execute('Otro');

      expect(
        (vm.publicar.error! as ApiException).message,
        'Escribiste varios comentarios seguidos.',
      );
      expect(vm.nuevos, isEmpty);
    });

    test('tras dispose no avisa', () async {
      api.demorar(_comentarios, const Duration(milliseconds: 20));
      final carga = vm.cargar();
      vm.dispose();
      await expectLater(carga, completes);
    });
  });
}
