// test/unitarias/atencion/reembolsos_personal_view_model_test.dart — la
// pestaña «Reembolsos» de Atención a clientes (#138) sin red: el orden, los
// pasos que ofrece cada estado según el rol (el mostrador solo pasa a
// revisión), el texto con que abre cada confirmación, la justificación
// mínima del rechazo y lo que cada paso manda al backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository_remote.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/ui/atencion/view_model/reembolsos_personal_view_model.dart';

import '../../fakes/atencion_json.dart';
import '../../fakes/fake_api_client.dart';

(ReembolsosPersonalViewModel, FakeApiClient) _armar(String rol) {
  final api = backendAtencion();
  return (
    ReembolsosPersonalViewModel(
      repo: AtencionClientesRepositoryRemote(api: api),
      rol: rol,
    ),
    api,
  );
}

void main() {
  group('ReembolsosPersonalViewModel: lista y reglas', () {
    test('las que esperan una decisión primero', () async {
      final (vm, _) = _armar('empleado');
      await vm.cargar();

      expect(vm.reembolsos.map((r) => r.id), ['1', '6', '2', '3', '5', '4']);
    });

    test('deciden gerencia y dirección; el mostrador no', () {
      ReembolsosPersonalViewModel con(String? rol) =>
          ReembolsosPersonalViewModel(
            repo: AtencionClientesRepositoryRemote(api: FakeApiClient()),
            rol: rol,
          );
      expect(con('gerencia').decide, isTrue);
      expect(con('direccion_general').decide, isTrue);
      expect(con('empleado').decide, isFalse);
      expect(con(null).decide, isFalse);
    });

    test('el mostrador solo pasa a revisión las pendientes', () async {
      final (vm, _) = _armar('empleado');
      await vm.cargar();
      List<PasoReembolso> pasos(String id) =>
          vm.pasos(vm.reembolsos.firstWhere((r) => r.id == id));
      bool espera(String id) =>
          vm.esperaDecision(vm.reembolsos.firstWhere((r) => r.id == id));

      expect(pasos('1'), [PasoReembolso.revision]);
      expect(pasos('2'), isEmpty);
      expect(pasos('3'), isEmpty);
      expect(espera('2'), isTrue);
      expect(espera('1'), isFalse);
    });

    test('gerencia: revisar, rechazar o aprobar; devolver lo aprobado',
        () async {
      final (vm, _) = _armar('gerencia');
      await vm.cargar();
      List<PasoReembolso> pasos(String id) =>
          vm.pasos(vm.reembolsos.firstWhere((r) => r.id == id));

      expect(pasos('1'), [
        PasoReembolso.revision,
        PasoReembolso.rechazar,
        PasoReembolso.aprobar,
      ]);
      expect(pasos('2'), [PasoReembolso.rechazar, PasoReembolso.aprobar]);
      expect(pasos('3'), [PasoReembolso.devolver]);
      expect(pasos('4'), isEmpty);
      expect(pasos('5'), isEmpty);
      expect(
        vm.esperaDecision(vm.reembolsos.firstWhere((r) => r.id == '2')),
        isFalse,
      );
    });

    test('el texto con que abre cada confirmación', () async {
      final (vm, _) = _armar('gerencia');
      await vm.cargar();
      ReembolsoPersonal de(String id) =>
          vm.reembolsos.firstWhere((r) => r.id == id);

      expect(vm.notaInicial(PasoReembolso.revision, de('1')),
          ReembolsosPersonalViewModel.mensajeRevision);
      expect(vm.notaInicial(PasoReembolso.rechazar, de('2')), '');
      // El aviso de revisión ya no aplica al aprobar.
      expect(vm.notaInicial(PasoReembolso.aprobar, de('2')), '');
      expect(vm.notaInicial(PasoReembolso.aprobar, de('1')), '');
      expect(vm.notaInicial(PasoReembolso.devolver, de('3')),
          'Te lo devolvemos & avisamos');
      expect(vm.notaInicial(PasoReembolso.aprobar, de('3')),
          'Te lo devolvemos & avisamos');
    });

    test('rechazar exige 20 caracteres de justificación', () {
      expect(
        ReembolsosPersonalViewModel.validarNota(
            PasoReembolso.rechazar, '  No procede  '),
        'La justificación debe tener al menos 20 caracteres.',
      );
      expect(
        ReembolsosPersonalViewModel.validarNota(
            PasoReembolso.rechazar, 'La foto no muestra ningún daño'),
        isNull,
      );
      expect(
        ReembolsosPersonalViewModel.validarNota(PasoReembolso.aprobar, ''),
        isNull,
      );
    });
  });

  group('ReembolsosPersonalViewModel: pasos', () {
    late ReembolsosPersonalViewModel vm;
    late FakeApiClient api;
    ReembolsoPersonal de(String id) =>
        vm.reembolsos.firstWhere((r) => r.id == id);
    Map<String, dynamic>? cuerpo(String id) =>
        api.ultima(ApiConstants.resolverReembolso(id))!.body;

    setUp(() async {
      (vm, api) = _armar('gerencia');
      await vm.cargar();
      for (final id in ['1', '2', '3']) {
        api.responder(ApiConstants.resolverReembolso(id), {'success': true});
      }
    });

    test('pasar a revisión con el mensaje para el cliente', () async {
      final r = await vm.dar(PasoReembolso.revision, de('1'),
          ReembolsosPersonalViewModel.mensajeRevision);

      expect(r, (
        mensaje: 'La solicitud del pedido PIER-41 pasó a revisión',
        ok: true,
      ));
      expect(cuerpo('1'), {
        'estado': 'en_revision',
        'respuesta_admin': 'Recibimos tu solicitud; gerencia la revisará hoy.',
      });

      await vm.dar(PasoReembolso.revision, de('1'), '   ');
      expect(cuerpo('1'), {'estado': 'en_revision'});
    });

    test('aprobar sin mensaje dice «Reembolso aprobado»', () async {
      final r = await vm.dar(PasoReembolso.aprobar, de('2'), '');

      expect(r.mensaje, 'Reembolso del pedido PIER-42 aprobado');
      expect(cuerpo('2'),
          {'estado': 'aprobado', 'respuesta_admin': 'Reembolso aprobado'});

      await vm.dar(PasoReembolso.aprobar, de('2'), ' Ya va tu dinero ');
      expect(cuerpo('2'),
          {'estado': 'aprobado', 'respuesta_admin': 'Ya va tu dinero'});
    });

    test('rechazar manda la justificación', () async {
      final r = await vm.dar(PasoReembolso.rechazar, de('2'),
          ' La foto no muestra ningún daño ');

      expect(r.mensaje, 'Reembolso del pedido PIER-42 rechazado');
      expect(cuerpo('2'), {
        'estado': 'rechazado',
        'justificacion_rechazo': 'La foto no muestra ningún daño',
      });
    });

    test('una justificación corta no se manda', () async {
      final r = await vm.dar(PasoReembolso.rechazar, de('2'), 'No');

      expect(r, (
        mensaje: 'La justificación debe tener al menos 20 caracteres.',
        ok: false,
      ));
      expect(api.llamo(ApiConstants.resolverReembolso('2')), isFalse);
    });

    test('marcar como devuelto conserva o cambia el mensaje', () async {
      final r = await vm.dar(PasoReembolso.devolver, de('3'), '');

      expect(r.mensaje, 'Reembolso del pedido PIER-43 marcado como devuelto');
      expect(cuerpo('3'), {'estado': 'procesado'});

      await vm.dar(PasoReembolso.devolver, de('3'), 'Referencia re_123');
      expect(cuerpo('3'),
          {'estado': 'procesado', 'respuesta_admin': 'Referencia re_123'});
    });

    test('si otra persona ya la cambió devuelve el motivo y recarga',
        () async {
      api.fallar(ApiConstants.resolverReembolso('1'),
          'No se puede pasar de "aprobado" a "aprobado"');
      final antes = cargasDe(api, ApiConstants.reembolsosPersonal);

      final r = await vm.dar(PasoReembolso.aprobar, de('1'), '');

      expect(r, (
        mensaje: 'No se puede pasar de "aprobado" a "aprobado"',
        ok: false,
      ));
      expect(cargasDe(api, ApiConstants.reembolsosPersonal), antes + 1);
    });
  });
}
