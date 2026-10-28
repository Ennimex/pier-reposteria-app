// test/unitarias/reembolsos_quejas/refunds_view_model_test.dart — «Reembolsos» (MVVM, Fase 3) sin
// red: el repositorio tipa el historial y el envío, y el ViewModel lleva el
// historial, los pedidos reembolsables y el formulario.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_reposteria/domain/models/reembolso.dart';
import 'package:pier_reposteria/ui/refunds/view_model/refunds_view_model.dart';

import '../../fakes/fake_api_client.dart';

const String _mis = ApiConstants.misReembolsos;
const String _crear = ApiConstants.crearReembolso;
const String _pedidos = ApiConstants.misPedidos;
const String _subir = ApiConstants.uploadImagen;

final Map<String, dynamic> _conDatos = {
  _mis: {
    'success': true,
    'reembolsos': [
      {
        'id': 3,
        'pedido_id': 9,
        'pedido_numero': 'PIER-9',
        'monto': '640.00',
        'motivo': 'producto_danado',
        'estado': 'en_revision',
        'respuesta_admin': 'Lo estamos revisando',
        'created_at': '2026-10-01T18:00:00Z',
      },
      {'id': 4, 'pedido_id': 12, 'estado': 'raro', 'respuesta_admin': ''},
      'basura',
    ],
  },
  _pedidos: {
    'success': true,
    'pedidos': [
      {'id': 9, 'numero': 'PIER-9', 'estado': 'completado', 'total': '640'},
      {'id': 10, 'numero': 'PIER-10', 'estado': 'entregado', 'total': '300'},
      {'id': 11, 'numero': 'PIER-11', 'estado': 'completado', 'total': '150'},
    ],
  },
  _crear: {'success': true, 'reembolso': {'id': 5}},
};

/// Sube cada archivo a `https://cdn/` + su nombre.
Map<String, dynamic> _subida(LlamadaApi l) {
  final ruta = l.body!['filePath'].toString();
  return {
    'success': true,
    'imagen': {'url': 'https://cdn/${ruta.split('/').last}'},
  };
}

RefundsViewModel _vm(FakeApiClient api) => RefundsViewModel(
      reembolsosRepo: ReembolsosRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
    );

