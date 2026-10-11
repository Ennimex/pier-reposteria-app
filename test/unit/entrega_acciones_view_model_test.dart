// test/unit/entrega_acciones_view_model_test.dart — ViewModels que actúan
// sobre una entrega (MVVM, Fase 5) sin red: el detalle (salir en camino,
// avisar llegada, enlaces de contacto), la confirmación con evidencia y el
// reporte de fallo. Al cambiar la entrega avisan al panel.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/confirmar_entrega_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/entrega_detail_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/reportar_fallo_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _estado = ApiConstants.entregaEstado('9');
final String _llegue = ApiConstants.entregaLlegue('9');

EntregaRepartidor _entrega({
  String estado = 'asignada',
  Object? direccion,
  String? telefono,
}) =>
    EntregaRepartidor.fromJson({
      'id': 9,
      'estado': estado,
      'numero': 'PIER-0041',
      'cliente_telefono': telefono,
      'direccion_entrega': direccion,
    });

void main() {
  late FakeApiClient api;
  late EntregasRepositoryRemote repo;
  late int avisos;

  Future<void> alCambiar() async => avisos++;

  setUp(() {
    api = FakeApiClient();
    repo = EntregasRepositoryRemote(api: api);
    avisos = 0;
  });

  group('EntregaDetailViewModel', () {
    EntregaDetailViewModel armar([EntregaRepartidor? entrega]) =>
        EntregaDetailViewModel(
          repo: repo,
          entrega: entrega ?? _entrega(),
          alCambiar: alCambiar,
        );

    test('salir en camino cambia el estado y avisa al panel', () async {
      api.responder(_estado, {'success': true});
      final vm = armar();
      final saliendo = <bool>[];
      vm.addListener(() => saliendo.add(vm.saliendo));
      expect(vm.puedeAccionar, isTrue);

      final r = await vm.salirEnCamino();

      expect(r, (ok: true, mensaje: EntregaDetailViewModel.mensajeEnCamino));
      expect(saliendo, [true, false]);
      expect(vm.estado, EstadoEntrega.enCamino);
      expect(vm.puedeAccionar, isTrue);
      expect(api.ultima(_estado)!.body, {'estado': 'en_camino'});
      expect(avisos, 1);
    });

    test('si el backend lo rechaza se queda asignada y no avisa', () async {
      api.fallar(_estado, 'No se puede pasar de "entregada" a "en_camino"');
      final vm = armar();

      final r = await vm.salirEnCamino();

      expect(r.ok, isFalse);
      expect(r.mensaje, 'No se puede pasar de "entregada" a "en_camino"');
      expect(vm.estado, EstadoEntrega.asignada);
      expect(vm.saliendo, isFalse);
      expect(avisos, 0);
    });

    test('avisar llegada devuelve el mensaje sin cambiar el estado', () async {
      api.responder(
          _llegue, {'success': true, 'message': 'Cliente avisado de tu llegada'});
      final vm = armar(_entrega(estado: 'en_camino'));

      final r = await vm.avisarLlegada();

      expect(r, (ok: true, mensaje: 'Cliente avisado de tu llegada'));
      expect(vm.avisandoLlegada, isFalse);
      expect(vm.estado, EstadoEntrega.enCamino);
      expect(avisos, 0);

      api.fallar(_llegue, 'Solo puedes avisar llegada cuando vas en camino');
      expect((await vm.avisarLlegada()).ok, isFalse);
    });

    test('una entrega finalizada no tiene acciones', () {
      expect(armar(_entrega(estado: 'entregada')).puedeAccionar, isFalse);
      expect(armar(_entrega(estado: 'fallida')).puedeAccionar, isFalse);
    });

    test('enlaces con el teléfono de la dirección y coordenadas', () {
      final vm = armar(_entrega(
        direccion: {
          'telefono_contacto': '771 123 4567',
          'lat': 21.14,
          'lng': -98.42,
        },
        telefono: '5550000000',
      ));

      expect(vm.telefono, '771 123 4567');
      expect(vm.uriLlamada.toString(), 'tel:7711234567');
      expect(vm.uriWhatsapp.toString(), 'https://wa.me/527711234567');
      expect(
        vm.uriComoLlegar.toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&destination=21.14%2C-98.42&travelmode=driving',
      );
    });

    test('sin teléfono en la dirección usa el del cliente; con lada la deja',
        () {
      final vm = armar(_entrega(telefono: '+52 771 123 4567'));
      expect(vm.uriWhatsapp.toString(), 'https://wa.me/527711234567');
    });

    test('sin ningún teléfono no hay enlaces de contacto', () {
      final vm = armar(_entrega(direccion: {'colonia': 'Centro'}));
      expect(vm.telefono, isNull);
      expect(vm.uriLlamada, isNull);
      expect(vm.uriWhatsapp, isNull);
      expect(vm.uriComoLlegar.queryParameters['destination'],
          'Centro, Huejutla de Reyes');
    });

    test('no avisa a la vista si se cerró a media llamada', () async {
      api
        ..responder(_estado, {'success': true})
        ..demorar(_estado, const Duration(milliseconds: 5));
      final vm = armar();
      final accion = vm.salirEnCamino();
      vm.dispose();
      expect((await accion).ok, isTrue);
    });
  });

  group('ConfirmarEntregaViewModel', () {
    ConfirmarEntregaViewModel armar() => ConfirmarEntregaViewModel(
          repo: repo,
          entrega: _entrega(estado: 'en_camino'),
          alCambiar: alCambiar,
        );

    test('pide quién recibió antes de llamar al backend', () async {
      final vm = armar();

      final r = await vm.confirmar('   ');

      expect(r,
          (ok: false, mensaje: ConfirmarEntregaViewModel.faltaQuienRecibio));
      expect(api.llamadas, isEmpty);
    });

    test('elige y quita la evidencia', () {
      final vm = armar()..elegirEvidencia('/tmp/f.jpg');
      expect(vm.evidencia, '/tmp/f.jpg');
      vm.quitarEvidencia();
      expect(vm.evidencia, isNull);
    });

    test('sube la foto y confirma con su URL', () async {
      api
        ..responder(ApiConstants.uploadImagen, {
          'success': true,
          'imagen': {'url': 'https://cdn/f.jpg'},
        })
        ..responder(_estado, {'success': true});
      final vm = armar()..elegirEvidencia('/tmp/f.jpg');
      final enviando = <bool>[];
      vm.addListener(() => enviando.add(vm.enviando));

      final r = await vm.confirmar(' María ');

      expect(r, (ok: true, mensaje: ConfirmarEntregaViewModel.mensajeConfirmada));
      expect(enviando, [true, false]);
      expect(vm.fotoSinSubir, isFalse);
      expect(api.ultima(_estado)!.body, {
        'estado': 'entregada',
        'evidencia_url': 'https://cdn/f.jpg',
        'recibio_nombre': 'María',
      });
      expect(avisos, 1);
    });

    test('si la foto no sube confirma sin evidencia y lo marca', () async {
      api
        ..fallar(ApiConstants.uploadImagen, 'Error al subir imagen')
        ..responder(_estado, {'success': true});
      final vm = armar()..elegirEvidencia('/tmp/f.jpg');

      final r = await vm.confirmar('María');

      expect(r.ok, isTrue);
      expect(vm.fotoSinSubir, isTrue);
      expect(api.ultima(_estado)!.body,
          {'estado': 'entregada', 'recibio_nombre': 'María'});
    });

    test('sin foto no sube nada; si el backend rechaza no avisa', () async {
      api.fallar(_estado, 'Entrega no encontrada');
      final vm = armar();

      final r = await vm.confirmar('María');

      expect(r, (ok: false, mensaje: 'Entrega no encontrada'));
      expect(api.llamo(ApiConstants.uploadImagen), isFalse);
      expect(vm.enviando, isFalse);
      expect(avisos, 0);
    });
  });

  group('ReportarFalloViewModel', () {
    ReportarFalloViewModel armar() => ReportarFalloViewModel(
          repo: repo,
          entrega: _entrega(),
          alCambiar: alCambiar,
        );

    test('pide el detalle antes de llamar al backend', () async {
      final r = await armar().reportar('  ');
      expect(r, (ok: false, mensaje: ReportarFalloViewModel.faltaDetalle));
      expect(api.llamadas, isEmpty);
    });

    test('el motivo combina la categoría (salvo «Otro») con el detalle', () {
      final vm = armar();
      expect(vm.motivoCompleto('Nadie abrió'), 'Nadie abrió');
      vm.elegirMotivo('No contestó');
      expect(vm.motivo, 'No contestó');
      expect(vm.motivoCompleto('Nadie abrió'), 'No contestó: Nadie abrió');
      vm.elegirMotivo('Otro');
      expect(vm.motivoCompleto('Nadie abrió'), 'Nadie abrió');
    });

    test('marca la entrega como fallida y avisa al panel', () async {
      api.responder(_estado, {'success': true});
      final vm = armar()..elegirMotivo('Cliente ausente');
      final enviando = <bool>[];
      vm.addListener(() => enviando.add(vm.enviando));

      final r = await vm.reportar(' Nadie abrió ');

      expect(r.ok, isTrue);
      expect(enviando, [true, false]);
      expect(api.ultima(_estado)!.body, {
        'estado': 'fallida',
        'motivo_fallo': 'Cliente ausente: Nadie abrió',
      });
      expect(avisos, 1);
    });

    test('si el backend lo rechaza devuelve su mensaje', () async {
      api.responder(_estado, {'success': false});
      final r = await armar().reportar('Nadie abrió');
      expect(r, (ok: false, mensaje: 'No se pudo reportar'));
      expect(avisos, 0);
    });
  });
}
