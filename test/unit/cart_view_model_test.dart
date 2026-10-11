// test/unit/cart_view_model_test.dart — «Mi Carrito» (MVVM, Fase 5) sin red:
// el ViewModel carga (sin sesión no pide nada), expone los totales del
// CartProvider, devuelve el motivo de cada rechazo y bloquea la línea
// mientras espera al backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_pasteleria/ui/cart/view_model/cart_view_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';

import '../fakes/fake_api_client.dart';

final String _linea151 = ApiConstants.carritoItem('151');

Map<String, dynamic> _carrito({int cantidad = 2}) => {
      'success': true,
      'carrito': {
        'items': [
          {
            'producto_id': 36,
            'carrito_item_id': 151,
            'nombre': 'Fresa Matcha Bliss',
            'precio_unitario': '90.00',
            'precio_original': '100.00',
            'cantidad': cantidad,
            'tiene_descuento': true,
          },
        ],
      },
    };

(CartViewModel, CartProvider, FakeApiClient) _armar({
  bool sesion = true,
  Map<String, dynamic>? respuestas,
}) {
  final api = FakeApiClient(respuestas: {
    ApiConstants.carrito: _carrito(),
    _linea151: {'success': true},
    ...?respuestas,
  });
  final carrito = CartProvider(repo: CarritoRepositoryRemote(api: api));
  final vm = CartViewModel(carrito: carrito, sesionIniciada: () => sesion);
  return (vm, carrito, api);
}

void main() {
  group('CartViewModel: carga', () {
    test('carga el carrito y expone sus totales', () async {
      final (vm, _, _) = _armar();
      expect(vm.cargando, isTrue);

      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.errorCarga, isNull);
      expect(vm.lineas.single.nombre, 'Fresa Matcha Bliss');
      expect(vm.totalProductos, 2);
      expect(vm.total, 180);
      expect(vm.totalOriginal, 200);
      expect(vm.ahorro, 20);
      expect(vm.tieneDescuentos, isTrue);
    });

    test('sin sesión no pide el carrito al backend', () async {
      final (vm, _, api) = _armar(sesion: false);

      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.lineas, isEmpty);
      expect(api.llamadas, isEmpty);
    });

    test('si falla con el carrito vacío expone el motivo', () async {
      final (vm, _, _) = _armar(respuestas: {
        ApiConstants.carrito: {'success': false, 'message': 'Sin conexión'},
      });

      await vm.cargar();

      expect(vm.errorCarga, 'Sin conexión');
    });

    test('si falla pero ya había líneas, las deja sin error', () async {
      final (vm, carrito, api) = _armar();
      await carrito.cargarDesdeBackend();
      api.fallar(ApiConstants.carrito, 'Sin conexión');

      await vm.cargar();

      expect(vm.errorCarga, isNull);
      expect(vm.lineas, hasLength(1));
    });

    test('avisa a la vista cuando cambia el carrito compartido', () async {
      final (vm, carrito, _) = _armar();
      var avisos = 0;
      vm.addListener(() => avisos++);

      carrito.limpiarLocal();

      expect(avisos, 1);
      vm.dispose();
      carrito.limpiarLocal();
      expect(avisos, 1);
    });
  });

  group('CartViewModel: cambios', () {
    test('incrementar y decrementar cambian la cantidad en el backend',
        () async {
      final (vm, _, api) = _armar();
      await vm.cargar();

      expect(await vm.incrementar(vm.lineas.single), isNull);
      expect(api.ultima(_linea151)?.body, {'cantidad': 3});

      expect(await vm.decrementar(vm.lineas.single), isNull);
      expect(api.ultima(_linea151)?.body, {'cantidad': 2});
      expect(vm.totalProductos, 2);
    });

    test('devuelve el motivo si el backend rechaza la cantidad', () async {
      final (vm, _, _) = _armar(respuestas: {
        _linea151: {'success': false, 'message': 'Solo quedan 2 unidades'},
      });
      await vm.cargar();

      final motivo = await vm.incrementar(vm.lineas.single);

      expect(motivo, 'Solo quedan 2 unidades');
      expect(vm.totalProductos, 2);
    });

    test('eliminar y vaciar dejan el carrito sin líneas', () async {
      final (vm, carrito, api) = _armar();
      await vm.cargar();

      expect(await vm.eliminar(vm.lineas.single), isNull);
      expect(vm.lineas, isEmpty);
      expect(api.llamo(_linea151, metodo: 'DELETE-Auth'), isTrue);

      await carrito.cargarDesdeBackend();
      expect(await vm.vaciar(), isNull);
      expect(vm.lineas, isEmpty);
      expect(api.llamo(ApiConstants.carrito, metodo: 'DELETE-Auth'), isTrue);
    });

    test('mientras una línea espera al backend no acepta otro cambio',
        () async {
      final (vm, _, api) = _armar();
      await vm.cargar();
      final linea = vm.lineas.single;
      api.demorar(_linea151, const Duration(milliseconds: 50));

      final primero = vm.incrementar(linea);
      expect(vm.ocupada(linea), isTrue);
      expect(await vm.incrementar(linea), isNull); // ignorado
      await primero;

      expect(vm.ocupada(linea), isFalse);
      expect(
        api.llamadas.where((l) => l.metodo == 'PUT-Auth'),
        hasLength(1),
      );
      expect(vm.totalProductos, 3);
    });

    test('si la pantalla se cerró a media carga no avisa', () async {
      final (vm, _, api) = _armar();
      api.demorar(ApiConstants.carrito, const Duration(milliseconds: 20));
      final carga = vm.cargar();

      vm.dispose();
      await carga;

      expect(vm.cargando, isTrue);
    });
  });
}
