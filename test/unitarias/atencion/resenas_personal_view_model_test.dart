// test/unitarias/atencion/resenas_personal_view_model_test.dart — la
// pestaña «Reseñas» de Atención a clientes (#138) sin red: las pendientes
// primero, a cuáles se puede moderar o responder, aprobar sin perder la
// respuesta, el motivo y la respuesta mínimos y la recarga tras un error.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository_remote.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/ui/atencion/view_model/resenas_personal_view_model.dart';

import '../../fakes/atencion_json.dart';
import '../../fakes/fake_api_client.dart';

void main() {
  late ResenasPersonalViewModel vm;
  late FakeApiClient api;
  ResenaPersonal resena(String id) =>
      vm.resenas.firstWhere((r) => r.id == id);

  setUp(() async {
    api = backendAtencion();
    vm = ResenasPersonalViewModel(
      repo: AtencionClientesRepositoryRemote(api: api),
    );
    await vm.cargar();
  });

  group('ResenasPersonalViewModel: lista', () {
    test('las que esperan revisión primero; luego las demás', () {
      expect(vm.resenas.map((r) => r.id), ['9', '7', '8', '10']);
    });

    test('se moderan las pendientes y se responden las aprobadas sin '
        'respuesta', () {
      expect(vm.puedeModerar(resena('9')), isTrue);
      expect(vm.puedeModerar(resena('7')), isFalse);
      expect(vm.puedeResponder(resena('7')), isTrue);
      expect(vm.puedeResponder(resena('10')), isFalse);
      expect(vm.puedeResponder(resena('8')), isFalse);
      expect(vm.puedeResponder(resena('9')), isFalse);
    });

    test('motivo de 10 y respuesta de 5 caracteres como mínimo', () {
      expect(ResenasPersonalViewModel.validarMotivo(' Feo '),
          'El motivo debe tener al menos 10 caracteres.');
      expect(ResenasPersonalViewModel.validarMotivo('Lenguaje ofensivo'),
          isNull);
      expect(ResenasPersonalViewModel.validarRespuesta(' Ok '),
          'La respuesta debe tener al menos 5 caracteres.');
      expect(ResenasPersonalViewModel.validarRespuesta('Gracias'), isNull);
    });
  });

  group('ResenasPersonalViewModel: acciones', () {
    test('aprobar manda el estado', () async {
      api.responder(ApiConstants.moderarResena('9'), {'success': true});

      final r = await vm.aprobar(resena('9'));

      expect(r, (mensaje: 'Reseña aprobada', ok: true));
      expect(api.ultima(ApiConstants.moderarResena('9'))!.body,
          {'estado': 'aprobada'});
    });

    test('aprobar reenvía la respuesta que ya tenía', () async {
      api
        ..responder(ApiConstants.resenasPersonal, {
          'success': true,
          'resenas': [resenaJson(id: 11, respuesta: 'Gracias &amp; vuelve')],
        })
        ..responder(ApiConstants.moderarResena('11'), {'success': true});
      await vm.refrescar();

      await vm.aprobar(resena('11'));

      expect(api.ultima(ApiConstants.moderarResena('11'))!.body,
          {'estado': 'aprobada', 'respuesta_negocio': 'Gracias & vuelve'});
    });

    test('rechazar manda el motivo; uno corto no se manda', () async {
      api.responder(ApiConstants.moderarResena('9'), {'success': true});

      final corto = await vm.rechazar(resena('9'), 'Feo');
      expect(corto.ok, isFalse);
      expect(api.llamo(ApiConstants.moderarResena('9')), isFalse);

      final r = await vm.rechazar(resena('9'), ' Lenguaje ofensivo ');
      expect(r, (mensaje: 'Reseña rechazada', ok: true));
      expect(api.ultima(ApiConstants.moderarResena('9'))!.body,
          {'estado': 'rechazada', 'motivo_rechazo': 'Lenguaje ofensivo'});
    });

    test('responder solo publica la respuesta; una corta no se manda',
        () async {
      api.responder(ApiConstants.moderarResena('7'), {'success': true});

      final corta = await vm.responder(resena('7'), 'Ok');
      expect(corta,
          (mensaje: 'La respuesta debe tener al menos 5 caracteres.', ok: false));
      expect(api.llamo(ApiConstants.moderarResena('7')), isFalse);

      final r = await vm.responder(resena('7'), ' ¡Gracias por venir! ');
      expect(r, (mensaje: 'Respuesta publicada', ok: true));
      expect(api.ultima(ApiConstants.moderarResena('7'))!.body,
          {'respuesta_negocio': '¡Gracias por venir!'});
    });

    test('si el backend la rechaza devuelve su motivo y recarga', () async {
      api.fallar(ApiConstants.moderarResena('9'), 'Reseña no encontrada');
      final antes = cargasDe(api, ApiConstants.resenasPersonal);

      final r = await vm.aprobar(resena('9'));

      expect(r, (mensaje: 'Reseña no encontrada', ok: false));
      expect(cargasDe(api, ApiConstants.resenasPersonal), antes + 1);
    });
  });
}
