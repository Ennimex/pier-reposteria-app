// test/repositories_test.dart — los repositorios hablan con el ApiClient que
// reciben (aquí el falso): endpoint, método y body correctos, y devuelven la
// respuesta tal cual. Ninguna prueba toca la red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';

import 'fakes/fake_api_client.dart';

void main() {
  group('PedidosRepository', () {
    test('misPedidos usa GET autenticado y devuelve la respuesta', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/mis-pedidos': {
          'success': true,
          'pedidos': [
            {'id': 7, 'estado': 'listo'},
          ],
        },
      });
      final repo = PedidosRepository(api: api);

      final r = await repo.misPedidos();

      expect(r['success'], true);
      expect((r['pedidos'] as List).single['id'], 7);
      expect(api.llamo('/pedidos/mis-pedidos', metodo: 'GET-Auth'), true);
    });

    test('cancelar hace PUT a /pedidos/:id/cancelar', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/7/cancelar': {'success': true, 'message': 'Cancelado'},
      });
      await PedidosRepository(api: api).cancelar('7');
      expect(api.llamo('/pedidos/7/cancelar', metodo: 'PUT-Auth'), true);
    });

    test('un error del backend se devuelve, no se lanza', () async {
      final api = FakeApiClient()..fallar('/pedidos/mis-pedidos', 'Token expirado');
      final r = await PedidosRepository(api: api).misPedidos();
      expect(r['success'], false);
      expect(r['message'], 'Token expirado');
    });
  });

  group('CarritoRepository', () {
    test('agregar manda producto_id, cantidad y tamano', () async {
      final api = FakeApiClient(respuestas: {
        '/carrito': {'success': true},
      });
      await CarritoRepository(api: api)
          .agregar(productoId: 15, cantidad: 2, tamano: 'grande');

      final llamada = api.ultima('/carrito')!;
      expect(llamada.metodo, 'POST-Auth');
      expect(llamada.body, {
        'producto_id': 15,
        'cantidad': 2,
        'tamano': 'grande',
      });
    });

    test('actualizarCantidad y eliminarItem apuntan al item', () async {
      final api = FakeApiClient(respuestas: {
        '/carrito/99': {'success': true},
      });
      final repo = CarritoRepository(api: api);
      await repo.actualizarCantidad('99', 3);
      await repo.eliminarItem('99');

      expect(api.llamadas.map((l) => l.metodo).toList(),
          ['PUT-Auth', 'DELETE-Auth']);
      expect(api.llamadas.first.body, {'cantidad': 3});
    });
  });

  group('FavoritosRepository', () {
    test('agregar y quitar usan el mismo endpoint con POST y DELETE',
        () async {
      final api = FakeApiClient(respuestas: {
        '/favoritos/15': {'success': true},
      });
      final repo = FavoritosRepository(api: api);
      await repo.agregar('15');
      await repo.quitar('15');
      expect(api.llamo('/favoritos/15', metodo: 'POST-Auth'), true);
      expect(api.llamo('/favoritos/15', metodo: 'DELETE-Auth'), true);
    });
  });

  group('CuentaRepository', () {
    test('enviarContacto va autenticado solo con sesión', () async {
      final api = FakeApiClient(respuestas: {
        '/contacto': {'success': true},
      });
      final repo = CuentaRepository(api: api);
      await repo.enviarContacto({'mensaje': 'hola'}, conSesion: true);
      await repo.enviarContacto({'mensaje': 'hola'}, conSesion: false);
      expect(api.llamadas.map((l) => l.metodo).toList(),
          ['POST-Auth', 'POST']);
    });
  });

  group('EntregasRepository', () {
    test('subirEvidencia sube por multipart con tipo entrega', () async {
      final api = FakeApiClient(respuestas: {
        '/upload/imagen': {
          'success': true,
          'imagen': {'url': 'https://cdn/x.jpg'},
        },
      });
      final r = await EntregasRepository(api: api).subirEvidencia('/tmp/f.jpg');
      final llamada = api.ultima('/upload/imagen')!;
      expect(llamada.metodo, 'UPLOAD');
      expect(llamada.body, {'filePath': '/tmp/f.jpg', 'tipo': 'entrega'});
      expect((r['imagen'] as Map)['url'], 'https://cdn/x.jpg');
    });
  });

  group('ConfiguracionRepository', () {
    test('seccion arma la ruta pública', () async {
      final api = FakeApiClient(respuestas: {
        '/configuracion/legales': {
          'success': true,
          'config': {'privacidad': 'texto'},
        },
      });
      final r = await ConfiguracionRepository(api: api).seccion('legales');
      expect((r['config'] as Map)['privacidad'], 'texto');
      expect(api.llamo('/configuracion/legales', metodo: 'GET'), true);
    });
  });
}
