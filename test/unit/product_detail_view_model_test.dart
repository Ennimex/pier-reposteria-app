// test/unit/product_detail_view_model_test.dart — ViewModel del detalle de
// producto (MVVM, Fase 4) sin red, más el modelo DetalleProducto y la fecha
// relativa de las reseñas.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/detalle_producto.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/products/view_model/product_detail_view_model.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_resenas.dart';

import '../fakes/fake_api_client.dart';

final Product _pastel = Product.fromJson({
  'id': 7,
  'nombre': 'Chocoflan',
  'precio_chico': 300,
  'precio_grande': 520,
  'imagen_url': 'https://pier/chocoflan.jpg',
  'rating': 4,
  'reviews': 3,
  'activo': true,
});

Map<String, dynamic> _resena(int id, {int likes = 2, bool marcada = false}) => {
      'id': id,
      'autor_nombre': 'Ana',
      'autor_apellido': 'García',
      'rating': 5,
      'comentario': 'Riquísimo',
      'created_at': '2026-10-01T12:00:00Z',
      'likes_count': likes,
      'user_has_liked': marcada,
    };

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.productoById('7'): {
        'success': true,
        'producto': {
          'imagenes': [
            {'url': 'https://pier/1.jpg'},
            'https://pier/2.jpg',
            {'url': ''},
          ],
          'reviews': 12,
          'rating_promedio': '4.6',
        },
        'resenas': [_resena(1), _resena(2, likes: 5, marcada: true)],
      },
      ApiConstants.favoritosIds: {
        'success': true,
        'ids': [7, 9],
      },
      ApiConstants.favoritoById('7'): {'success': true},
      ApiConstants.recomendaciones('7'): {
        'success': true,
        'recomendaciones': [
          {'id': 7, 'nombre': 'Chocoflan'},
          {'id': 8, 'nombre': 'Pay de queso', 'precio_chico': 250},
          {'nombre': 'Sin id'},
        ],
      },
      ApiConstants.likeResena('1'): {'success': true, 'liked': true},
      ApiConstants.clicsAgotados: {'success': true},
    });

ProductDetailViewModel _vm(FakeApiClient api, {Product? producto}) =>
    ProductDetailViewModel(
      producto: producto ?? _pastel,
      productosRepo: ProductosRepositoryRemote(api: api),
      favoritosRepo: FavoritosRepositoryRemote(api: api),
      resenasRepo: ResenasRepositoryRemote(api: api),
      demandaRepo: DemandaRepositoryRemote(api: api),
    );

