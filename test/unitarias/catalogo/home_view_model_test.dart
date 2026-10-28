// test/unitarias/catalogo/home_view_model_test.dart — ViewModel del inicio (MVVM, Fase 4)
// sin red: carga pública, slides configurables (editor del sitio, panel o
// respaldo), sucursales, datos del usuario y el tiempo restante de las
// promociones.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/config_testimonios.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/domain/models/slide_hero.dart';
import 'package:pier_reposteria/ui/home/view_model/home_view_model.dart';

import '../../fakes/fake_api_client.dart';

HomeViewModel _vm(FakeApiClient api) => HomeViewModel(
      productosRepo: ProductosRepositoryRemote(api: api),
      resenasRepo: ResenasRepositoryRemote(api: api),
      configRepo: ConfiguracionRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
    );

Map<String, dynamic> _ok(String clave, Object valor) =>
    {'success': true, clave: valor};

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.categorias: _ok('categorias', [
        {'id': 1, 'nombre': 'Pasteles'},
        {'id': 2, 'nombre': 'Galletas'},
      ]),
      ApiConstants.resenasDestacadas: _ok('resenas', [
        {'autor_nombre': 'Ana', 'comentario': 'Rico'},
      ]),
      ApiConstants.promocionesActivas: _ok('promociones', [
        {'tipo': 'banner', 'titulo': 'Primero'},
        {'tipo': 'banner', 'titulo': 'Segundo'},
        {'tipo': 'relampago', 'producto_id': 1},
        {'tipo': 'relampago'}, // sin producto: no entra
        {'tipo': 'temporada', 'producto_id': 2},
        {'tipo': 'destacado', 'producto_id': 3},
        {'tipo': 'otro', 'producto_id': 4},
      ]),
      ApiConstants.configuracionSeccion('contacto'): _ok('config', {
        'direccion': 'Centro',
        'horarios': '[{"sucursal": "Repostería", "horario": "9-8"}, '
            '{"sucursal": "Cafetería"}, {"sucursal": "Tercera"}]',
      }),
      ApiConstants.configuracionSeccion('personalizacion'): _ok('config', {
        'slides': [
          {'titulo': 'B', 'orden': 2, 'activo': true, 'imagen': 'local.png'},
          {'titulo': 'A', 'orden': 1, 'activo': true,
           'imagen': 'https://pier/a.jpg', 'cta': 'Ir'},
          {'titulo': 'Oculto', 'orden': 0, 'activo': false},
        ],
      }),
      ApiConstants.configuracionSeccion('inicio'): _ok('config', {}),
      ApiConstants.productosComprados: _ok('productos', [
        {'id': 1, 'nombre': 'Chocoflan', 'precio_unitario': 300},
        {'id': 99, 'nombre': 'Ya no existe', 'precio_chico': 80},
      ]),
      ApiConstants.misPedidos: _ok('pedidos', [
        {'id': 5, 'numero': 'P-5', 'estado': 'completado'},
        {'id': 6, 'numero': 'P-6', 'estado': 'en_preparacion'},
      ]),
    });

