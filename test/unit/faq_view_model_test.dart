// test/unit/faq_view_model_test.dart — «Preguntas Frecuentes» (MVVM, Fase 3)
// sin red: el repositorio interpreta configuracion/faq y el ViewModel reemplaza
// las preguntas por defecto y filtra por categoría.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/ui/public/view_model/faq_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _endpoint = ApiConstants.configuracionSeccion('faq');

FakeApiClient _backendCon(Object? preguntas) => FakeApiClient(
      respuestas: {
        _endpoint: {
          'success': true,
          'config': {'preguntas': preguntas},
        },
      },
    );

FaqViewModel _vm(FakeApiClient api) =>
    FaqViewModel(repo: ConfiguracionRepository(api: api));

void main() {
  group('ConfiguracionRepository.faq', () {
    test('lee preguntas aunque lleguen como JSON y descarta incompletas',
        () async {
      final api = _backendCon(
        '[{"categoria":"Envíos","pregunta":"¿Llegan?","respuesta":"Sí"}, '
        '{"pregunta":"Sin categoría","respuesta":"Va a General"}, '
        '{"pregunta":"  ","respuesta":"Vacía"}, '
        '{"pregunta":"Sin respuesta"}, '
        '"no es mapa"]',
      );

      final lista = await ConfiguracionRepository(api: api).faq();

      expect(lista.map((p) => (p.categoria, p.pregunta, p.respuesta)), [
        ('Envíos', '¿Llegan?', 'Sí'),
        ('General', 'Sin categoría', 'Va a General'),
      ]);
      expect(api.llamo(_endpoint, metodo: 'GET'), isTrue);
    });

    test('sin preguntas capturadas devuelve lista vacía', () async {
      final lista =
          await ConfiguracionRepository(api: _backendCon(null)).faq();
      expect(lista, isEmpty);
    });

    test('si el backend falla lanza ApiException', () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sección no encontrada');
      await expectLater(
        ConfiguracionRepository(api: api).faq(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('FaqViewModel', () {
    test('arranca con las preguntas y categorías por defecto', () {
      final vm = _vm(FakeApiClient());
      expect(vm.categorias, [
        'Todas',
        'Pedidos',
        'Pagos',
        'Devoluciones',
        'Seguridad',
        'Ubicación',
      ]);
      expect(vm.filtradas, hasLength(9));
      expect(vm.categoriaSeleccionada, FaqViewModel.todas);
    });

    test('filtra por categoría y avisa a la vista', () {
      final vm = _vm(FakeApiClient());
      var avisos = 0;
      vm
        ..addListener(() => avisos++)
        ..seleccionarCategoria('Devoluciones');

      expect(vm.filtradas, hasLength(3));
      expect(vm.filtradas.every((p) => p.categoria == 'Devoluciones'), isTrue);
      expect(avisos, 1);

      vm.seleccionarCategoria('Devoluciones');
      expect(avisos, 1, reason: 'misma categoría no repinta');
    });

    test('las preguntas del panel reemplazan a las de la app', () async {
      final vm = _vm(
        _backendCon([
          {'categoria': 'Envíos', 'pregunta': '¿Llegan?', 'respuesta': 'Sí'},
          {'categoria': 'Pagos', 'pregunta': '¿Tarjeta?', 'respuesta': 'Sí'},
        ]),
      );
      await vm.cargar();

      expect(vm.categorias, ['Todas', 'Pagos', 'Envíos']);
      expect(vm.filtradas.map((p) => p.pregunta), ['¿Llegan?', '¿Tarjeta?']);
    });

    test('si la categoría elegida ya no existe vuelve a Todas', () async {
      final vm = _vm(
        _backendCon([
          {'categoria': 'Envíos', 'pregunta': '¿Llegan?', 'respuesta': 'Sí'},
        ]),
      )..seleccionarCategoria('Seguridad');
      await vm.cargar();

      expect(vm.categoriaSeleccionada, FaqViewModel.todas);
      expect(vm.filtradas, hasLength(1));
    });

    test('si el backend falla se quedan las preguntas por defecto', () async {
      final vm = _vm(FakeApiClient()..fallar(_endpoint, 'Sin conexión'));
      await vm.cargar();
      expect(vm.filtradas, hasLength(9));
    });

    test('panel sin preguntas conserva las de la app', () async {
      final vm = _vm(_backendCon([]));
      await vm.cargar();
      expect(vm.filtradas, hasLength(9));
    });
  });
}
