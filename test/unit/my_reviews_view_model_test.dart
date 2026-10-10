// test/unit/my_reviews_view_model_test.dart — «Mis Reseñas» (MVVM, Fase 3)
// sin red: el repositorio tipa /resenas/mis-resenas y edita, y el ViewModel
// lleva la lista y la edición.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/mi_resena.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/my_reviews_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _lista = ApiConstants.misResenas;
final String _editar7 = ApiConstants.editarResena('7');

final List<Object> _dos = [
  {
    'id': 7,
    'rating': '4.0',
    'titulo': 'Rico',
    'comentario': 'Muy esponjoso',
    'estado': 'aprobada',
    'producto_nombre': 'Fresa Matcha Bliss',
    'created_at': '2026-10-08T12:00:00Z',
    'respuesta_negocio': '¡Gracias!',
  },
  {
    'id': 8,
    'rating': 2,
    'comentario': 'Llegó tarde',
    'estado': 'rechazada',
    'motivo_rechazo': 'Lenguaje inapropiado',
    'respuesta_negocio': '',
  },
];

FakeApiClient _backendCon(List<Object> resenas) => FakeApiClient(
      respuestas: {
        _lista: {'success': true, 'resenas': resenas},
      },
    );

MyReviewsViewModel _vm(FakeApiClient api) =>
    MyReviewsViewModel(repo: ResenasRepositoryRemote(api: api));

void main() {
  group('MiResena.fromJson', () {
    test('tipa los campos y tolera textos vacíos', () {
      final a = MiResena.fromJson(_dos[0] as Map<String, dynamic>);
      expect(a.id, '7');
      expect(a.rating, 4);
      expect(a.estrellas, 4);
      expect(a.estado, EstadoResena.aprobada);
      expect(a.creadaEn, isNotNull);
      expect(a.respuestaNegocio, '¡Gracias!');

      final b = MiResena.fromJson(_dos[1] as Map<String, dynamic>);
      expect(b.titulo, '');
      expect(b.estado, EstadoResena.rechazada);
      expect(b.motivoRechazo, 'Lenguaje inapropiado');
      expect(b.respuestaNegocio, isNull);
      expect(b.creadaEn, isNull);
    });

    test('un estado desconocido queda en revisión', () {
      final r = MiResena.fromJson({'id': 1, 'estado': 'pendiente'});
      expect(r.estado, EstadoResena.enRevision);
      expect(r.estrellas, 0);
    });
  });

  group('ResenasRepository', () {
    test('listarMisResenas tipa e ignora lo que no es objeto', () async {
      final api = _backendCon([..._dos, 'basura']);

      final lista = await ResenasRepositoryRemote(api: api).listarMisResenas();

      expect(lista.map((r) => r.id), ['7', '8']);
      expect(api.llamo(_lista, metodo: 'GET-Auth'), isTrue);
    });

    test('listarMisResenas lanza ApiException si el backend falla', () async {
      final api = FakeApiClient()..fallar(_lista, 'Token expirado');
      await expectLater(
        ResenasRepositoryRemote(api: api).listarMisResenas(),
        throwsA(isA<ApiException>()),
      );
    });

    test('editarResena manda los campos y devuelve el mensaje', () async {
      final api = FakeApiClient(
        respuestas: {
          _editar7: {'success': true, 'message': 'Reseña editada'},
        },
      );

      final mensaje = await ResenasRepositoryRemote(api: api).editarResena(
        id: '7',
        rating: 5,
        titulo: 'Riquísimo',
        comentario: 'Lo volvería a pedir',
      );

      expect(mensaje, 'Reseña editada');
      final llamada = api.ultima(_editar7)!;
      expect(llamada.metodo, 'PUT-Auth');
      expect(llamada.body, {
        'rating': 5,
        'titulo': 'Riquísimo',
        'comentario': 'Lo volvería a pedir',
      });
    });

    test('editarResena lanza ApiException con el mensaje del backend',
        () async {
      final api = FakeApiClient()..fallar(_editar7, 'No es tu reseña');
      await expectLater(
        ResenasRepositoryRemote(api: api)
            .editarResena(id: '7', rating: 3, titulo: '', comentario: 'x'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'No es tu reseña'),
        ),
      );
    });
  });

  group('MyReviewsViewModel', () {
    test('arranca cargando y sin reseñas', () {
      final vm = _vm(FakeApiClient());
      expect(vm.cargando, isTrue);
      expect(vm.resenas, isEmpty);
    });

    test('carga la lista', () async {
      final vm = _vm(_backendCon(_dos));
      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.resenas, hasLength(2));
    });

    test('la recarga silenciosa no pasa por cargando', () async {
      final vm = _vm(_backendCon(_dos));
      await vm.cargar();
      final estados = <bool>[];
      vm.addListener(() => estados.add(vm.cargando));

      await vm.cargar(silenciosa: true);

      expect(estados, [false]);
    });

    test('si el backend falla conserva la última lista', () async {
      final api = _backendCon(_dos);
      final vm = _vm(api);
      await vm.cargar();
      api.fallar(_lista, 'Sin conexión');

      await vm.cargar();

      expect(vm.resenas, hasLength(2));
      expect(vm.cargando, isFalse);
    });

    test('editar devuelve el mensaje y recarga la lista', () async {
      final api = _backendCon(_dos)
        ..responder(_editar7, {'success': true, 'message': 'Reseña editada'});
      final vm = _vm(api);
      await vm.cargar();

      final mensaje = await vm.editar(
        vm.resenas.first,
        rating: 5,
        titulo: '',
        comentario: 'Mejor que nunca',
      );
      await pumpEventQueue();

      expect(mensaje, 'Reseña editada');
      expect(api.llamadas.where((l) => l.endpoint == _lista), hasLength(2));
    });

    test('si editar falla devuelve el error y no recarga', () async {
      final api = _backendCon(_dos)..fallar(_editar7, 'No es tu reseña');
      final vm = _vm(api);
      await vm.cargar();

      final mensaje = await vm.editar(
        vm.resenas.first,
        rating: 1,
        titulo: '',
        comentario: 'x',
      );
      await pumpEventQueue();

      expect(mensaje, 'No es tu reseña');
      expect(api.llamadas.where((l) => l.endpoint == _lista), hasLength(1));
    });
  });
}