void main() {
  // Regresión de #118: la solicitud mandaba el motivo como texto y el
  // backend la rechazaba; ahora manda el código del ENUM.
  group('Motivos (#118)', () {
    test('son los códigos del ENUM motivo_reembolso, como en la web', () {
      expect(RefundsViewModel.motivos.keys, [
        'producto_danado',
        'no_satisfecho',
        'pedido_incorrecto',
        'tardanza',
        'cantidad_incorrecta',
        'otro',
      ]);
      expect(RefundsViewModel.motivos['tardanza'], 'Tardanza en preparación');
    }, tags: 'regresion');

    test('el texto traduce el código; uno desconocido se muestra tal cual',
        () {
      // El reembolso automático de una cancelación llega con 'otro'.
      expect(Reembolso.fromJson({'motivo': 'otro'}).motivoTexto, 'Otro motivo');
      expect(Reembolso.fromJson({'motivo': 'raro'}).motivoTexto, 'raro');
    }, tags: 'regresion');
  });

  group('Reembolso y repositorio', () {
    test('listarMisReembolsos tipa, tolera faltantes e ignora basura',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);

      final lista = await ReembolsosRepositoryRemote(api: api).listarMisReembolsos();

      expect(lista, hasLength(2));
      final r = lista.first;
      expect(r.pedidoNumero, 'PIER-9');
      expect(r.monto, 640);
      expect(r.estado, EstadoReembolso.enRevision);
      expect(r.respuestaAdmin, 'Lo estamos revisando');
      expect(r.creadoEn, isNotNull);
      expect(r.motivo, 'producto_danado');
      expect(r.motivoTexto, 'Producto dañado');
      // Sin número usa el id del pedido; estado desconocido = pendiente;
      // respuesta vacía = sin respuesta.
      expect(lista[1].pedidoNumero, '12');
      expect(lista[1].estado, EstadoReembolso.pendiente);
      expect(lista[1].respuestaAdmin, isNull);
      expect(lista[1].motivo, isNull);
      expect(lista[1].motivoTexto, isNull);
      expect(api.llamo(_mis, metodo: 'GET-Auth'), isTrue);
    });

    test('listarMisReembolsos lanza ApiException si falla', () async {
      final api = FakeApiClient()..fallar(_mis, 'Token expirado');

      expect(() => ReembolsosRepositoryRemote(api: api).listarMisReembolsos(),
          throwsA(isA<ApiException>()));
    });

    test('solicitar manda el id numérico y lanza el mensaje del backend',
        () async {
      final api = FakeApiClient()
        ..fallar(_crear, 'Solo se pueden reembolsar pedidos completados');
      final repo = ReembolsosRepositoryRemote(api: api);

      await expectLater(
        repo.solicitar(
          pedidoId: '9',
          monto: 640,
          motivo: 'otro',
          descripcion: 'Llegó aplastado',
        ),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Solo se pueden reembolsar pedidos completados')),
      );
      expect(api.ultima(_crear)?.body, {
        'pedido_id': 9,
        'monto': 640.0,
        'motivo': 'otro',
        'descripcion': 'Llegó aplastado',
      });
    });
  });

  group('Fotos de evidencia: modelo y repositorio (#117)', () {
    test('el historial trae las fotos guardadas; sin fotos queda vacío', () {
      final con = Reembolso.fromJson({
        'id': 1,
        'fotos_evidencia': ['https://cdn/a.jpg', 7, '', 'https://cdn/b.jpg'],
      });
      final sin = Reembolso.fromJson({'id': 2, 'fotos_evidencia': null});

      expect(con.fotos, ['https://cdn/a.jpg', 'https://cdn/b.jpg']);
      expect(sin.fotos, isEmpty);
    });

    test('subirEvidencia sube como «reembolso» y devuelve la URL', () async {
      final api = FakeApiClient()
        ..responder(_subir, {
          'success': true,
          'imagen': {'url': 'https://cdn/f.jpg'},
        });
      final repo = ReembolsosRepositoryRemote(api: api);

      expect(await repo.subirEvidencia('/tmp/f.jpg'), 'https://cdn/f.jpg');
      expect(api.ultima(_subir)!.body,
          {'filePath': '/tmp/f.jpg', 'tipo': 'reembolso'});

      api.responder(_subir, {'success': true});
      await expectLater(repo.subirEvidencia('/tmp/f.jpg'),
          throwsA(isA<ApiException>()));
    });

    test('solicitar manda fotos_evidencia solo si hay fotos', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final repo = ReembolsosRepositoryRemote(api: api);

      await repo.solicitar(
        pedidoId: '9',
        monto: 640,
        motivo: 'producto_danado',
        descripcion: 'Llegó aplastado',
        fotos: const ['https://cdn/a.jpg', 'https://cdn/b.jpg'],
      );

      expect(api.ultima(_crear)?.body, {
        'pedido_id': 9,
        'monto': 640.0,
        'motivo': 'producto_danado',
        'descripcion': 'Llegó aplastado',
        'fotos_evidencia': ['https://cdn/a.jpg', 'https://cdn/b.jpg'],
      });
    });
  });

  group('RefundsViewModel: fotos de evidencia (#117)', () {
    test('admite hasta 3 fotos y se pueden quitar', () {
      final vm = _vm(FakeApiClient())
        ..agregarFoto('/fotos/1.jpg')
        ..agregarFoto('/fotos/2.jpg')
        ..agregarFoto('/fotos/3.jpg');
      expect(vm.puedeAgregarFoto, isFalse);

      vm.agregarFoto('/fotos/4.jpg');
      expect(vm.fotos, ['/fotos/1.jpg', '/fotos/2.jpg', '/fotos/3.jpg']);

      vm.quitarFoto('/fotos/2.jpg');
      expect(vm.fotos, ['/fotos/1.jpg', '/fotos/3.jpg']);
      expect(vm.puedeAgregarFoto, isTrue);
    });

    test('sube cada foto, la manda con la solicitud y limpia', () async {
      final api = FakeApiClient(respuestas: {..._conDatos, _subir: _subida});
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarMotivo('producto_danado')
        ..agregarFoto('/fotos/1.jpg')
        ..agregarFoto('/fotos/2.jpg');

      final error = await vm.enviar(descripcion: 'Llegó aplastado');

      expect(error, isNull);
      expect(
          api.llamadas
              .where((l) => l.endpoint == _subir)
              .map((l) => l.body!['tipo']),
          ['reembolso', 'reembolso']);
      expect(api.ultima(_crear)?.body?['fotos_evidencia'],
          ['https://cdn/1.jpg', 'https://cdn/2.jpg']);
      expect(vm.fotos, isEmpty);
    });

    test('si una foto no sube no manda la solicitud y conserva las fotos',
        () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_subir, 'Error al subir imagen');
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarMotivo('otro')
        ..agregarFoto('/fotos/1.jpg');

      final error = await vm.enviar(descripcion: 'Llegó aplastado');

      expect(error, 'No se pudo subir una de las fotos. Intenta de nuevo.');
      expect(api.llamo(_crear), isFalse);
      expect(vm.fotos, ['/fotos/1.jpg']);
      expect(vm.enviando, isFalse);
    });

    test('al reintentar no vuelve a subir las fotos que ya subieron',
        () async {
      final api = FakeApiClient(respuestas: {..._conDatos, _subir: _subida})
        ..fallar(_crear, 'Pedido no encontrado');
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarMotivo('otro')
        ..agregarFoto('/fotos/1.jpg');

      expect(await vm.enviar(descripcion: 'Llegó aplastado'),
          'Pedido no encontrado');
      api.responder(_crear, {'success': true});
      expect(await vm.enviar(descripcion: 'Llegó aplastado'), isNull);

      expect(api.llamadas.where((l) => l.endpoint == _subir).length, 1);
      expect(api.ultima(_crear)?.body?['fotos_evidencia'],
          ['https://cdn/1.jpg']);
    });
  });

  group('RefundsViewModel', () {
    test('carga el historial y los pedidos recogidos o entregados (#172)',
        () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      expect(vm.cargandoReembolsos, isTrue);

      await vm.cargar();

      expect(vm.cargandoReembolsos, isFalse);
      expect(vm.reembolsos, hasLength(2));
      expect(vm.pedidos.map((p) => p.numero), ['PIER-9', 'PIER-10', 'PIER-11']);
    });

    test('un pedido con solicitud viva no se ofrece; uno rechazado sí (#172)',
        () async {
      final vm = _vm(FakeApiClient(respuestas: {
        ..._conDatos,
        _pedidos: {
          'success': true,
          'pedidos': [
            for (final (id, estado) in [
              (1, 'pendiente'),
              (2, 'en_revision'),
              (3, 'aprobado'),
              (4, 'procesado'),
              (5, 'rechazado'),
            ])
              {
                'id': id,
                'numero': 'PIER-$id',
                'estado': 'entregado',
                'total': '100',
                'reembolso': {'id': id * 10, 'estado': estado, 'monto': '100'},
              },
            {'id': 6, 'numero': 'PIER-6', 'estado': 'en_camino', 'total': '9'},
          ],
        },
      }));

      await vm.cargar();

      expect(vm.pedidos.map((p) => p.numero), ['PIER-5']);
      expect(vm.pedidos.single.reembolso?.monto, 100);
    });

    test('si el backend responde que ya hay solicitud, el pedido se quita',
        () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_crear,
            'Este pedido ya tiene una solicitud de reembolso (pendiente)');
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarPedido(vm.pedidos[1])
        ..seleccionarMotivo('otro');
      api.responder(_pedidos, {
        'success': true,
        'pedidos': [
          {'id': 9, 'numero': 'PIER-9', 'estado': 'completado', 'total': '640'},
          {
            'id': 10,
            'numero': 'PIER-10',
            'estado': 'entregado',
            'total': '300',
            'reembolso': {'id': 7, 'estado': 'pendiente', 'monto': '300'},
          },
        ],
      });

      final error = await vm.enviar(descripcion: 'Llegó aplastado');
      await Future<void>.delayed(Duration.zero);

      expect(error,
          'Este pedido ya tiene una solicitud de reembolso (pendiente)');
      expect(api.llamadas.where((l) => l.endpoint == _crear), hasLength(1));
      expect(vm.pedidos.map((p) => p.numero), ['PIER-9']);
      expect(vm.pedidoSeleccionado?.numero, 'PIER-9');
    });

    test('sin elegir, el pedido seleccionado es el primero', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      await vm.cargar();

      expect(vm.pedidoSeleccionado?.numero, 'PIER-9');

      vm.seleccionarPedido(vm.pedidos.last);
      expect(vm.pedidoSeleccionado?.numero, 'PIER-11');
    });

    test('sin pedidos completados no hay seleccionado y no envía', () async {
      final api = FakeApiClient(respuestas: {
        ..._conDatos,
        _pedidos: {'success': true, 'pedidos': <Object>[]},
      });
      final vm = _vm(api);
      await vm.cargar();
      vm.seleccionarMotivo('otro');

      expect(vm.pedidoSeleccionado, isNull);
      expect(await vm.enviar(descripcion: 'Llegó aplastado'),
          'Selecciona un pedido');
      expect(api.llamo(_crear), isFalse);
    });

    // Regresión de #118: el cuerpo lleva el código del motivo, no su texto.
    test('envía por el total del pedido, limpia y recarga el historial',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarPedido(vm.pedidos.last)
        ..seleccionarMotivo('cantidad_incorrecta');
      final antes = api.llamadas.where((l) => l.endpoint == _mis).length;

      final error = await vm.enviar(descripcion: '  Faltó un pay  ');
      await Future<void>.delayed(Duration.zero);

      expect(error, isNull);
      expect(api.ultima(_crear)?.body, {
        'pedido_id': 11,
        'monto': 150.0,
        'motivo': 'cantidad_incorrecta',
        'descripcion': 'Faltó un pay',
      });
      expect(vm.enviando, isFalse);
      expect(vm.motivo, isNull);
      expect(vm.pedidoSeleccionado?.numero, 'PIER-9'); // vuelve al primero
      expect(api.llamadas.where((l) => l.endpoint == _mis).length, antes + 1);
    }, tags: 'regresion');

    test('si el backend rechaza devuelve su mensaje y conserva el formulario',
        () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_crear, 'Pedido no encontrado');
      final vm = _vm(api);
      await vm.cargar();
      vm.seleccionarMotivo('otro');

      final error = await vm.enviar(descripcion: 'Llegó aplastado');

      expect(error, 'Pedido no encontrado');
      expect(vm.enviando, isFalse);
      expect(vm.motivo, 'otro');
    });

    test('si falla la recarga se queda el historial anterior', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();

      api.fallar(_mis, 'Caído');
      await vm.cargarReembolsos();

      expect(vm.reembolsos, hasLength(2));
      expect(vm.cargandoReembolsos, isFalse);
    });
  });
}
