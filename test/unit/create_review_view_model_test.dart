// test/unit/create_review_view_model_test.dart — «Escribir reseña» (MVVM,
// Fase 3) sin red: el repositorio manda POST /resenas y el ViewModel valida
// y envía.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/create_review_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _endpoint = ApiConstants.crearResena;

FakeApiClient _backend({bool autoAprobada = true}) => FakeApiClient(
      respuestas: {
        _endpoint: {
          'success': true,
          'resena': {'id': 9, 'auto_aprobada': autoAprobada},
        },
      },
    );

CreateReviewViewModel _vm(FakeApiClient api) =>
    CreateReviewViewModel(repo: ResenasRepositoryRemote(api: api), productoId: '36');

void main() {
  group('ResenasRepository.crearResena', () {
    test('manda el cuerpo autenticado y devuelve auto_aprobada', () async {
      final api = _backend();

      final publicada = await ResenasRepositoryRemote(api: api).crearResena(
        productoId: '36',
        rating: 5,
        titulo: '',
        comentario: 'Delicioso pastel',
      );

      expect(publicada, isTrue);
      final llamada = api.ultima(_endpoint)!;
      expect(llamada.metodo, 'POST-Auth');
      expect(llamada.body, {
        'producto_id': '36',
        'rating': 5,
        'titulo': '',
        'comentario': 'Delicioso pastel',
      });
    });

    test('en revisión devuelve false', () async {
      final publicada =
          await ResenasRepositoryRemote(api: _backend(autoAprobada: false))
              .crearResena(
        productoId: '36',
        rating: 4,
        titulo: 'Rico',
        comentario: 'Muy rico todo',
      );
      expect(publicada, isFalse);
    });

    test('si el backend falla lanza ApiException con su mensaje', () async {
      final api = FakeApiClient()
        ..fallar(_endpoint, 'Ya dejaste una reseña para este producto');
      await expectLater(
        ResenasRepositoryRemote(api: api).crearResena(
          productoId: '36',
          rating: 5,
          titulo: '',
          comentario: 'Delicioso pastel',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Ya dejaste una reseña para este producto',
          ),
        ),
      );
    });
  });

  group('CreateReviewViewModel', () {
    test('lleva calificación y largo del comentario sin espacios', () {
      final vm = _vm(FakeApiClient())
        ..calificar(4)
        ..editarComentario('   corto   ');
      expect(vm.rating, 4);
      expect(vm.largoComentario, 5);
      expect(vm.comentarioValido, isFalse);

      vm.editarComentario('Diez letras');
      expect(vm.comentarioValido, isTrue);
    });

    test('sin calificación no envía', () async {
      final api = _backend();
      final vm = _vm(api)..editarComentario('Delicioso pastel');

      expect(await vm.enviar(titulo: ''), isNull);
      expect(vm.error, 'Selecciona una calificación');
      expect(api.llamadas, isEmpty);
    });

    test('con comentario corto no envía', () async {
      final api = _backend();
      final vm = _vm(api)
        ..calificar(5)
        ..editarComentario('Rico');

      expect(await vm.enviar(titulo: ''), isNull);
      expect(vm.error, 'El comentario debe tener al menos 10 caracteres');
      expect(api.llamadas, isEmpty);
    });

    test('envía recortado y devuelve si quedó publicada', () async {
      final api = _backend(autoAprobada: false);
      final vm = _vm(api)
        ..calificar(5)
        ..editarComentario('  Delicioso pastel  ');

      final publicada = await vm.enviar(titulo: '  Rico  ');

      expect(publicada, isFalse);
      expect(vm.error, isNull);
      expect(vm.enviando, isFalse);
      expect(api.ultima(_endpoint)!.body, {
        'producto_id': '36',
        'rating': 5,
        'titulo': 'Rico',
        'comentario': 'Delicioso pastel',
      });
    });

    test('si el backend falla devuelve null con su mensaje', () async {
      final api = FakeApiClient()
        ..fallar(_endpoint, 'Ya dejaste una reseña para este producto');
      final vm = _vm(api)
        ..calificar(5)
        ..editarComentario('Delicioso pastel');

      expect(await vm.enviar(titulo: ''), isNull);
      expect(vm.error, 'Ya dejaste una reseña para este producto');
      expect(vm.enviando, isFalse);
    });
  });
}