void main() {
  group('ProductDetailViewModel: carga', () {
    test('antes de cargar usa lo que trae el producto', () {
      final vm = _vm(FakeApiClient());
      expect(vm.imagenes, ['https://pier/chocoflan.jpg']);
      expect(vm.totalResenas, 3);
      expect(vm.rating, 4);
      expect(vm.cargandoResenas, isTrue);
    });

    test('carga galería, reseñas, favorito y recomendaciones', () async {
      final vm = _vm(_backend());

      await vm.cargar(autenticado: true);

      expect(vm.imagenes, ['https://pier/1.jpg', 'https://pier/2.jpg']);
      expect(vm.totalResenas, 12);
      expect(vm.rating, 4.6);
      expect(vm.cargandoResenas, isFalse);
      expect(vm.resenas, hasLength(2));
      expect(vm.resenas.first.autor, 'Ana G.');
      expect(vm.resenas.last.utilCount, 5);
      expect(vm.resenas.last.marcadaUtil, isTrue);
      expect(vm.esFavorito, isTrue);
      // Sin el propio producto ni los que no traen id.
      expect(vm.recomendaciones.map((p) => p.id), ['8']);
    });

    test('sin sesión no pregunta por el favorito', () async {
      final api = _backend();
      final vm = _vm(api);

      await vm.cargar(autenticado: false);

      expect(vm.esFavorito, isFalse);
      expect(api.llamo(ApiConstants.favoritosIds), isFalse);
    });

    test('si el backend falla deja de cargar y conserva lo del producto',
        () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.productoById('7'), 'caído')
        ..fallar(ApiConstants.favoritosIds, 'caído')
        ..fallar(ApiConstants.recomendaciones('7'), 'caído');
      final vm = _vm(api);

      await vm.cargar(autenticado: true);

      expect(vm.cargandoResenas, isFalse);
      expect(vm.resenas, isEmpty);
      expect(vm.imagenes, ['https://pier/chocoflan.jpg']);
      expect(vm.recomendaciones, isEmpty);
    });
  });

  group('ProductDetailViewModel: acciones', () {
    test('quitar el favorito va al backend y si falla se revierte', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargarFavorito(autenticado: true);

      expect(await vm.alternarFavorito(), isNull);
      expect(vm.esFavorito, isFalse);
      expect(api.llamo(ApiConstants.favoritoById('7'), metodo: 'DELETE-Auth'),
          isTrue);

      api.fallar(ApiConstants.favoritoById('7'), 'Sin sesión');
      expect(await vm.alternarFavorito(), 'Sin sesión');
      expect(vm.esFavorito, isFalse);
    });

    test('marcar útil suma al instante y si falla se revierte', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargarDetalle();

      expect(await vm.alternarUtil('1'), isNull);
      expect(vm.resenas.first.marcadaUtil, isTrue);
      expect(vm.resenas.first.utilCount, 3);

      api.fallar(ApiConstants.likeResena('2'), 'Token expirado');
      expect(await vm.alternarUtil('2'), 'Token expirado');
      expect(vm.resenas.last.marcadaUtil, isTrue);
      expect(vm.resenas.last.utilCount, 5);
    });

    test('un segundo toque mientras va el primero se ignora', () async {
      final api = _backend()
        ..demorar(ApiConstants.likeResena('1'), const Duration(milliseconds: 5));
      final vm = _vm(api);
      await vm.cargarDetalle();

      final primero = vm.alternarUtil('1');
      expect(await vm.alternarUtil('1'), isNull);
      await primero;

      expect(vm.resenas.first.utilCount, 3);
      expect(
          api.llamadas.where((l) => l.endpoint == ApiConstants.likeResena('1')),
          hasLength(1));
      expect(await vm.alternarUtil('no-existe'), isNull);
    });

    test('tamaño y cantidad con sus límites', () {
      final vm = _vm(FakeApiClient());
      expect(vm.tieneTamanos, isTrue);
      expect(vm.precioBase, 300);
      expect(vm.tamanoParaCarrito, 'chico');

      vm.elegirTamano(1);
      expect(vm.precioBase, 520);
      expect(vm.tamanoParaCarrito, 'grande');

      vm.quitarPieza();
      expect(vm.cantidad, 1);
      for (var i = 0; i < 12; i++) {
        vm.sumarPieza();
      }
      expect(vm.cantidad, ProductDetailViewModel.cantidadMaxima);
      vm.quitarPieza();
      expect(vm.cantidad, 9);
    });

    test('sin precio grande se estima y no hay selector', () {
      final vm = _vm(FakeApiClient(),
          producto: Product.fromJson({'id': 3, 'precio_chico': 100}));
      expect(vm.tieneTamanos, isFalse);
      expect(vm.precioDeTamano(1), closeTo(140, 0.001));
    });

    test('Avísame registra el clic en el agotado', () async {
      final api = _backend();
      _vm(api).avisarme();
      await Future<void>.delayed(Duration.zero);
      expect(api.ultima(ApiConstants.clicsAgotados)!.body, {'producto_id': 7});
    });
  });

  group('DetalleProducto.fromJson', () {
    test('imágenes como texto JSON', () {
      final d = DetalleProducto.fromJson({
        'success': true,
        'producto': {'imagenes': '["https://a.jpg", {"url": "https://b.jpg"}]'},
      });
      expect(d.imagenes, ['https://a.jpg', 'https://b.jpg']);
      expect(d.resenas, isEmpty);
      expect(d.totalResenas, 0);
    });

    test('JSON inválido o sin producto deja todo vacío', () {
      expect(
          DetalleProducto.fromJson({
            'producto': {'imagenes': '[no es json'},
          }).imagenes,
          isEmpty);
      expect(DetalleProducto.fromJson({}).imagenes, isEmpty);
    });
  });

  group('fechaRelativa', () {
    final ahora = DateTime(2026, 10, 9, 12);
    test('de hoy a meses', () {
      expect(fechaRelativa(null), '');
      expect(fechaRelativa(ahora, ahora: ahora), 'Hoy');
      expect(fechaRelativa(DateTime(2026, 10, 8, 11), ahora: ahora), 'Ayer');
      expect(fechaRelativa(DateTime(2026, 10, 5, 12), ahora: ahora),
          'Hace 4 días');
      expect(fechaRelativa(DateTime(2026, 9, 24, 12), ahora: ahora),
          'Hace 2 sem.');
      expect(fechaRelativa(DateTime(2026, 7, 1, 12), ahora: ahora),
          'Hace 3 mes');
    });
  });
}
