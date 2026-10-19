// test/unitarias/feed/feed_test.dart — publicaciones del inicio del cliente
// (#132): modelos, cómo se intercalan promociones y sugerencias (igual que la
// web, src/cliente/feed/estado.ts), repositorio y FeedViewModel.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository_remote.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';

const _feed = '/publicaciones/feed?limite=8';
const _promociones = '/publicaciones/promociones';

String _sugerencias(int pagina) => '/publicaciones/sugerencias?pagina=$pagina';

List<Map<String, dynamic>> _publicaciones(int desde, int cuantas) => [
  for (var i = desde; i < desde + cuantas; i++) publicacionJson(id: i),
];

List<Map<String, dynamic>> _sugeridos(int desde, int cuantos) => [
  for (var i = desde; i < desde + cuantos; i++)
    sugeridoJson(id: i, nombre: 'Producto $i'),
];

/// Claves de lo que se pinta, para comparar el orden del feed.
List<String> _claves(List<ElementoFeed> elementos) => [
  for (final e in elementos)
    switch (e) {
      ElementoPublicacion(:final publicacion) => 'pub${publicacion.id}',
      ElementoPromocion(:final promocion) => 'promo${promocion.id}',
      ElementoSugerencias(:final productos) =>
        'sug${productos.map((p) => p.id).join(',')}',
    },
];

EstadoFeed _estado({
  int publicaciones = 0,
  bool terminado = false,
  int promociones = 0,
  int sugerencias = 0,
  bool sugerenciasTerminadas = false,
}) => EstadoFeed(
  publicaciones: [
    for (var i = 1; i <= publicaciones; i++)
      Publicacion.fromJson(publicacionJson(id: i)),
  ],
  feedTerminado: terminado,
  promociones: [
    for (var i = 1; i <= promociones; i++)
      PromocionFeed.fromJson(promocionFeedJson(id: i, productoId: 100 + i)),
  ],
  sugerencias: [
    for (var i = 1; i <= sugerencias; i++)
      ProductoSugerido.fromJson(sugeridoJson(id: i)),
  ],
  sugerenciasTerminadas: sugerenciasTerminadas,
);

