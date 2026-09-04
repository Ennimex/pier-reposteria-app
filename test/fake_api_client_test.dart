// test/fake_api_client_test.dart — el falso se prueba a sí mismo, para que
// los tests de repositorios y ViewModels (Fases 2-6) puedan confiar en él.
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_client.dart';

void main() {
  group('FakeApiClient', () {
    test('devuelve la respuesta configurada y registra la llamada', () async {
      final api = FakeApiClient(respuestas: {
        '/resenas/mis-resenas': {
          'success': true,
          'resenas': [
            {'id': 1, 'comentario': 'hola mundo', 'rating': 5},
          ],
        },
      });

      final r = await api.getAuth('/resenas/mis-resenas');

      expect(r['success'], true);
      expect((r['resenas'] as List).first['comentario'], 'hola mundo');
      expect(api.llamadas.length, 1);
      expect(api.llamo('/resenas/mis-resenas', metodo: 'GET-Auth'), true);
      expect(api.llamo('/resenas/mis-resenas', metodo: 'POST'), false);
    });

    test('endpoint sin configurar responde success:false, nunca lanza',
        () async {
      final api = FakeApiClient();
      final r = await api.get('/lo-que-sea');
      expect(r['success'], false);
      expect(r['message'], contains('/lo-que-sea'));
    });

    test('fallar() simula un rechazo del backend', () async {
      final api = FakeApiClient()..fallar('/carrito', 'Token expirado');
      final r = await api.getAuth('/carrito');
      expect(r, {'success': false, 'message': 'Token expirado'});
    });

    test('sin coincidencia exacta, ignora el query string', () async {
      final api = FakeApiClient(respuestas: {
        '/zonas-envio/cotizar': {'success': true, 'tarifa': 35},
      });
      final r = await api.get('/zonas-envio/cotizar?colonia=Tahuiz%C3%A1n');
      expect(r['tarifa'], 35);
    });

    test('respuesta dinámica recibe la llamada y su body', () async {
      final api = FakeApiClient(respuestas: {
        '/carrito': (LlamadaApi l) =>
            {'success': true, 'eco': l.body?['cantidad']},
      });
      final r = await api.postAuth('/carrito', {'producto_id': 15, 'cantidad': 2});
      expect(r['eco'], 2);
      expect(api.ultima('/carrito')?.body?['producto_id'], 15);
      expect(api.ultima('/nada'), isNull);
    });

    test('cada respuesta es una copia: mutarla no contamina la siguiente',
        () async {
      final api = FakeApiClient(respuestas: {
        '/x': {'success': true, 'n': 1},
      });
      final a = await api.get('/x');
      a['n'] = 99;
      final b = await api.get('/x');
      expect(b['n'], 1);
    });
  });
}
