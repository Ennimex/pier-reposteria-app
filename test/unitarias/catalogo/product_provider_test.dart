// test/unitarias/catalogo/product_provider_test.dart — ProductProvider baja
// el catálogo y las promociones una sola vez aunque dos pantallas lo pidan al
// mismo tiempo (#341): al abrir la app, el Inicio y el Catálogo (montado en
// su pestaña) mandaban cada uno sus dos peticiones y la pantalla se armaba
// dos veces.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';

import '../../fakes/fake_api_client.dart';

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.productos: {
        'success': true,
        'productos': [
          {
            'id': 1,
            'nombre': 'Chocoflan',
            'descripcion': 'Rico',
            'precio_chico': 300,
            'categoria': 'Pasteles',
            'imagen_url': '',
            'activo': true,
          },
        ],
      },
      ApiConstants.promocionesActivas: {
        'success': true,
        'promociones': [
          {'producto_id': 1, 'tipo': 'temporada', 'descuento_porcentaje': 10},
        ],
      },
    });

ProductProvider _provider(FakeApiClient api) =>
    ProductProvider(repo: ProductosRepositoryRemote(api: api));

int _pedidas(FakeApiClient api, String endpoint) =>
    api.llamadas.where((llamada) => llamada.endpoint == endpoint).length;

void main() {
  group('ProductProvider.cargarProductos', () {
    test('dos pantallas que lo piden a la vez comparten la carga (#341)',
        () async {
      final api = _backend();
      final provider = _provider(api);
      var avisos = 0;
      provider.addListener(() => avisos++);

      await Future.wait([
        provider.cargarProductos(),
        provider.cargarProductos(),
      ]);

      expect(_pedidas(api, ApiConstants.productos), 1);
      expect(_pedidas(api, ApiConstants.promocionesActivas), 1);
      expect(provider.productos.single.nombre, 'Chocoflan');
      expect(provider.precioConDescuento('1', 300), 270);
      // Avisa al empezar y al terminar, una vez cada uno.
      expect(avisos, 2);
      expect(provider.isLoading, isFalse);
    }, tags: 'regresion');

    test('con el catálogo ya cargado no lo vuelve a pedir', () async {
      final api = _backend();
      final provider = _provider(api);
      await provider.cargarProductos();

      await provider.cargarProductos();

      expect(_pedidas(api, ApiConstants.productos), 1);
      expect(_pedidas(api, ApiConstants.promocionesActivas), 1);
    });

    test('refrescar los pide otra vez', () async {
      final api = _backend();
      final provider = _provider(api);
      await provider.cargarProductos();

      await provider.refrescar();

      expect(_pedidas(api, ApiConstants.productos), 2);
      expect(_pedidas(api, ApiConstants.promocionesActivas), 2);
      expect(provider.productos, hasLength(1));
    });

    test('si la carga falla, la siguiente lo vuelve a intentar', () async {
      final api = _backend()
        ..fallar(ApiConstants.productos, 'Servidor no disponible');
      final provider = _provider(api);

      await provider.cargarProductos();
      expect(provider.productos, isEmpty);
      expect(provider.errorMessage, 'Servidor no disponible');

      api.responder(ApiConstants.productos, {
        'success': true,
        'productos': [
          {'id': 2, 'nombre': 'Rosca', 'precio_chico': 380, 'activo': true},
        ],
      });
      await provider.cargarProductos();

      expect(_pedidas(api, ApiConstants.productos), 2);
      expect(provider.productos.single.nombre, 'Rosca');
      expect(provider.errorMessage, isNull);
    });
  });
}
