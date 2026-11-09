// test/unitarias/comun/repositories_test.dart — los repositorios hablan con el ApiClient que
// reciben (aquí el falso): endpoint, método y body correctos, y devuelven la
// respuesta tal cual (o, los ya tipados, el modelo o ApiException). Ninguna
// prueba toca la red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';

import '../../fakes/fake_api_client.dart';

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
      final repo = PedidosRepositoryRemote(api: api);

      final r = await repo.misPedidos();

      expect(r['success'], true);
      expect((r['pedidos'] as List).single['id'], 7);
      expect(api.llamo('/pedidos/mis-pedidos', metodo: 'GET-Auth'), true);
    });

    test('cancelarPedido hace PUT a /pedidos/:id/cancelar', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/7/cancelar': {'success': true, 'message': 'Cancelado'},
      });
      final mensaje =
          await PedidosRepositoryRemote(api: api).cancelarPedido('7');
      expect(mensaje, 'Cancelado');
      expect(api.llamo('/pedidos/7/cancelar', metodo: 'PUT-Auth'), true);
    });

    test('#40: sin mensaje, con reembolso generado lo dice', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/7/cancelar': {'success': true, 'reembolso_generado': true},
      });
      expect(
        await PedidosRepositoryRemote(api: api).cancelarPedido('7'),
        'Pedido cancelado; tu reembolso ya está en proceso',
      );
    });

    test('#40: sin mensaje y sin reembolso no promete uno', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/7/cancelar': {'success': true, 'reembolso_generado': false},
      });
      expect(
        await PedidosRepositoryRemote(api: api).cancelarPedido('7'),
        'Pedido cancelado',
      );
    });

    test('cancelarPedido rechazado lanza ApiException con el motivo',
        () async {
      final api = FakeApiClient()
        ..fallar('/pedidos/7/cancelar',
            'Un repartidor ya tomó tu pedido; ya no es posible cancelarlo');
      await expectLater(
        PedidosRepositoryRemote(api: api).cancelarPedido('7'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Un repartidor ya tomó tu pedido; ya no es posible cancelarlo')),
      );
    });

    test('obtenerPedido junta el pedido con sus items', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/7': {
          'success': true,
          'pedido': {'id': 7, 'numero': 'PIER-1', 'estado': 'listo'},
          'items': [
            {'nombre_producto': 'Chocoflan', 'cantidad': 2, 'subtotal': 300},
            'basura',
          ],
        },
      });

      final pedido = await PedidosRepositoryRemote(api: api).obtenerPedido('7');

      expect(pedido.numero, 'PIER-1');
      expect(pedido.items.single.nombre, 'Chocoflan');
      expect(pedido.items.single.subtotal, 300);
    });

    test('obtenerPedido sin items devuelve el pedido sin productos', () async {
      final api = FakeApiClient(respuestas: {
        '/pedidos/7': {
          'success': true,
          'pedido': {'id': 7, 'numero': 'PIER-1'},
        },
      });

      final pedido = await PedidosRepositoryRemote(api: api).obtenerPedido('7');

      expect(pedido.items, isEmpty);
    });

    test('obtenerPedido de otro usuario lanza ApiException', () async {
      final api = FakeApiClient()..fallar('/pedidos/7', 'Sin permiso');
      await expectLater(
        PedidosRepositoryRemote(api: api).obtenerPedido('7'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Sin permiso')),
      );
    });

    test('un error del backend se devuelve, no se lanza', () async {
      final api = FakeApiClient()..fallar('/pedidos/mis-pedidos', 'Token expirado');
      final r = await PedidosRepositoryRemote(api: api).misPedidos();
      expect(r['success'], false);
      expect(r['message'], 'Token expirado');
    });
  });

  group('CarritoRepository', () {
    test('agregar manda producto_id, cantidad y tamano', () async {
      final api = FakeApiClient(respuestas: {
        '/carrito': {'success': true},
      });
      await CarritoRepositoryRemote(api: api)
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
      final repo = CarritoRepositoryRemote(api: api);
      await repo.actualizarCantidad('99', 3);
      await repo.eliminarItem('99');

      expect(api.llamadas.map((l) => l.metodo).toList(),
          ['PUT-Auth', 'DELETE-Auth']);
      expect(api.llamadas.first.body, {'cantidad': 3});
    });

    test('obtener convierte las líneas del carrito', () async {
      final api = FakeApiClient(respuestas: {
        '/carrito': {
          'success': true,
          'carrito': {
            'items': [
              {'producto_id': 15, 'cantidad': 2, 'precio_unitario': '80.00'},
              'basura',
            ],
          },
        },
      });

      final lineas = await CarritoRepositoryRemote(api: api).obtener();

      expect(lineas, hasLength(1));
      expect(lineas.single.lineKey, '15_chico');
      expect(lineas.single.subtotal, 160);
    });

    test('obtener sin carrito devuelve una lista vacía', () async {
      final api = FakeApiClient(respuestas: {
        '/carrito': {'success': true},
      });

      expect(await CarritoRepositoryRemote(api: api).obtener(), isEmpty);
    });

    test('si el backend rechaza, lanza ApiException con su mensaje', () async {
      final api = FakeApiClient()
        ..fallar('/carrito', 'Solo quedan 2 unidades')
        ..responder('/carrito/99', {'success': false});
      final repo = CarritoRepositoryRemote(api: api);

      await expectLater(
        repo.agregar(productoId: 15, cantidad: 3, tamano: 'chico'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Solo quedan 2 unidades')),
      );
      await expectLater(repo.vaciar(), throwsA(isA<ApiException>()));
      await expectLater(
        repo.eliminarItem('99'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'No se pudo quitar el producto')),
      );
    });
  });

  group('FavoritosRepository', () {
    test('agregar y quitar usan el mismo endpoint con POST y DELETE',
        () async {
      final api = FakeApiClient(respuestas: {
        '/favoritos/15': {'success': true},
      });
      final repo = FavoritosRepositoryRemote(api: api);
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
      final repo = CuentaRepositoryRemote(api: api);
      Future<void> enviar({required bool conSesion}) => repo.enviarContacto(
            nombre: 'Ana',
            email: 'ana@pier.mx',
            telefono: '',
            tipoProducto: 'Otro',
            mensaje: 'hola',
            conSesion: conSesion,
          );
      await enviar(conSesion: true);
      await enviar(conSesion: false);
      expect(api.llamadas.map((l) => l.metodo).toList(),
          ['POST-Auth', 'POST']);
    });

    group('foto de perfil (#345)', () {
      const url = 'https://res.cloudinary.com/pier/perfil/ana.webp';

      test('subirFotoPerfil sube por multipart con tipo perfil', () async {
        final api = FakeApiClient(respuestas: {
          ApiConstants.uploadImagen: {
            'success': true,
            'imagen': {'url': url, 'public_id': 'perfil/ana'},
          },
        });

        expect(await CuentaRepositoryRemote(api: api).subirFotoPerfil('/a.jpg'),
            url);
        final llamada = api.llamadas.single;
        expect(llamada.metodo, 'UPLOAD');
        expect(llamada.body, {'filePath': '/a.jpg', 'tipo': 'perfil'});
      });

      test('actualizarFotoPerfil manda solo avatar_url (null la quita)',
          () async {
        final api = FakeApiClient(respuestas: {
          ApiConstants.updateProfileData: {
            'success': true,
            'user': {'id': 9, 'avatar_url': url},
          },
        });
        final repo = CuentaRepositoryRemote(api: api);

        expect((await repo.actualizarFotoPerfil(url))['avatar_url'], url);
        await repo.actualizarFotoPerfil(null);

        expect(api.llamadas.map((l) => l.metodo), ['PUT-Auth', 'PUT-Auth']);
        expect(api.llamadas.map((l) => l.body), [
          {'avatar_url': url},
          {'avatar_url': null},
        ]);
      });

      test('si el backend la rechaza lanza su mensaje', () async {
        final api = FakeApiClient()
          ..fallar(ApiConstants.updateProfileData,
              'La foto debe subirse desde la página');

        await expectLater(
          CuentaRepositoryRemote(api: api).actualizarFotoPerfil(url),
          throwsA(isA<ApiException>().having((e) => e.message, 'message',
              'La foto debe subirse desde la página')),
        );
      });
    });

    group('eliminarCuenta (#222)', () {
      Future<void> eliminar(Map<String, dynamic> respuesta) =>
          CuentaRepositoryRemote(
            api: FakeApiClient()
              ..responder(ApiConstants.eliminarCuenta, respuesta),
          ).eliminarCuenta();

      test('manda DELETE /usuarios/perfil con el token de la sesión',
          () async {
        final api = FakeApiClient()
          ..responder(ApiConstants.eliminarCuenta,
              {'success': true, 'message': 'Tu cuenta se eliminó'});

        await CuentaRepositoryRemote(api: api).eliminarCuenta();

        expect(api.llamadas, hasLength(1));
        final llamada = api.llamadas.single;
        expect(llamada.endpoint, '/usuarios/perfil');
        expect(llamada.metodo, 'DELETE-Auth');
      });

      test('409 con pedidos en curso lanza el mensaje y el código', () async {
        await expectLater(
          eliminar({
            'success': false,
            'codigo': 'PEDIDOS_EN_CURSO',
            'message': 'Tienes pedidos en curso; espera a que se entreguen '
                'o cancélalos',
          }),
          throwsA(isA<ApiException>()
              .having((e) => e.codigo, 'codigo', 'PEDIDOS_EN_CURSO')
              .having((e) => e.message, 'message',
                  startsWith('Tienes pedidos en curso'))),
        );
      });

      test('401 de una cuenta inactiva lanza SesionInvalidaException',
          () async {
        await expectLater(
          eliminar({
            'success': false,
            'codigo': 'SESION_INVALIDA',
            'message': 'Tu sesión ya no es válida',
          }),
          throwsA(isA<SesionInvalidaException>()
              .having((e) => e.codigo, 'codigo', 'SESION_INVALIDA')
              .having((e) => e.message, 'message',
                  'Tu sesión ya no es válida')),
        );
      });

      test('401, 403 o 500 sin código lanzan el mensaje del backend',
          () async {
        for (final mensaje in [
          'Token expirado',
          'Las cuentas del personal no se dan de baja desde aquí',
          'No se pudo eliminar tu cuenta',
        ]) {
          await expectLater(
            eliminar({'success': false, 'message': mensaje}),
            throwsA(allOf(
              isA<ApiException>()
                  .having((e) => e.message, 'message', mensaje)
                  .having((e) => e.codigo, 'codigo', isNull),
              isNot(isA<SesionInvalidaException>()),
            )),
          );
        }
      });

      test('sin mensaje del backend usa el genérico', () async {
        await expectLater(
          eliminar({'success': false}),
          throwsA(isA<ApiException>().having(
              (e) => e.message, 'message', 'No se pudo eliminar tu cuenta')),
        );
      });
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
      final url = await EntregasRepositoryRemote(api: api).subirEvidencia('/tmp/f.jpg');
      final llamada = api.ultima('/upload/imagen')!;
      expect(llamada.metodo, 'UPLOAD');
      expect(llamada.body, {'filePath': '/tmp/f.jpg', 'tipo': 'entrega'});
      expect(url, 'https://cdn/x.jpg');
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
      final r = await ConfiguracionRepositoryRemote(api: api).seccion('legales');
      expect((r['config'] as Map)['privacidad'], 'texto');
      expect(api.llamo('/configuracion/legales', metodo: 'GET'), true);
    });

    test('contenido lee sin sesión los bloques del editor del sitio (#168)',
        () async {
      final api = FakeApiClient(respuestas: {
        '/contenido': {
          'success': true,
          'contenido': {
            'inicio.carrusel': [
              {'titulo': 'Endulza tus momentos especiales'},
            ],
          },
          'actualizado': {'inicio.carrusel': '2026-10-18T03:57:42.421Z'},
        },
      });

      final c = await ConfiguracionRepositoryRemote(api: api).contenido();

      expect(c['inicio.carrusel'], [
        {'titulo': 'Endulza tus momentos especiales'},
      ]);
      expect(api.llamo('/contenido', metodo: 'GET'), true);
    });

    test('contenido que falla lanza ApiException con su mensaje', () async {
      final api = FakeApiClient()
        ..fallar('/contenido', 'Error al obtener el contenido');

      await expectLater(
        ConfiguracionRepositoryRemote(api: api).contenido(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Error al obtener el contenido')),
      );
    });
  });
}
