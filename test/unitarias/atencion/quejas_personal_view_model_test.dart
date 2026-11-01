// test/unitarias/atencion/quejas_personal_view_model_test.dart — la pestaña
// «Quejas» de Atención a clientes (#138) sin red: los pendientes primero,
// el error de carga, marcar en proceso sin perder la respuesta, responder
// sin cerrar o resolviendo, la respuesta mínima y la recarga después de
// cada acción (también si el backend la rechaza).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository_remote.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/ui/atencion/view_model/quejas_personal_view_model.dart';

import '../../fakes/atencion_json.dart';
import '../../fakes/fake_api_client.dart';

(QuejasPersonalViewModel, FakeApiClient) _armar() {
  final api = backendAtencion();
  return (
    QuejasPersonalViewModel(repo: AtencionClientesRepositoryRemote(api: api)),
    api,
  );
}

void main() {
  group('QuejasPersonalViewModel: lista', () {
    test('pendientes, luego en proceso y al final las resueltas', () async {
      final (vm, _) = _armar();
      expect(vm.cargando, isFalse);

      final carga = vm.cargar();
      expect(vm.cargando, isTrue);
      await carga;

      expect(vm.cargando, isFalse);
      expect(vm.error, isNull);
      expect(vm.quejas.map((q) => q.id), ['1', '2', '3']);
      expect(vm.elementos.map((q) => q.id), ['3', '1', '2']);
    });

    test('si no carga expone el motivo y al reintentar se recupera',
        () async {
      final (vm, api) = _armar();
      api.fallar(ApiConstants.quejasPersonal, 'Sin conexión');
      await vm.cargar();
      expect(vm.error, 'Sin conexión');
      expect(vm.quejas, isEmpty);

      api.responder(ApiConstants.quejasPersonal, quejasJson);
      await vm.cargar();
      expect(vm.error, isNull);
      expect(vm.quejas, hasLength(3));
    });

    test('al refrescar sin respuesta conserva la lista y da el motivo',
        () async {
      final (vm, api) = _armar();
      await vm.cargar();
      api.fallar(ApiConstants.quejasPersonal, 'Sin conexión');

      expect(await vm.refrescar(), 'Sin conexión');
      expect(vm.quejas, hasLength(3));
      expect(vm.error, isNull);
    });

    test('si la pantalla se cierra a media carga no avisa a nadie', () async {
      final (vm, api) = _armar();
      api.demorar(ApiConstants.quejasPersonal, const Duration(milliseconds: 5));
      final carga = vm.cargar();
      vm.dispose();
      await carga;
      expect(vm.elementos, isEmpty);
    });
  });

  group('QuejasPersonalViewModel: acciones', () {
    late QuejasPersonalViewModel vm;
    late FakeApiClient api;
    QuejaPersonal queja(String id) => vm.quejas.firstWhere((q) => q.id == id);

    setUp(() async {
      (vm, api) = _armar();
      await vm.cargar();
    });

    test('marcar en proceso sin respuesta solo manda el estado', () async {
      api.responder(ApiConstants.atenderQueja('1'), {'success': true});
      final antes = cargasDe(api, ApiConstants.quejasPersonal);

      final r = await vm.marcarEnProceso(queja('1'));

      expect(r, (mensaje: 'TKT-001 quedó en proceso', ok: true));
      expect(api.ultima(ApiConstants.atenderQueja('1'))!.body,
          {'estado': 'en_proceso'});
      expect(cargasDe(api, ApiConstants.quejasPersonal), antes + 1);
    });

    test('marcar en proceso reenvía la respuesta que ya tenía', () async {
      api
        ..responder(ApiConstants.quejasPersonal, {
          'success': true,
          'quejas': [quejaJson(id: 5, respuesta: 'Ya lo &amp; vimos')],
        })
        ..responder(ApiConstants.atenderQueja('5'), {'success': true});
      await vm.refrescar();

      await vm.marcarEnProceso(queja('5'));

      // Como se escribió: el backend la vuelve a escapar al guardarla.
      expect(api.ultima(ApiConstants.atenderQueja('5'))!.body,
          {'estado': 'en_proceso', 'respuesta': 'Ya lo & vimos'});
    });

    test('responder y resolver, o responder sin cerrar', () async {
      api.responder(ApiConstants.atenderQueja('1'), {'success': true});

      final resuelta = await vm.responder(
        queja('1'),
        '  Te llamamos hoy para reponerlo  ',
        resolver: true,
      );
      expect(resuelta.mensaje, 'Respuesta enviada: TKT-001 quedó resuelto');
      expect(api.ultima(ApiConstants.atenderQueja('1'))!.body, {
        'estado': 'resuelto',
        'respuesta': 'Te llamamos hoy para reponerlo',
      });

      final abierta = await vm.responder(
        queja('1'),
        'Seguimos revisando tu caso',
        resolver: false,
      );
      expect(abierta,
          (mensaje: 'Respuesta enviada: TKT-001 sigue en proceso', ok: true));
      expect(api.ultima(ApiConstants.atenderQueja('1'))!.body, {
        'estado': 'en_proceso',
        'respuesta': 'Seguimos revisando tu caso',
      });
    });

    test('la respuesta lleva al menos 10 caracteres', () async {
      expect(QuejasPersonalViewModel.validarRespuesta('  Perdón   '),
          'La respuesta debe tener al menos 10 caracteres.');
      expect(QuejasPersonalViewModel.validarRespuesta('Te llamamos hoy'),
          isNull);

      final r = await vm.responder(queja('1'), 'Perdón', resolver: true);
      expect(r, (
        mensaje: 'La respuesta debe tener al menos 10 caracteres.',
        ok: false,
      ));
      expect(api.llamo(ApiConstants.atenderQueja('1')), isFalse);
    });

    test('si el backend lo rechaza devuelve su motivo y recarga', () async {
      api.fallar(ApiConstants.atenderQueja('2'), 'Queja no encontrada');
      final antes = cargasDe(api, ApiConstants.quejasPersonal);

      final r = await vm.responder(
        queja('2'),
        'Ya quedó lo que pediste',
        resolver: true,
      );

      expect(r, (mensaje: 'Queja no encontrada', ok: false));
      expect(cargasDe(api, ApiConstants.quejasPersonal), antes + 1);
      expect(vm.ocupado(queja('2')), isFalse);
    });

    test('no corre dos acciones a la vez sobre la misma queja', () async {
      api
        ..responder(ApiConstants.atenderQueja('1'), {'success': true})
        ..demorar(ApiConstants.atenderQueja('1'),
            const Duration(milliseconds: 5));
      final primera = vm.marcarEnProceso(queja('1'));
      expect(vm.ocupado(queja('1')), isTrue);

      final segunda = await vm.marcarEnProceso(queja('1'));
      expect(segunda,
          (mensaje: 'Espera a que termine la acción anterior', ok: false));
      await primera;
      expect(
        api.llamadas.where((l) => l.endpoint == ApiConstants.atenderQueja('1')),
        hasLength(1),
      );
    });

    test('si se cierra a media acción no recarga', () async {
      api
        ..responder(ApiConstants.atenderQueja('1'), {'success': true})
        ..demorar(ApiConstants.atenderQueja('1'),
            const Duration(milliseconds: 5));
      final antes = cargasDe(api, ApiConstants.quejasPersonal);
      final accion = vm.marcarEnProceso(queja('1'));
      vm.dispose();

      expect((await accion).ok, isTrue);
      expect(cargasDe(api, ApiConstants.quejasPersonal), antes);
    });
  });
}
