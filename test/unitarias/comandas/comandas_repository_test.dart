// test/unitarias/comandas/comandas_repository_test.dart — ComandasRepositoryRemote
// contra el backend falso (#127): consulta de la agenda por vista y
// búsqueda, errores con el mensaje del backend y sesión inválida.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

void main() {
  late FakeApiClient api;
  late ComandasRepositoryRemote repo;

  setUp(() {
    api = FakeApiClient()
      ..responder(ApiConstants.comandas, agendaJson([comandaJson()]));
    repo = ComandasRepositoryRemote(api: api);
  });

  group('agenda', () {
    test('por defecto pide los próximos días con sesión', () async {
      final agenda = await repo.agenda();

      expect(agenda.comandas.single.folio, 5001);
      expect(api.llamadas.single.metodo, 'GET-Auth');
      expect(api.llamadas.single.endpoint, '/comandas?vista=proximas');
    });

    test('manda la vista y la búsqueda codificada', () async {
      await repo.agenda(vista: VistaAgenda.entregadas, busqueda: 'Ana María');

      expect(api.llamadas.single.endpoint,
          '/comandas?vista=entregadas&busqueda=Ana+Mar%C3%ADa');
    });

    test('la búsqueda vacía no se manda', () async {
      await repo.agenda(vista: VistaAgenda.activas, busqueda: '   ');

      expect(api.llamadas.single.endpoint, '/comandas?vista=activas');
    });

    test('si el backend falla lanza ApiException con su mensaje', () async {
      api.fallar(ApiConstants.comandas, 'No tienes permiso para esta acción');

      await expectLater(
        repo.agenda(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'No tienes permiso para esta acción')),
      );
    });

    test('sin mensaje usa uno por defecto', () async {
      api.responder(ApiConstants.comandas, {'success': false});

      await expectLater(
        repo.agenda(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'No se pudieron cargar las comandas')),
      );
    });

    test('cuenta desactivada: lanza SesionInvalidaException', () async {
      api.responder(ApiConstants.comandas, {
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu cuenta está desactivada o cambió. Inicia sesión de nuevo.',
      });

      await expectLater(
          repo.agenda(), throwsA(isA<SesionInvalidaException>()));
    });
  });
}
