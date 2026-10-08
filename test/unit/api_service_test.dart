// test/unit/api_service_test.dart — ApiService contra un cliente HTTP
// simulado (#13): sin red, se revisa la petición que realmente saldría.
// http.runWithClient sustituye el cliente que usan http.get/post/... dentro
// de la zona, así que ApiService no necesita cambios para probarse.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
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

    test('sin conexión devuelve success:false en lugar de lanzar', () async {
      final cliente =
          MockClient((_) async => throw http.ClientException('sin red'));

      final r = await http.runWithClient(
          () => ApiService().get('/productos'), () => cliente);

      expect(r['success'], isFalse);
      expect(r['message'], startsWith('Error de conexión'));
    });
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
      expect(r['message'], startsWith('Error al subir la imagen'));
    });
  });
}