void main() {
  group('Modelos', () {
    test('publicación con fotos, video, contadores y comentarios', () {
      final p = Publicacion.fromJson(
        publicacionJson(
          id: 4,
          editada: true,
          medios: [
            medioJson(),
            medioJson(
              id: 2,
              tipo: 'video',
              url: 'https://res.cloudinary.com/v.mp4',
              poster: 'https://res.cloudinary.com/v.jpg',
              duracion: 12.5,
            ),
          ],
          corazones: 7,
          meEncanta: true,
          totalComentarios: 5,
          comentarios: [
            comentarioJson(oficial: true, autor: 'Pier Repostería'),
          ],
        ),
      );

      expect(p.id, 4);
      expect(p.texto, 'Pastel de chocolate recién salido del horno');
      expect(p.creada, DateTime.utc(2026, 10, 12, 16));
      expect(p.editada, isTrue);
      expect(p.medios.first.esVideo, isFalse);
      expect(p.medios.first.proporcion, closeTo(1.333, 0.001));
      expect(p.medios.last.esVideo, isTrue);
      expect(p.medios.last.portada, 'https://res.cloudinary.com/v.jpg');
      expect(p.medios.last.duracion, 12.5);
      expect(p.corazones, 7);
      expect(p.meEncanta, isTrue);
      expect(p.totalComentarios, 5);
      expect(p.comentariosRecientes.single.esOficial, isTrue);
      expect(p.comentariosRecientes.single.autorNombre, 'Pier Repostería');
    });

    test('sin texto y medidas raras no truenan', () {
      final p = Publicacion.fromJson(
        publicacionJson(texto: null, medios: [medioJson(ancho: 0, alto: 0)]),
      );

      expect(p.texto, isNull);
      expect(p.medios.single.proporcion, 1);
    });

    test('la proporción de las fotos queda entre 0.8 y 1.91', () {
      expect(
        MedioPublicacion.fromJson(medioJson(ancho: 400, alto: 1600)).proporcion,
        0.8,
      );
      expect(
        MedioPublicacion.fromJson(
          medioJson(ancho: 3000, alto: 1000),
        ).proporcion,
        1.91,
      );
    });

    test('promoción con su precio y su producto', () {
      final p = PromocionFeed.fromJson(promocionFeedJson(etiqueta: 'Favorito'));

      expect(p.titulo, 'Chocoflan');
      expect(p.subtitulo, 'Solo esta semana');
      expect(p.etiqueta, 'Favorito');
      expect(p.descuentoPorcentaje, 20);
      expect(p.precioNormal, 250);
      expect(p.precioPromocion, 200);
      expect(p.productoId, 10);
      expect(p.imagenUrl, 'https://res.cloudinary.com/pier/p10.webp');
      final producto = p.comoProducto;
      expect(producto.id, '10');
      expect(producto.precio, 250);
      expect(producto.precioGrande, 400);
      expect(producto.categoria, 'Postres');
    });

    test('producto sugerido con su motivo', () {
      final s = ProductoSugerido.fromJson(
        sugeridoJson(motivo: 'Porque te gustó Chocoflan'),
      );

      expect(s.motivo, 'Porque te gustó Chocoflan');
      expect(s.precioChico, 180);
      expect(s.comoProducto.id, '20');
      expect(s.comoProducto.nombre, 'Pay de queso');
    });
  });

  group('componerFeed (misma regla que la web)', () {
    test('una promoción después de cada 5 publicaciones', () {
      final e = componerFeed(_estado(publicaciones: 11, promociones: 3));

      expect(_claves(e), [
        'pub1',
        'pub2',
        'pub3',
        'pub4',
        'pub5',
        'promo1',
        'pub6',
        'pub7',
        'pub8',
        'pub9',
        'pub10',
        'promo2',
        'pub11',
      ]);
    });

    test('mientras haya publicaciones no salen sugerencias', () {
      final e = componerFeed(_estado(publicaciones: 2, sugerencias: 6));

      expect(_claves(e), ['pub1', 'pub2']);
    });

    test('al acabarse: bloques de 6 sugerencias con una promoción tras cada '
        'bloque completo y al final las que sobren', () {
      final e = componerFeed(
        _estado(
          publicaciones: 1,
          terminado: true,
          promociones: 3,
          sugerencias: 8,
          sugerenciasTerminadas: true,
        ),
      );

      expect(_claves(e), [
        'pub1',
        'sug1,2,3,4,5,6',
        'promo1',
        'sug7,8',
        'promo2',
        'promo3',
      ]);
    });

    test('un bloque incompleto que aún va a crecer no lleva promoción', () {
      final e = componerFeed(
        _estado(terminado: true, promociones: 2, sugerencias: 4),
      );

      expect(_claves(e), ['sug1,2,3,4']);
    });
  });

  group('PublicacionesRepositoryRemote', () {
    late FakeApiClient api;
    late PublicacionesRepositoryRemote repo;

    setUp(() {
      api = FakeApiClient();
      repo = PublicacionesRepositoryRemote(api: api);
    });

    test('feed: primera página y cursor de la siguiente', () async {
      api.responder(
        _feed,
        feedJson(_publicaciones(1, 2), siguiente: cursorJson()),
      );

      final pagina = await repo.feed();

      expect(pagina.publicaciones.map((p) => p.id), [1, 2]);
      expect(pagina.siguiente!.antesId, 5);
      expect(api.llamadas.single.metodo, 'GET-Auth');
    });

    test('feed: la siguiente página manda el cursor codificado', () async {
      const conCursor =
          '/publicaciones/feed?limite=8'
          '&antes=2026-10-10T12%3A00%3A00.123456Z&antes_id=5';
      api.responder(conCursor, feedJson(_publicaciones(3, 1)));

      final pagina = await repo.feed(
        despues: const CursorFeed(
          antes: '2026-10-10T12:00:00.123456Z',
          antesId: 5,
        ),
      );

      expect(pagina.publicaciones.single.id, 3);
      expect(pagina.siguiente, isNull);
      expect(api.llamadas.single.endpoint, conCursor);
    });

    test('promociones y sugerencias', () async {
      api
        ..responder(_promociones, promocionesFeedJson([promocionFeedJson()]))
        ..responder(
          _sugerencias(2),
          sugerenciasJson(_sugeridos(1, 2), hayMas: true),
        );

      expect((await repo.promociones()).single.titulo, 'Chocoflan');
      final s = await repo.sugerencias(pagina: 2);
      expect(s.productos.map((p) => p.id), [1, 2]);
      expect(s.hayMas, isTrue);
    });

    test(
      'si falla: ApiException con el mensaje; sesión inválida aparte',
      () async {
        api.fallar(_feed, 'Error al cargar el inicio');
        await expectLater(
          repo.feed(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Error al cargar el inicio',
            ),
          ),
        );

        api.responder(_promociones, {
          'success': false,
          'codigo': 'SESION_INVALIDA',
          'message': 'Tu cuenta está desactivada o cambió.',
        });
        await expectLater(
          repo.promociones(),
          throwsA(isA<SesionInvalidaException>()),
        );

        api.responder(_sugerencias(1), {'success': false});
        await expectLater(
          repo.sugerencias(pagina: 1),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'No se pudieron cargar las sugerencias',
            ),
          ),
        );
      },
    );
  });

  group('FeedViewModel', () {
    late FakeApiClient api;
    late FeedViewModel vm;

    setUp(() {
      api = FakeApiClient()
        ..responder(
          _promociones,
          promocionesFeedJson([promocionFeedJson(productoId: 21)]),
        );
      vm = FeedViewModel(repo: PublicacionesRepositoryRemote(api: api));
    });

    test('cargar: promociones y la primera página', () async {
      api.responder(
        _feed,
        feedJson(_publicaciones(1, 5), siguiente: cursorJson()),
      );
      final carga = vm.cargar();
      expect(vm.cargando, isTrue);
      await carga;

      expect(vm.cargando, isFalse);
      expect(vm.iniciado, isTrue);
      expect(vm.fase, FaseFeed.publicaciones);
      expect(_claves(vm.elementos), [
        'pub1',
        'pub2',
        'pub3',
        'pub4',
        'pub5',
        'promo1',
      ]);
    });

    test('cargarMas: sigue con el cursor y luego pasa a las sugerencias, sin '
        'repetir lo que ya salió como promoción', () async {
      const conCursor =
          '/publicaciones/feed?limite=8'
          '&antes=2026-10-10T12%3A00%3A00.123456Z&antes_id=5';
      api
        ..responder(
          _feed,
          feedJson(_publicaciones(1, 2), siguiente: cursorJson()),
        )
        ..responder(conCursor, feedJson(_publicaciones(2, 2)))
        ..responder(
          _sugerencias(1),
          sugerenciasJson(_sugeridos(20, 3)),
        );
      await vm.cargar();

      await vm.cargarMas();
      expect(vm.fase, FaseFeed.sugerencias);
      expect(_claves(vm.elementos), [
        'pub1',
        'pub2',
        'pub3',
      ], reason: 'pub2 no se repite');

      await vm.cargarMas();
      expect(vm.fase, FaseFeed.fin);
      expect(_claves(vm.elementos), [
        'pub1',
        'pub2',
        'pub3',
        'sug20,22',
        'promo1',
      ], reason: 'el 21 ya salió como promoción');
    });

    test('feed vacío: sin publicaciones', () async {
      api
        ..responder(_feed, feedJson(const []))
        ..responder(_sugerencias(1), sugerenciasJson(const []));
      await vm.cargar();

      expect(vm.sinPublicaciones, isTrue);
      await vm.cargarMas();
      expect(vm.fase, FaseFeed.fin);
    });

    test('si fallan las promociones el feed sigue sin error', () async {
      api
        ..fallar(_promociones, 'Error al obtener las promociones')
        ..responder(_feed, feedJson(_publicaciones(1, 1)));
      await vm.cargar();

      expect(vm.error, isNull);
      expect(_claves(vm.elementos), ['pub1']);
    });

    test('error en la primera carga y reintento', () async {
      api.fallar(_feed, 'Error al cargar el inicio');
      await vm.cargar();
      expect(vm.error, 'Error al cargar el inicio');
      expect(vm.iniciado, isFalse);

      api.responder(_feed, feedJson(_publicaciones(1, 1)));
      await vm.cargar();
      expect(vm.error, isNull);
      expect(vm.iniciado, isTrue);
    });

    test('error al cargar más: lo marca y deja reintentar', () async {
      api.responder(
        _feed,
        feedJson(_publicaciones(1, 1), siguiente: cursorJson()),
      );
      await vm.cargar();

      await vm.cargarMas();
      expect(vm.errorMas, isNotNull);
      expect(_claves(vm.elementos), ['pub1']);
    });

    test('no pide más mientras carga ni al terminar', () async {
      api
        ..responder(_feed, feedJson(_publicaciones(1, 1)))
        ..responder(_sugerencias(1), sugerenciasJson(_sugeridos(30, 1)))
        ..demorar(_sugerencias(1), const Duration(milliseconds: 20));
      await vm.cargar();

      final primera = vm.cargarMas();
      expect(vm.cargandoMas, isTrue);
      await vm.cargarMas();
      await primera;
      await vm.cargarMas();

      expect(
        api.llamadas.where((l) => l.endpoint == _sugerencias(1)),
        hasLength(1),
      );
      expect(vm.fase, FaseFeed.fin);
    });

    test('recargar empieza de nuevo y limpiar lo olvida todo', () async {
      api.responder(_feed, feedJson(_publicaciones(1, 1)));
      await vm.cargar();
      api.responder(_feed, feedJson(_publicaciones(7, 1)));

      await vm.recargar();
      expect(_claves(vm.elementos), ['pub7']);

      vm.limpiar();
      expect(vm.iniciado, isFalse);
      expect(vm.elementos, isEmpty);
    });

    test('tras dispose no avisa', () async {
      api
        ..responder(_feed, feedJson(const []))
        ..demorar(_feed, const Duration(milliseconds: 20));
      final carga = vm.cargar();
      vm.dispose();
      await expectLater(carga, completes);
    });
  });
}