void main() {
  group('HomeViewModel: carga pública', () {
    test('sin backend usa categorías y slides de respaldo', () {
      final vm = _vm(FakeApiClient());
      expect(vm.nombresCategorias, HomeViewModel.categoriasDeRespaldo);
      expect(vm.slides, HomeViewModel.slidesDeRespaldo);
      expect(vm.sucursales, isEmpty);
      expect(vm.pedidoActivo, isNull);
      expect(vm.hayCompras, isFalse);
    });

    test('carga categorías, reseñas, promociones y configuración', () async {
      final vm = _vm(_backend());

      await vm.cargar();

      expect(vm.nombresCategorias, ['Pasteles', 'Galletas']);
      expect(vm.resenasDestacadas.single['autor_nombre'], 'Ana');
      expect(vm.promociones.banner!['titulo'], 'Primero');
      expect(vm.promociones.relampago, hasLength(1));
      expect(vm.promociones.temporada, hasLength(1));
      expect(vm.promociones.destacado, hasLength(1));
      expect(vm.contacto['direccion'], 'Centro');
      // Solo las 2 primeras sucursales con nombre.
      expect(vm.sucursales.map((s) => s['sucursal']),
          ['Repostería', 'Cafetería']);
      // Slides del panel: solo activos, por orden, imagen local → respaldo.
      expect(vm.slides.map((s) => s.titulo), ['A', 'B']);
      expect(vm.slides.first.imagen, 'https://pier/a.jpg');
      expect(vm.slides.first.cta, 'Ir');
      expect(vm.slides.last.cta, 'Ver Productos');
      expect(vm.slides.last.imagen, HomeViewModel.slidesDeRespaldo[1].imagen);
    });

    test('el carrusel de GET /contenido manda sobre Personalización (#168)',
        () async {
      final api = _backend()
        ..responder(ApiConstants.contenido, {
          'success': true,
          'contenido': {
            'inicio.carrusel': [
              {
                'imagen': 'local:producto1.webp',
                'titulo': 'Endulza tus momentos especiales',
                'subtitulo': 'Repostería artesanal desde 2009',
                'boton_texto': 'Ver Productos',
                'boton_enlace': '/productos',
              },
            ],
          },
        });
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.slides.map((s) => s.titulo),
          ['Endulza tus momentos especiales']);
      expect(vm.slides.single.imagen, 'assets/images/sitio/producto1.webp');
      expect(api.llamo(ApiConstants.contenido, metodo: 'GET'), isTrue);
    });

    test('si todo falla se queda con lo de respaldo', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.categorias, 'x')
        ..fallar(ApiConstants.resenasDestacadas, 'x')
        ..fallar(ApiConstants.promocionesActivas, 'x');
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.nombresCategorias, HomeViewModel.categoriasDeRespaldo);
      expect(vm.resenasDestacadas, isEmpty);
      expect(vm.promociones.banner, isNull);
      expect(vm.contacto, isEmpty);
      expect(vm.slides, HomeViewModel.slidesDeRespaldo);
    });
  });

  group('HomeViewModel: testimonios de Dirección (#169)', () {
    Map<String, dynamic> contenido(Map<String, dynamic> bloques) =>
        {'success': true, 'contenido': bloques};
    Map<String, dynamic> resena(int id) =>
        {'id': id, 'autor_nombre': 'Cliente $id', 'rating': 5};

    test('pide las reseñas con cantidad y estrellas, con título y subtítulo',
        () async {
      final api = _backend()
        ..responder(
            ApiConstants.contenido,
            contenido({
              'inicio.testimonios': {
                'titulo': 'Clientes felices',
                'subtitulo': 'Reseñas reales',
                'cantidad': 4,
                'min_estrellas': 5,
              },
            }));
      final vm = _vm(api);

      await vm.cargar();

      expect(
          api.llamo(ApiConstants.resenasDestacadasCon(
              limite: 4, minEstrellas: 5)),
          isTrue);
      expect(vm.testimonios?.titulo, 'Clientes felices');
      expect(vm.testimonios?.subtitulo, 'Reseñas reales');
    });

    test('nunca muestra más de la cantidad configurada', () async {
      final api = _backend()
        ..responder(
            ApiConstants.contenido,
            contenido({
              'inicio.testimonios': {'cantidad': 2, 'min_estrellas': 4},
            }))
        ..responder(ApiConstants.resenasDestacadas,
            _ok('resenas', [resena(1), resena(2), resena(3)]));
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.resenasDestacadas, hasLength(2));
      expect(vm.testimonios?.titulo, ConfigTestimonios.tituloPorDefecto);
    });

    test('sin reseñas que cumplan, la sección queda vacía', () async {
      final api = _backend()
        ..responder(
            ApiConstants.contenido,
            contenido({
              'inicio.testimonios': {'cantidad': 3, 'min_estrellas': 5},
            }));
      final vm = _vm(api);
      await vm.cargar();
      expect(vm.resenasDestacadas, isNotEmpty);

      api.responder(ApiConstants.resenasDestacadas, _ok('resenas', []));
      await vm.cargarResenasDestacadas();

      expect(vm.resenasDestacadas, isEmpty);
    });

    test('sin configuración pide las destacadas como antes', () async {
      final api = _backend();
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.testimonios, isNull);
      expect(api.ultima(ApiConstants.resenasDestacadas), isNotNull);
      expect(
          api.llamadas.any((l) => l.endpoint.startsWith(
              '${ApiConstants.resenasDestacadas}?')),
          isFalse);
    });
  });

  group('ConfigTestimonios.desdeContenido', () {
    test('usa la clave anterior si no viene la nueva', () {
      final config = ConfigTestimonios.desdeContenido({
        'inicio.testimonios_config': {
          'titulo': 'Opiniones',
          'cantidad': '3',
          'min_estrellas': '4',
        },
      });

      expect(config?.titulo, 'Opiniones');
      expect(config?.cantidad, 3);
      expect(config?.minEstrellas, 4);
      expect(config?.subtitulo, isNull);
    });

    test('fuera de rango o con otra forma no cuenta', () {
      for (final bloque in <Object?>[
        null,
        'texto',
        {'cantidad': 0, 'min_estrellas': 5},
        {'cantidad': 7, 'min_estrellas': 5},
        {'cantidad': 3, 'min_estrellas': 6},
        {'cantidad': 'x', 'min_estrellas': 5},
      ]) {
        expect(
          ConfigTestimonios.desdeContenido({'inicio.testimonios': bloque}),
          isNull,
          reason: '$bloque',
        );
      }
      expect(ConfigTestimonios.desdeContenido(null), isNull);
    });
  });

  group('resolverSlides', () {
    test('sin slides, el hero de Inicio cambia los textos del primero', () {
      final slides = resolverSlides(null, {
        'hero': '{"titulo": "Día de Muertos", "subtitulo": "Pan de muerto"}',
      })!;
      expect(slides.first.titulo, 'Día de Muertos');
      expect(slides.first.subtitulo, 'Pan de muerto');
      expect(slides.first.etiqueta, 'ARTESANAL');
      expect(slides, hasLength(3));
      expect(slides[1].ruta, RutaSlide.contacto);
    });

    test('hero sin subtítulo conserva el de respaldo', () {
      final slides = resolverSlides({'slides': '[]'}, {
        'hero': {'titulo': 'Hola'},
      })!;
      expect(slides.first.subtitulo,
          HomeViewModel.slidesDeRespaldo.first.subtitulo);
    });

    test('formatos inválidos dejan los de respaldo', () {
      expect(resolverSlides({'slides': '[no es json'}, null), isNull);
      expect(resolverSlides(null, {'hero': '{roto'}), isNull);
      expect(resolverSlides(null, {'hero': {'titulo': ''}}), isNull);
      expect(resolverSlides(null, null), isNull);
    });

    test('el carrusel del editor del sitio manda sobre el panel (#168)', () {
      final slides = resolverSlides(
        {
          'slides': [
            {'titulo': 'Del panel', 'orden': 1, 'activo': true},
          ],
        },
        {'hero': {'titulo': 'Hero viejo'}},
        carrusel: [
          {
            'imagen': 'local:producto3.webp',
            'titulo': 'Mostachón de maracuyá',
            'subtitulo': 'Explosión tropical en cada bocado',
            'boton_texto': 'Ver Productos',
            'boton_enlace': '/productos',
          },
          {
            'imagen': 'https://res.cloudinary.com/pier/image/upload/v1/rosca.jpg',
            'titulo': 'Rosca Cielito Lindo',
            'subtitulo': '',
            'boton_texto': 'Escríbenos',
            'boton_enlace': '/contacto',
          },
        ],
      )!;

      expect(slides.map((s) => s.titulo),
          ['Mostachón de maracuyá', 'Rosca Cielito Lindo']);
      expect(slides.first.subtitulo, 'Explosión tropical en cada bocado');
      expect(slides.first.cta, 'Ver Productos');
      expect(slides.first.etiqueta, '');
      expect(slides.first.imagen, 'assets/images/sitio/producto3.webp');
      expect(slides.first.ruta, RutaSlide.catalogo);
      expect(slides[1].subtitulo, '');
      expect(slides[1].cta, 'Escríbenos');
      expect(slides[1].imagen,
          'https://res.cloudinary.com/pier/image/upload/v1/rosca.jpg');
      expect(slides[1].ruta, RutaSlide.contacto);
    });

    test('una foto del carrusel que la app no tiene usa la de respaldo de su '
        'posición', () {
      final slides = resolverSlides(null, null, carrusel: [
        {'imagen': 'local:otra.png', 'titulo': 'Uno', 'boton_texto': 'Ver'},
        {'imagen': '', 'titulo': 'Dos', 'boton_texto': 'Ver'},
      ])!;

      expect(slides.map((s) => s.imagen), [
        HomeViewModel.slidesDeRespaldo[0].imagen,
        HomeViewModel.slidesDeRespaldo[1].imagen,
      ]);
    });

    test('un carrusel vacío o con otra forma deja el panel y el hero', () {
      final hero = {'hero': {'titulo': 'Día de Muertos'}};
      for (final carrusel in [<dynamic>[], 'no es lista', [1, 'dos']]) {
        expect(resolverSlides(null, hero, carrusel: carrusel)!.first.titulo,
            'Día de Muertos',
            reason: '$carrusel');
      }
    });
  });

  group('HomeViewModel: datos del usuario', () {
    test('pide de nuevo completa con el catálogo y halla el pedido activo',
        () async {
      final vm = _vm(_backend());

      await vm.cargarDatosUsuario();

      expect(vm.hayCompras, isTrue);
      expect(vm.pedidoActivo!.numero, 'P-6');
      final catalogo = [
        Product.fromJson({
          'id': 1,
          'nombre': 'Chocoflan',
          'descripcion': 'Del catálogo',
          'precio_chico': 320,
        }),
      ];
      final lista = vm.pideDeNuevo(catalogo);
      expect(lista.first.descripcion, 'Del catálogo');
      expect(lista.last.nombre, 'Ya no existe');
      expect(lista.last.precio, 80);

      vm.limpiarDatosUsuario();
      expect(vm.hayCompras, isFalse);
      expect(vm.pedidoActivo, isNull);
    });

    test('si el pedido activo cambió, lo vuelve a buscar', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargarDatosUsuario();
      expect(vm.pedidoActivo, isNotNull);

      api.responder(ApiConstants.misPedidos, {'success': true, 'pedidos': []});
      await vm.actualizarPedidoActivo();

      expect(vm.pedidoActivo, isNull);
    });

    test('si el backend falla se queda como estaba', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.productosComprados, 'x')
        ..fallar(ApiConstants.misPedidos, 'x');
      final vm = _vm(api);
      await vm.cargarDatosUsuario();
      expect(vm.hayCompras, isFalse);
      expect(vm.pedidoActivo, isNull);
    });

    test('sucursales: una sola o texto plano no cuentan', () async {
      final api = _backend()
        ..responder(ApiConstants.configuracionSeccion('contacto'),
            _ok('config', {'horarios': 'Lun a Sáb 9 a 8'}));
      final vm = _vm(api);
      await vm.cargarConfiguracion();
      expect(vm.sucursales, isEmpty);

      api.responder(ApiConstants.configuracionSeccion('contacto'),
          _ok('config', {'horarios': '[{"sucursal": "Única"}]'}));
      await vm.cargarConfiguracion();
      expect(vm.sucursales, isEmpty);

      api.responder(ApiConstants.configuracionSeccion('contacto'),
          _ok('config', {'horarios': '[roto'}));
      await vm.cargarConfiguracion();
      expect(vm.sucursales, isEmpty);
    });
  });

  group('tiempoRestante', () {
    final ahora = DateTime(2026, 10, 9, 12);
    test('días, horas, minutos y expirada', () {
      expect(tiempoRestante(null), '');
      expect(tiempoRestante('no es fecha'), '');
      expect(tiempoRestante('2026-10-11T15:00:00', ahora: ahora), '2d 3h');
      expect(tiempoRestante('2026-10-09T15:20:00', ahora: ahora), '3h 20m');
      expect(tiempoRestante('2026-10-09T12:45:00', ahora: ahora), '45m');
      expect(tiempoRestante('2026-10-08T12:00:00', ahora: ahora), 'Expirada');
    });
  });
}
