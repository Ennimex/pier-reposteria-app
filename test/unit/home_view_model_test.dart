// test/unit/home_view_model_test.dart — ViewModel del inicio (MVVM, Fase 4)
// sin red: carga pública, slides configurables, sucursales, datos del
// usuario y el tiempo restante de las promociones.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/domain/models/slide_hero.dart';
import 'package:pier_pasteleria/ui/home/view_model/home_view_model.dart';

import '../fakes/fake_api_client.dart';

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
