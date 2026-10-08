// test/unit/ambiente_test.dart — URL del backend según el ambiente (#13).
// El ambiente llega por --dart-define=AMBIENTE=dev|staging|prod y la URL se
// puede forzar con --dart-define=API_BASE_URL=...
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';

void main() {
  group('ApiConstants.ambienteDesde', () {
    test('reconoce los tres ambientes sin importar mayúsculas', () {
      expect(ApiConstants.ambienteDesde('dev'), Ambiente.dev);
      expect(ApiConstants.ambienteDesde('STAGING'), Ambiente.staging);
      expect(ApiConstants.ambienteDesde('prod'), Ambiente.prod);
    });

    test('un valor vacío o desconocido es prod', () {
      expect(ApiConstants.ambienteDesde(''), Ambiente.prod);
      expect(ApiConstants.ambienteDesde('qa'), Ambiente.prod);
    });
  });

  group('ApiConstants.resolverBaseUrl', () {
    test('prod usa el backend de Render', () {
      expect(ApiConstants.resolverBaseUrl(Ambiente.prod),
          'https://pier-reposteria-backend.onrender.com/api');
    });

    test('dev usa el backend local visto desde el emulador', () {
      expect(ApiConstants.resolverBaseUrl(Ambiente.dev),
          'http://10.0.2.2:3000/api');
    });

    test('staging usa prod mientras no exista un backend de staging', () {
      expect(ApiConstants.resolverBaseUrl(Ambiente.staging),
          ApiConstants.prodUrl);
    });

    test('una URL forzada gana sobre el ambiente', () {
      expect(
        ApiConstants.resolverBaseUrl(Ambiente.dev,
            urlForzada: 'http://192.168.1.50:3000/api'),
        'http://192.168.1.50:3000/api',
      );
    });
  });

  group('ApiConstants sin --dart-define', () {
    test('el build normal sigue apuntando a producción', () {
      expect(ApiConstants.ambiente, Ambiente.prod);
      expect(ApiConstants.baseUrl, ApiConstants.prodUrl);
    });

    test('ninguna URL lleva credenciales', () {
      for (final url in [ApiConstants.prodUrl, ApiConstants.devUrl]) {
        expect(Uri.parse(url).userInfo, isEmpty, reason: url);
      }
    });
  });
}
