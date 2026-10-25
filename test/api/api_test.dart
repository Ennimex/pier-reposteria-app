// test/api/api_test.dart — pruebas de la API real del backend contra el
// entorno aislado (la API y su base en contenedores, con los datos de
// docker/semilla/semilla_pruebas.sql). Validan el contrato entre la app y la
// API: lo que la app manda y lo que espera de vuelta.
//
// Corren en la etapa de integración del pipeline (integracion.yml, trabajo
// «API contra entorno aislado») y, con el entorno arriba, también en local:
//
//   bash tool/entorno_pruebas.sh levantar
//   flutter test --tags api --run-skipped --dart-define=API_BASE_URL=http://localhost:3000/api
//
// Un flutter test normal las omite (dart_test.yaml): sin el entorno no hay a
// quién preguntarle.
//
// Usan test() y no testWidgets(): el binding de flutter_test intercepta HTTP y
// contesta 400 a todo, así que aquí no se inicializa.
@Tags(['api'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pier_reposteria/domain/models/product_model.dart';

import 'entorno_aislado.dart';

/// La dirección de la API. Dart la calcula la primera vez que una prueba la
/// usa: si las pruebas se omiten, nadie la pide y no hace falta.
final String _api = urlDeLaApi();

/// El cuerpo JSON de [respuesta] como mapa.
Map<String, dynamic> _cuerpo(http.Response respuesta) =>
    jsonDecode(respuesta.body) as Map<String, dynamic>;

Future<http.Response> _iniciarSesion(String clave) => http.post(
      Uri.parse('$_api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': correoDeLaSemilla, 'password': clave}),
    );

void main() {
  test('GET /health responde 200 con la base de datos conectada', () async {
    final respuesta = await http.get(Uri.parse('$_api/health'));

    expect(respuesta.statusCode, 200, reason: respuesta.body);
    expect(_cuerpo(respuesta)['success'], isTrue);
  });

  test(
      'GET /productos responde 200 y cada producto pasa por Product.fromJson '
      '(contrato de la app)', () async {
    final respuesta = await http.get(Uri.parse('$_api/productos'));

    expect(respuesta.statusCode, 200, reason: respuesta.body);
    final cuerpo = _cuerpo(respuesta);
    final productos = (cuerpo['productos'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
    // Los 4 de la semilla: 3 con existencias y 1 agotado.
    expect(cuerpo['total'], 4);
    expect(productos, hasLength(4));
    for (final producto in productos) {
      expect(producto.id, isNotEmpty);
      expect(producto.nombre, isNotEmpty);
      expect(producto.precio, greaterThan(0), reason: producto.nombre);
      expect(producto.disponible, isTrue, reason: producto.nombre);
    }
    expect(
      productos.where((producto) => producto.agotado).map((p) => p.nombre),
      ['Pay de limón'],
    );
    final chocoflan = productos.firstWhere((p) => p.nombre == 'Chocoflan');
    // El backend manda los precios como texto («350.00»): la app los lee
    // como número.
    expect(chocoflan.precio, 350);
    expect(chocoflan.stockOnline, 12);
  });

  test('GET /categorias responde 200 con las categorías de la semilla',
      () async {
    final respuesta = await http.get(Uri.parse('$_api/categorias'));

    expect(respuesta.statusCode, 200, reason: respuesta.body);
    final categorias = _cuerpo(respuesta)['categorias'] as List<dynamic>;
    expect(
      categorias.cast<Map<String, dynamic>>().map((c) => c['nombre']),
      ['Pasteles', 'Pays'],
    );
  });

  test('POST /auth/login con la cuenta de la semilla responde 200 con token',
      () async {
    final respuesta = await _iniciarSesion(claveDeLaSemilla);

    expect(respuesta.statusCode, 200, reason: respuesta.body);
    final cuerpo = _cuerpo(respuesta);
    // Un JWT: tres partes separadas por punto.
    expect(cuerpo['token'], isA<String>());
    expect((cuerpo['token'] as String).split('.'), hasLength(3));
    final usuario = cuerpo['user'] as Map<String, dynamic>;
    expect(usuario['email'], correoDeLaSemilla);
    expect(usuario['rol'], 'cliente');
  });

  test('POST /auth/login con contraseña incorrecta responde 401', () async {
    final respuesta = await _iniciarSesion('no-es-la-clave');

    expect(respuesta.statusCode, 401, reason: respuesta.body);
    expect(_cuerpo(respuesta)['success'], isFalse);
    expect(_cuerpo(respuesta).containsKey('token'), isFalse);
  });
}
