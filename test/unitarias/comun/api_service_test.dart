// test/unitarias/comun/api_service_test.dart — ApiService contra un cliente HTTP
// simulado (#13): sin red, se revisa la petición que realmente saldría.
// http.runWithClient sustituye el cliente que usan http.get/post/... dentro
// de la zona, así que ApiService no necesita cambios para probarse.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ejecuta [accion] con un cliente que registra la petición y responde
/// [status] con [cuerpo].
Future<(Map<String, dynamic>, http.Request?)> _con(
  Future<Map<String, dynamic>> Function(ApiService api) accion, {
  int status = 200,
  String cuerpo = '{"success": true}',
}) async {
  http.Request? peticion;
  final cliente = MockClient((req) async {
    peticion = req;
    return http.Response(cuerpo, status,
        headers: {'content-type': 'application/json'});
  });
  final r = await http.runWithClient(() => accion(ApiService()), () => cliente);
  return (r, peticion);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ApiService: URL y headers', () {
    test('GET arma la URL con el backend del ambiente y sin token', () async {
      final (r, req) = await _con((api) => api.get('/productos'));

      expect(req!.method, 'GET');
      expect(req.url.toString(), '${ApiConstants.baseUrl}/productos');
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(r['success'], isTrue);
    });

    test('GET-Auth manda el token guardado', () async {
      SharedPreferences.setMockInitialValues(
          {'pierreposteria_token': 'jwt-de-prueba'});

      final (_, req) = await _con((api) => api.getAuth('/carrito'));

      expect(req!.headers['Authorization'], 'Bearer jwt-de-prueba');
    });

    test('sin sesión, las llamadas Auth no mandan Authorization', () async {
      final (_, req) = await _con((api) => api.getAuth('/carrito'));

      expect(req!.headers.containsKey('Authorization'), isFalse);
    });

    test('POST manda el body como JSON', () async {
      final (_, req) = await _con(
          (api) => api.post('/auth/login', {'email': 'ana@example.com'}));

      expect(req!.method, 'POST');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(req.body), {'email': 'ana@example.com'});
    });

    test('POST, PUT y DELETE con sesión usan su método y el token', () async {
      SharedPreferences.setMockInitialValues({'pierreposteria_token': 'jwt'});

      final (_, post) =
          await _con((api) => api.postAuth('/carrito', {'cantidad': 1}));
      final (_, put) =
          await _con((api) => api.putAuth('/carrito/151', {'cantidad': 2}));
      final (_, delete) = await _con((api) => api.deleteAuth('/carrito/151'));

      expect([post!.method, put!.method, delete!.method],
          ['POST', 'PUT', 'DELETE']);
      for (final req in [post, put, delete]) {
        expect(req.headers['Authorization'], 'Bearer jwt');
      }
      expect(put.url.toString(), '${ApiConstants.baseUrl}/carrito/151');
      expect(jsonDecode(put.body), {'cantidad': 2});
    });
  });

  group('ApiService: respuestas con error', () {
    test('un error del backend conserva su mensaje y el resto del cuerpo',
        () async {
      final (r, _) = await _con(
        (api) => api.post('/pagos/confirmar', {}),
        status: 402,
        cuerpo: '{"message": "Pago rechazado", "status": "requires_action"}',
      );

      expect(r['success'], isFalse);
      expect(r['message'], 'Pago rechazado');
      expect(r['status'], 'requires_action');
    });

    test('un error sin mensaje usa uno genérico', () async {
      final (r, _) =
          await _con((api) => api.get('/productos'), status: 500, cuerpo: '{}');

      expect(r['success'], isFalse);
      expect(r['message'], 'Error del servidor');
    });

    test('una respuesta que no es JSON no rompe la app', () async {
      final (r, _) = await _con((api) => api.get('/productos'),
          cuerpo: '<html>502 Bad Gateway</html>');

      expect(r['success'], isFalse);
      expect(r['message'], 'Error al procesar la respuesta');
    });

    // Regresión de #112: sin red, el cliente veía el texto de la excepción.
    test('sin conexión devuelve un mensaje amigable en lugar de lanzar',
        () async {
      final cliente = MockClient((_) async => throw http.ClientException(
          "SocketException: Failed host lookup: 'pier.onrender.com'"));
      final llamadas = <Future<Map<String, dynamic>> Function(ApiService)>[
        (api) => api.get('/productos'),
        (api) => api.getAuth('/carrito'),
        (api) => api.post('/auth/login', {}),
        (api) => api.postAuth('/carrito', {}),
        (api) => api.putAuth('/carrito/1', {}),
        (api) => api.deleteAuth('/carrito/1'),
      ];

      for (final llamada in llamadas) {
        final r = await http.runWithClient(
            () => llamada(ApiService()), () => cliente);

        expect(r['success'], isFalse);
        expect(r['message'], ApiService.mensajeSinConexion);
      }
    }, tags: 'regresion');
  });

  group('ApiService: subir imagen', () {
    test('manda la imagen como multipart con el token y los campos',
        () async {
      SharedPreferences.setMockInitialValues({'pierreposteria_token': 'jwt'});
      final dir = await Directory.systemTemp.createTemp('pier_upload');
      final foto = File('${dir.path}/foto.png')..writeAsBytesSync([1, 2, 3]);
      http.BaseRequest? peticion;
      String? cuerpo;
      final cliente = MockClient.streaming((req, stream) async {
        peticion = req;
        cuerpo = utf8.decode(await stream.toBytes(), allowMalformed: true);
        return http.StreamedResponse(
            Stream.value(utf8.encode('{"success": true}')), 200);
      });

      final r = await http.runWithClient(
        () => ApiService()
            .uploadImageAuth('/resenas/7/foto', foto.path, {'tipo': 'resena'}),
        () => cliente,
      );
      await dir.delete(recursive: true);

      expect(r['success'], isTrue);
      expect(peticion!.method, 'POST');
      expect(peticion!.url.toString(), '${ApiConstants.baseUrl}/resenas/7/foto');
      expect(peticion!.headers['Authorization'], 'Bearer jwt');
      expect(cuerpo, contains('name="imagen"'));
      expect(cuerpo, contains('content-type: image/png'));
      expect(cuerpo, contains('name="tipo"'));
    });

    test('si el archivo no existe devuelve el error sin lanzar', () async {
      final r = await ApiService()
          .uploadImageAuth('/resenas/7/foto', 'no/existe.jpg', {});

      expect(r['success'], isFalse);
      expect(r['message'], 'No se pudo subir la imagen. Intenta de nuevo.');
    });
  });

  group('ApiService: sesión expirada (#218)', () {
    const conSesion = {
      'pierreposteria_token': 'jwt-vencido',
      'pierreposteria_current_user': '{"id":1}',
    };
    const vencido = '{"success": false, "message": "Token expirado"}';

    /// Corre [accion] contra un servidor que responde [status] y devuelve
    /// cuántos avisos de sesión expirada salieron.
    Future<(Map<String, dynamic>, int)> avisos(
      Future<Map<String, dynamic>> Function(ApiService api) accion, {
      int status = 401,
      String cuerpo = vencido,
    }) async {
      var avisos = 0;
      final suscripcion = ApiService().sesionExpirada.listen((_) => avisos++);
      final (r, _) = await _con(accion, status: status, cuerpo: cuerpo);
      await Future<void>.delayed(Duration.zero);
      await suscripcion.cancel();
      return (r, avisos);
    }

    test('un 401 con token borra la sesión del teléfono y avisa', () async {
      SharedPreferences.setMockInitialValues(conSesion);

      final (r, n) = await avisos((api) => api.getAuth('/carrito'));

      expect(n, 1);
      expect(r['success'], isFalse);
      expect(r['message'], 'Token expirado');
      expect(await StorageService().getToken(), isNull);
      expect(await StorageService().getUser(), isNull);
    });

    test('POST, PUT y DELETE con token también avisan', () async {
      final llamadas = <Future<Map<String, dynamic>> Function(ApiService)>[
        (api) => api.postAuth('/carrito', {'producto_id': 1}),
        (api) => api.putAuth('/carrito/1', {'cantidad': 2}),
        (api) => api.deleteAuth('/carrito/1'),
      ];
      for (final llamada in llamadas) {
        SharedPreferences.setMockInitialValues(conSesion);
        final (_, n) = await avisos(llamada);
        expect(n, 1);
      }
    });

    test('el 401 de cerrar sesión no vuelve a avisar', () async {
      SharedPreferences.setMockInitialValues(conSesion);

      final (_, n) =
          await avisos((api) => api.postAuth(ApiConstants.logout, {}));

      expect(n, 0);
    });

    test('sin sesión un 401 no es una sesión expirada', () async {
      final (_, n) = await avisos((api) => api.getAuth('/carrito'));

      expect(n, 0);
    });

    test('el 401 del inicio de sesión (credenciales malas) no avisa',
        () async {
      SharedPreferences.setMockInitialValues(conSesion);

      final (r, n) = await avisos(
        (api) => api.post(ApiConstants.login, {'email': 'a@b.mx'}),
        cuerpo: '{"success": false, "message": "Credenciales inválidas"}',
      );

      expect(n, 0);
      expect(r['message'], 'Credenciales inválidas');
      expect(await StorageService().getToken(), 'jwt-vencido');
    });

    test('otros errores (403, 500) no cierran la sesión', () async {
      for (final status in [403, 500]) {
        SharedPreferences.setMockInitialValues(conSesion);
        final (_, n) = await avisos((api) => api.getAuth('/carrito'),
            status: status, cuerpo: '{"success": false, "message": "x"}');
        expect(n, 0);
        expect(await StorageService().getToken(), 'jwt-vencido');
      }
    });

    test('subir una imagen con el token vencido también avisa', () async {
      SharedPreferences.setMockInitialValues(conSesion);
      final dir = await Directory.systemTemp.createTemp('pier_upload_401');
      final foto = File('${dir.path}/foto.png')..writeAsBytesSync([1, 2, 3]);
      var n = 0;
      final suscripcion = ApiService().sesionExpirada.listen((_) => n++);
      final cliente = MockClient.streaming((req, stream) async {
        await stream.drain<void>();
        return http.StreamedResponse(Stream.value(utf8.encode(vencido)), 401);
      });

      final r = await http.runWithClient(
        () => ApiService().uploadImageAuth('/resenas/7/foto', foto.path, {}),
        () => cliente,
      );
      await Future<void>.delayed(Duration.zero);
      await suscripcion.cancel();
      await dir.delete(recursive: true);

      expect(r['success'], isFalse);
      expect(n, 1);
    });
  });
}
