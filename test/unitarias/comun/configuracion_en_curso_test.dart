// test/unitarias/comun/configuracion_en_curso_test.dart —
// ConfiguracionRepositoryRemote comparte la petición de una sección que ya va
// en camino (#341): al abrir la app, el Inicio pide «contacto» y
// «personalizacion» en el mismo cuadro que «Más» y el tema, y antes cada uno
// mandaba la suya.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

final String _contacto = ApiConstants.configuracionSeccion('contacto');
final String _personalizacion =
    ApiConstants.configuracionSeccion('personalizacion');

FakeApiClient _backend() => FakeApiClient(respuestas: {
      _contacto: {
        'success': true,
        'config': {'telefono': '7711234567'},
      },
      _personalizacion: {
        'success': true,
        'config': {'modo_auto': true},
      },
    });

int _pedidas(FakeApiClient api, String endpoint) =>
    api.llamadas.where((llamada) => llamada.endpoint == endpoint).length;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ConfiguracionRepositoryRemote.seccion', () {
    test('dos pantallas que piden la misma sección a la vez comparten la '
        'petición (#341)', () async {
      final api = _backend();
      final repo = ConfiguracionRepositoryRemote(api: api);

      final respuestas = await Future.wait([
        repo.seccion('contacto'),
        repo.configDe('contacto'),
      ]);

      expect(_pedidas(api, _contacto), 1);
      expect(respuestas[0]['config'], {'telefono': '7711234567'});
      expect(respuestas[1], {'telefono': '7711234567'});
    }, tags: 'regresion');

    test('cada sección va en su propia petición', () async {
      final api = _backend();
      final repo = ConfiguracionRepositoryRemote(api: api);

      final respuestas = await Future.wait([
        repo.seccion('contacto'),
        repo.seccion('personalizacion'),
      ]);

      expect(_pedidas(api, _contacto), 1);
      expect(_pedidas(api, _personalizacion), 1);
      expect(respuestas[0]['config'], {'telefono': '7711234567'});
      expect(respuestas[1]['config'], {'modo_auto': true});
    });

    // El tema vuelve a preguntar cada minuto: no debe quedarse con la
    // respuesta de la primera vez.
    test('cuando la petición ya terminó, la siguiente pregunta de nuevo',
        () async {
      final api = _backend();
      final repo = ConfiguracionRepositoryRemote(api: api);
      await repo.seccion('personalizacion');

      api.responder(_personalizacion, {
        'success': true,
        'config': {'modo_auto': false},
      });
      final segunda = await repo.seccion('personalizacion');

      expect(_pedidas(api, _personalizacion), 2);
      expect(segunda['config'], {'modo_auto': false});
    });

    test('si la petición revienta, la siguiente lo vuelve a intentar',
        () async {
      // Una respuesta que el falso no sabe entregar: su llamada lanza.
      final api = FakeApiClient(respuestas: {_contacto: 42});
      final repo = ConfiguracionRepositoryRemote(api: api);

      await expectLater(repo.seccion('contacto'), throwsStateError);

      api.responder(_contacto, {
        'success': true,
        'config': {'telefono': '7711234567'},
      });
      final respuesta = await repo.seccion('contacto');

      expect(_pedidas(api, _contacto), 2);
      expect(respuesta['config'], {'telefono': '7711234567'});
    });
  });
}
