// test/unit/vincular_alexa_view_model_test.dart — ViewModel de «Vincular con
// Alexa» (MVVM, Fase 3) sin red. Las pruebas con cuenta regresiva corren en
// testWidgets para avanzar el reloj simulado con tester.pump(duración).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_pasteleria/ui/more/view_model/vincular_alexa_view_model.dart';

import '../fakes/fake_api_client.dart';

FakeApiClient _backendConCodigo({int? expira = 90}) => FakeApiClient(
      respuestas: {
        ApiConstants.alexaGenerarCodigo: {
          'success': true,
          'codigo': 482913,
          'expira_en_segundos': ?expira,
        },
      },
    );

VincularAlexaViewModel _vm(FakeApiClient api) =>
    VincularAlexaViewModel(repo: CuentaRepositoryRemote(api: api));

void main() {
  group('CuentaRepository.generarCodigoAlexa', () {
    test('devuelve el código tipado y va autenticado', () async {
      final api = _backendConCodigo();
      final codigo = await CuentaRepositoryRemote(api: api).generarCodigoAlexa();

      expect(codigo.codigo, '482913');
      expect(codigo.expiraEnSegundos, 90);
      expect(
        api.llamo(ApiConstants.alexaGenerarCodigo, metodo: 'POST-Auth'),
        isTrue,
      );
    });

    test('sin expira_en_segundos usa 5 minutos', () async {
      final codigo = await CuentaRepositoryRemote(api: _backendConCodigo(expira: null))
          .generarCodigoAlexa();
      expect(codigo.expiraEnSegundos, 300);
    });

    test('si el backend falla lanza ApiException con su mensaje', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.alexaGenerarCodigo, 'Token expirado');
      await expectLater(
        CuentaRepositoryRemote(api: api).generarCodigoAlexa(),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Token expirado'),
        ),
      );
    });

    test('success sin código también es error', () async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.alexaGenerarCodigo: {'success': true},
        },
      );
      await expectLater(
        CuentaRepositoryRemote(api: api).generarCodigoAlexa(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No se pudo generar el código',
          ),
        ),
      );
    });
  });

  group('VincularAlexaViewModel', () {
    testWidgets('generar expone el código y la cuenta regresiva',
        (tester) async {
      final vm = _vm(_backendConCodigo());

      await vm.generar();

      expect(vm.codigo, '482913');
      expect(vm.tiempoRestante, '1:30');
      expect(vm.generando, isFalse);
      expect(vm.error, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(vm.tiempoRestante, '1:29');

      // El reloj simulado exige cero timers vivos antes del tearDown.
      vm.dispose();
    });

    testWidgets('el código desaparece al expirar', (tester) async {
      final vm = _vm(_backendConCodigo(expira: 3));
      addTearDown(vm.dispose);

      await vm.generar();
      await tester.pump(const Duration(seconds: 2));
      expect(vm.codigo, isNotNull);

      await tester.pump(const Duration(seconds: 1));
      expect(vm.codigo, isNull);
      expect(vm.segundos, 0);
    });

    test('un fallo deja el mensaje en error y sin código', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.alexaGenerarCodigo, 'Sin conexión');
      final vm = _vm(api);
      addTearDown(vm.dispose);

      await vm.generar();

      expect(vm.error, 'Sin conexión');
      expect(vm.codigo, isNull);
      expect(vm.generando, isFalse);
    });

    test('mientras espera al backend generando es true', () async {
      final vm = _vm(_backendConCodigo());
      addTearDown(vm.dispose);

      final pendiente = vm.generar();
      expect(vm.generando, isTrue);
      await pendiente;
      expect(vm.generando, isFalse);
    });

    testWidgets('marcarCopiado dura 2 segundos', (tester) async {
      final vm = _vm(_backendConCodigo());
      addTearDown(vm.dispose);

      vm.marcarCopiado();
      expect(vm.copiado, isTrue);

      await tester.pump(const Duration(seconds: 2));
      expect(vm.copiado, isFalse);
    });

    test('si se cierra la pantalla antes de la respuesta no notifica',
        () async {
      final vm = _vm(_backendConCodigo());
      var avisos = 0;
      vm.addListener(() => avisos++);

      final pendiente = vm.generar(); // 1 aviso: generando = true
      vm.dispose();
      await pendiente;

      expect(avisos, 1);
    });
  });
}
