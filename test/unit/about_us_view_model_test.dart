// test/unit/about_us_view_model_test.dart — «Nosotros» (MVVM, Fase 3) sin red:
// el repositorio interpreta configuracion/nosotros y el ViewModel mezcla lo
// capturado en el panel con los textos por defecto.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/ui/public/view_model/about_us_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _endpoint = ApiConstants.configuracionSeccion('nosotros');

FakeApiClient _backendCon(Map<String, dynamic> config) => FakeApiClient(
      respuestas: {
        _endpoint: {'success': true, 'config': config},
      },
    );

AboutUsViewModel _vm(FakeApiClient api) => AboutUsViewModel(
      repo: ConfiguracionRepository(api: api),
      anioActual: 2026,
    );

void main() {
  group('ConfiguracionRepository.nosotros', () {
    test('lee historia, valores y estadísticas aunque lleguen como JSON',
        () async {
      final api = _backendCon({
        'historia':
            '{"titulo":"Desde 2015","contenido":"Hornear es lo nuestro","fundacion":"2015"}',
        'mision': 'Endulzar Huejutla',
        'valores': '["Calidad","  ","Amor"]',
        'estadisticas': [
          {'numero': '+ 10k', 'label': 'Pasteles'},
          {'numero': '', 'label': 'Vacía'},
          'no es mapa',
        ],
      });

      final info = await ConfiguracionRepository(api: api).nosotros();

      expect(info.historiaTitulo, 'Desde 2015');
      expect(info.historia, 'Hornear es lo nuestro');
      expect(info.anioFundacion, 2015);
      expect(info.mision, 'Endulzar Huejutla');
      expect(info.vision, isNull);
      expect(info.valores, ['Calidad', 'Amor']);
      expect(info.estadisticas, [('+ 10k', 'Pasteles')]);
      expect(api.llamo(_endpoint, metodo: 'GET'), isTrue);
    });

    test('historia como texto plano va al contenido', () async {
      final info = await ConfiguracionRepository(
        api: _backendCon({'historia': 'Solo texto'}),
      ).nosotros();
      expect(info.historia, 'Solo texto');
      expect(info.historiaTitulo, isNull);
    });

    test('si el backend falla lanza ApiException', () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sección no encontrada');
      await expectLater(
        ConfiguracionRepository(api: api).nosotros(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('AboutUsViewModel', () {
    test('antes de cargar muestra los textos por defecto', () {
      final vm = _vm(FakeApiClient());
      expect(vm.historiaTitulo, 'Nuestra Historia');
      expect(vm.valores, hasLength(4));
      expect(vm.valoresDelPanel, isFalse);
      expect(vm.stats, [
        ('100%', 'Artesanal'),
        ('+ 5 años', 'Experiencia'),
        ('❤️', 'Con amor'),
      ]);
    });

    test('lo capturado en el panel reemplaza solo esos campos', () async {
      final vm = _vm(
        _backendCon({
          'mision': 'Endulzar Huejutla',
          'valores': ['Calidad', 'Amor'],
        }),
      );

      await vm.cargar();

      expect(vm.mision, 'Endulzar Huejutla');
      expect(vm.historiaTitulo, 'Nuestra Historia');
      expect(vm.valores, ['Calidad', 'Amor']);
      expect(vm.valoresDelPanel, isTrue);
    });

    test('sin estadísticas calcula los años desde la fundación', () async {
      final vm = _vm(
        _backendCon({
          'historia': {'fundacion': '2015'},
        }),
      );

      await vm.cargar();

      expect(vm.stats[1], ('+ 11 años', 'Experiencia'));
    });

    test('muestra como máximo 4 estadísticas', () async {
      final vm = _vm(
        _backendCon({
          'estadisticas': [
            for (var i = 1; i <= 6; i++) {'numero': '$i', 'label': 'L$i'},
          ],
        }),
      );

      await vm.cargar();

      expect(vm.stats, hasLength(4));
      expect(vm.stats.last, ('4', 'L4'));
    });

    test('si el backend falla se quedan los textos por defecto', () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sin conexión');
      final vm = _vm(api);
      var avisos = 0;
      vm.addListener(() => avisos++);

      await vm.cargar();

      expect(vm.historiaTitulo, 'Nuestra Historia');
      expect(avisos, 0);
    });
  });
}
