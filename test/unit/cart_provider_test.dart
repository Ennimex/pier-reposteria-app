// test/unit/cart_provider_test.dart — lógica del carrito (#16) sin red: el
// backend es un FakeApiClient y se afirma qué se le pidió.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';

import '../fakes/fake_api_client.dart';

Product _producto({String id = '36', double precio = 100}) => Product(
      id: id,
      nombre: 'Fresa Matcha Bliss',
      descripcion: '',
      precio: precio,
      categoria: 'Pasteles',
      imagenUrl: '',
    );

/// Carrito como lo devuelve GET /carrito: una línea con descuento y otra sin.
Map<String, dynamic> _carritoDelBackend({int cantidadFresa = 2}) => {
      'success': true,
      'carrito': {
        'items': [
          {
            'producto_id': 36,
            'carrito_item_id': 151,
            'nombre': 'Fresa Matcha Bliss',
            'precio_unitario': '90.00',
            'precio_original': '100.00',
            'cantidad': cantidadFresa,
            'imagen_url': '',
            'tiene_descuento': true,
            'promo_nombre': 'Temporada de fresas',
            'tamano': 'chico',
          },
          {
            'producto_id': 12,
            'carrito_item_id': 152,
            'nombre': 'Pay de limón',
            'precio_unitario': '50.00',
            'precio_original': '50.00',
            'cantidad': 1,
            'imagen_url': '',
            'tiene_descuento': false,
            'tamano': 'grande',
          },
        ],
      },
    };

/// POST /carrito responde bien y GET /carrito falla: así el carrito conserva
/// lo agregado en local y se puede observar la lógica optimista.
FakeApiClient _backendQueAceptaSinRecargar() => FakeApiClient(respuestas: {
      ApiConstants.carrito: (LlamadaApi l) => l.metodo == 'POST-Auth'
          ? {'success': true}
          : {'success': false, 'message': 'sin recarga en esta prueba'},
    });

Future<CartProvider> _cargado(FakeApiClient api, {int cantidadFresa = 2}) async {
  api.responder(
      ApiConstants.carrito, _carritoDelBackend(cantidadFresa: cantidadFresa));
  final cart = CartProvider(repo: CarritoRepositoryRemote(api: api));
  await cart.cargarDesdeBackend();
  return cart;
}

void main() {
  group('CartProvider: carga y totales', () {
    test('carga las líneas del backend y calcula totales con descuento',
        () async {
      final cart = await _cargado(FakeApiClient());

      expect(cart.itemCount, 2);
      expect(cart.totalQuantity, 3);
      expect(cart.totalAmount, 230); // 90 x 2 + 50
      expect(cart.totalOriginal, 250); // 100 x 2 + 50
      expect(cart.totalAhorro, 20);
      expect(cart.tieneDescuentos, isTrue);
      expect(cart.isInCart('36'), isTrue);
      expect(cart.isInCart('99'), isFalse);

      final fresa = cart.items['36_chico']!;
      expect(fresa.carritoItemId, '151');
      expect(fresa.subtotal, 180);
      expect(fresa.ahorroTotal, 20);
      expect(fresa.promoNombre, 'Temporada de fresas');
      expect(cart.items['12_grande']!.ahorroTotal, 0);
    });

    test('si el backend falla, conserva lo que ya tenía', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api);

      api.fallar(ApiConstants.carrito, 'Token expirado');
      await cart.cargarDesdeBackend();

      expect(cart.itemCount, 2);
    });
  });

  group('CartProvider: agregar', () {
    test('envía producto, cantidad y tamaño al backend', () async {
      final api = _backendQueAceptaSinRecargar();
      final cart = CartProvider(repo: CarritoRepositoryRemote(api: api));

      await cart.addItem(_producto(), 2, 'grande', 180);

      final post = api.llamadas.firstWhere((l) => l.metodo == 'POST-Auth');
      expect(post.endpoint, ApiConstants.carrito);
      expect(post.body, {'producto_id': 36, 'cantidad': 2, 'tamano': 'grande'});
      expect(cart.items['36_grande']!.precio, 180);
    });

    test('el mismo producto suma cantidad; otro tamaño es otra línea',
        () async {
      final cart =
          CartProvider(repo: CarritoRepositoryRemote(api: _backendQueAceptaSinRecargar()));

      await cart.addItem(_producto());
      await cart.addItem(_producto());
      await cart.addItem(_producto(), 1, 'grande', 180);

      expect(cart.itemCount, 2);
      expect(cart.items['36_chico']!.quantity, 2);
      expect(cart.items['36_grande']!.quantity, 1);
      expect(cart.totalAmount, 380); // 100 x 2 + 180
    });

    test('tras agregar con éxito recarga desde el backend', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.carrito: (LlamadaApi l) => l.metodo == 'POST-Auth'
            ? {'success': true}
            : _carritoDelBackend(),
      });
      final cart = CartProvider(repo: CarritoRepositoryRemote(api: api));

      await cart.addItem(_producto());

      expect(api.llamo(ApiConstants.carrito, metodo: 'GET-Auth'), isTrue);
      expect(cart.items['36_chico']!.carritoItemId, '151');
      expect(cart.totalAmount, 230);
    });

    test('si el backend rechaza, revierte lo agregado en local', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.carrito, 'Producto agotado');
      final cart = CartProvider(repo: CarritoRepositoryRemote(api: api));
      var avisos = 0;
      cart.addListener(() => avisos++);

      await cart.addItem(_producto());

      expect(cart.itemCount, 0);
      expect(avisos, 2); // optimista + reversión
    });
  });

  group('CartProvider: quitar y vaciar', () {
    test('reducir una unidad actualiza la cantidad en el backend', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api, cantidadFresa: 3);

      await cart.removeSingleItem('36_chico');

      expect(cart.items['36_chico']!.quantity, 2);
      expect(api.ultima(ApiConstants.carritoItem('151'))?.metodo, 'PUT-Auth');
      expect(api.ultima(ApiConstants.carritoItem('151'))?.body, {'cantidad': 2});
    });

    test('reducir la última unidad elimina la línea', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api);

      await cart.removeSingleItem('12_grande');

      expect(cart.items.containsKey('12_grande'), isFalse);
      expect(
        api.llamo(ApiConstants.carritoItem('152'), metodo: 'DELETE-Auth'),
        isTrue,
      );
    });

    test('eliminar una línea la borra en local y en el backend', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api);

      await cart.removeItem('36_chico');

      expect(cart.itemCount, 1);
      expect(cart.totalAmount, 50);
      expect(
        api.llamo(ApiConstants.carritoItem('151'), metodo: 'DELETE-Auth'),
        isTrue,
      );
    });

    test('quitar una línea que no existe no hace nada', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api);
      final llamadasAntes = api.llamadas.length;

      await cart.removeSingleItem('99_chico');
      await cart.removeItem('99_chico');

      expect(cart.itemCount, 2);
      expect(api.llamadas.length, llamadasAntes);
    });

    test('vaciar borra todo en local y en el backend', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api);

      await cart.clearCart();

      expect(cart.itemCount, 0);
      expect(cart.totalAmount, 0);
      expect(api.llamo(ApiConstants.carrito, metodo: 'DELETE-Auth'), isTrue);
    });

    test('limpiar en local (logout) no toca el carrito del backend', () async {
      final api = FakeApiClient();
      final cart = await _cargado(api);
      final llamadasAntes = api.llamadas.length;

      cart.limpiarLocal();

      expect(cart.itemCount, 0);
      expect(api.llamadas.length, llamadasAntes);
    });
  });
}
