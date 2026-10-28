// test/unitarias/comun/cliente_seguro_test.dart — #219: certificate pinning
// del API. Un servidor HTTPS local con un certificado de prueba
// (test/fakes/certificados/) hace de «certificado distinto»: el cliente con
// los certificados del API fijados lo rechaza, y el mismo mecanismo acepta la
// conexión cuando se fija la autoridad que lo firmó.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/data/services/certificados_api.dart';
import 'package:pier_reposteria/data/services/cliente_seguro.dart';

const _carpeta = 'test/fakes/certificados';

/// Servidor HTTPS en localhost con el certificado de prueba.
Future<HttpServer> _servidorDePrueba() async {
  final contexto = SecurityContext()
    ..useCertificateChain('$_carpeta/servidor.pem')
    ..usePrivateKey('$_carpeta/servidor.key');
  final servidor =
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, contexto);
  servidor.listen((peticion) async {
    peticion.response
      ..statusCode = 200
      ..write('{"success": true}');
    await peticion.response.close();
  });
  return servidor;
}

bool _certificadoRechazado(Object error) =>
    error.toString().contains('CERTIFICATE_VERIFY_FAILED');

void main() {
  group('Certificados fijados (#219)', () {
    test('son GTS WE1 y GTS Root R4, con sus huellas SHA-256', () {
      expect(
        CertificadosApi.fijados.map((c) => c.nombre),
        ['GTS WE1', 'GTS Root R4'],
      );
      for (final certificado in CertificadosApi.fijados) {
        expect(
          huellaSha256(certificado.pem),
          certificado.huellaSha256,
          reason: certificado.nombre,
        );
      }
    });

    test('la huella coincide con la de openssl', () {
      final pem = File('$_carpeta/autoridad.pem').readAsStringSync();

      expect(
        huellaSha256(pem),
        'D7:A1:2A:85:86:D8:4D:CA:03:84:C1:A6:7E:F2:FC:95:'
        '2B:51:FE:AE:A9:0C:79:A4:81:C8:F5:9F:8F:68:32:B4',
      );
    });

    test('se fija solo el API de producción por https', () {
      expect(debeFijarCertificado(ApiConstants.prodUrl), isTrue);
      expect(debeFijarCertificado(ApiConstants.devUrl), isFalse);
      expect(debeFijarCertificado('http://localhost:3000/api'), isFalse);
      expect(
        debeFijarCertificado('http://${CertificadosApi.hostFijado}/api'),
        isFalse,
      );
      expect(debeFijarCertificado('https://otro.onrender.com/api'), isFalse);
      expect(debeFijarCertificado('no es una url'), isFalse);
    });
  });

  group('Cliente con el certificado fijado (#219)', () {
    late HttpServer servidor;

    setUp(() async => servidor = await _servidorDePrueba());
    tearDown(() => servidor.close(force: true));

    Uri url() => Uri.parse('https://localhost:${servidor.port}/api/productos');

    test('rechaza un servidor con un certificado distinto a los fijados',
        () async {
      final cliente = clienteConCertificadoFijo();
      addTearDown(cliente.close);

      await expectLater(
        cliente.get(url()),
        throwsA(predicate(_certificadoRechazado)),
      );
    });

    test('acepta el servidor cuando se fija la autoridad que lo firmó',
        () async {
      final cliente = clienteConCertificadoFijo(
        certificados: [File('$_carpeta/autoridad.pem').readAsStringSync()],
      );
      addTearDown(cliente.close);

      final respuesta = await cliente.get(url());

      expect(respuesta.statusCode, 200);
      expect(respuesta.body, '{"success": true}');
    });
  });

  group('ApiService con un cliente fijo (#219)', () {
    tearDown(() => ApiService().cliente = null);

    test('usa el cliente fijo en las peticiones', () async {
      final urls = <Uri>[];
      ApiService().cliente = MockClient((peticion) async {
        urls.add(peticion.url);
        return http.Response('{"success": true}', 200);
      });

      final respuesta = await ApiService().get('/productos');

      expect(respuesta['success'], isTrue);
      expect(urls.single.toString(), '${ApiConstants.baseUrl}/productos');
    });

    test('si el certificado no coincide, el cliente ve «sin conexión»',
        () async {
      ApiService().cliente = MockClient((_) async =>
          throw const HandshakeException('CERTIFICATE_VERIFY_FAILED'));

      final respuesta = await ApiService().get('/productos');

      expect(respuesta['success'], isFalse);
      expect(respuesta['message'], ApiService.mensajeSinConexion);
    });
  });
}
