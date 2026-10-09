// test/unit/profile_view_model_test.dart — «Mi Perfil» (MVVM, Fase 3) sin
// red: los repositorios tipan favoritos y el detalle del pedido, y el
// ViewModel lleva las dos secciones y «Volver a pedir».
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/more/view_model/profile_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _favoritos = ApiConstants.favoritos;
const String _pedidos = ApiConstants.misPedidos;
final String _detalle9 = ApiConstants.pedidoById('9');

final Map<String, dynamic> _conDatos = {
  _favoritos: {
    'success': true,
    'favoritos': [
      {'id': 36, 'nombre': 'Fresa Matcha Bliss', 'precio_chico': '320'},
      'basura',
    ],
  },
  _pedidos: {
    'success': true,
    'pedidos': [
      {'id': 9, 'numero': 'PIER-9', 'estado': 'entregado', 'total': '640'},
    ],
  },
};

ProfileViewModel _vm(FakeApiClient api) => ProfileViewModel(
      favoritosRepo: FavoritosRepository(api: api),
      pedidosRepo: PedidosRepository(api: api),
    );

/// Carrito falso: registra (id, cantidad, tamaño, precio).
class _Carrito {
  final List<(String, int, String, double)> lineas = [];

  Future<void> agregar(Product p, int cantidad, String tamano, double precio) {
    lineas.add((p.id, cantidad, tamano, precio));
    return Future.value();
  }
}

void main() {
  group('Repositorios', () {
    test('listarProductos tipa, marca activos e ignora lo que no es objeto',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);

      final lista = await FavoritosRepository(api: api).listarProductos();

      expect(lista.map((p) => p.id), ['36']);
      expect(lista.first.disponible, isTrue);
      expect(api.llamo(_favoritos, metodo: 'GET-Auth'), isTrue);
    });

    test('listarProductos lanza ApiException si el backend falla', () async {
      final api = FakeApiClient()..fallar(_favoritos, 'Token expirado');
      await expectLater(
        FavoritosRepository(api: api).listarProductos(),
        throwsA(isA<ApiException>()),
      );
    });

    test('itemsDelPedido lee producto_id e imagen', () async {
      final api = FakeApiClient(
        respuestas: {
          _detalle9: {
            'success': true,
            'items': [
              {
                'producto_id': 36,
                'nombre_producto': 'Fresa Matcha Bliss',
                'cantidad': '2',
                'precio_unitario': '320',
                'imagen_url': 'https://x/fresa.jpg',
              },
            ],
          },
        },
      );

      final items = await PedidosRepository(api: api).itemsDelPedido('9');

      expect(items.single.productoId, '36');
      expect(items.single.cantidad, 2);
      expect(items.single.imagenUrl, 'https://x/fresa.jpg');
    });

    test('itemsDelPedido lanza ApiException si el backend falla', () async {
      final api = FakeApiClient()..fallar(_detalle9, 'Pedido no encontrado');
      await expectLater(
        PedidosRepository(api: api).itemsDelPedido('9'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ProfileViewModel', () {
    test('arranca cargando las dos secciones', () {
      final vm = _vm(FakeApiClient());
      expect(vm.cargandoFavoritos, isTrue);
      expect(vm.cargandoPedidos, isTrue);
    });

    test('carga favoritos y pedidos', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      await vm.cargar();

      expect(vm.cargandoFavoritos, isFalse);
      expect(vm.cargandoPedidos, isFalse);
      expect(vm.favoritos.single.nombre, 'Fresa Matcha Bliss');
      expect(vm.pedidos.single.numero, 'PIER-9');
    });

    test('si una sección falla la otra se carga igual', () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_favoritos, 'Sin conexión');
      final vm = _vm(api);
      await vm.cargar();

      expect(vm.favoritos, isEmpty);
      expect(vm.cargandoFavoritos, isFalse);
      expect(vm.pedidos, hasLength(1));
    });

    test('reordenar agrega los productos con producto_id', () async {
      final api = FakeApiClient(
        respuestas: {
          _detalle9: {
            'success': true,
            'items': [
              {
                'producto_id': 36,
                'nombre_producto': 'Fresa',
                'cantidad': 2,
                'tamano': 'grande',
                'precio_unitario': '450',
              },
              {'nombre_producto': 'Sin id', 'cantidad': 1},
              {'producto_id': 40, 'nombre_producto': 'Pay', 'precio_unitario': 90},
            ],
          },
        },
      );
      final vm = _vm(api);
      final carrito = _Carrito();
      final durante = <String?>[];
      vm.addListener(() => durante.add(vm.reordenandoId));

      final r = await vm.reordenar('9', agregar: carrito.agregar);

      expect(r, ResultadoReorden.agregado);
      expect(carrito.lineas, [
        ('36', 2, 'grande', 450.0),
        ('40', 1, 'chico', 90.0),
      ]);
      expect(durante, ['9', null]);
      expect(vm.reordenandoId, isNull);
    });

    test('reordenar sin productos o con error avisa sinProductos', () async {
      final api = FakeApiClient()..fallar(_detalle9, 'Pedido no encontrado');
      final carrito = _Carrito();

      final r = await _vm(api).reordenar('9', agregar: carrito.agregar);

      expect(r, ResultadoReorden.sinProductos);
      expect(carrito.lineas, isEmpty);
    });

    test('reordenar sin ningún producto_id avisa ningunoAgregado', () async {
      final api = FakeApiClient(
        respuestas: {
          _detalle9: {
            'success': true,
            'items': [
              {'nombre_producto': 'Sin id', 'cantidad': 1},
            ],
          },
        },
      );

      final r = await _vm(api).reordenar('9', agregar: _Carrito().agregar);

      expect(r, ResultadoReorden.ningunoAgregado);
    });

    test('no reordena dos pedidos a la vez', () async {
      final api = FakeApiClient(
        respuestas: {
          _detalle9: {'success': true, 'items': <Object>[]},
        },
      )..demorar(_detalle9, const Duration(milliseconds: 20));
      final vm = _vm(api);
      final carrito = _Carrito();

      final primero = vm.reordenar('9', agregar: carrito.agregar);
      final segundo = await vm.reordenar('9', agregar: carrito.agregar);
      await primero;

      expect(segundo, ResultadoReorden.ocupado);
      expect(api.llamadas, hasLength(1));
    });
  });
}
