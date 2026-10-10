// test/unit/legal_view_model_test.dart — «Marco Legal» (MVVM, Fase 3) sin
// red: el parser arma las tarjetas, el repositorio interpreta
// configuracion/legales y el ViewModel reemplaza las secciones por defecto.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/textos_legales.dart';
import 'package:pier_pasteleria/ui/public/view_model/legal_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _endpoint = ApiConstants.configuracionSeccion('legales');

FakeApiClient _backendCon(Map<String, dynamic> config) => FakeApiClient(
      respuestas: {
        _endpoint: {'success': true, 'config': config},
      },
    );

LegalViewModel _vm(FakeApiClient api) =>
    LegalViewModel(repo: ConfiguracionRepositoryRemote(api: api));

List<(String, String)> _pares(List<SeccionLegal> s) =>
    s.map((x) => (x.titulo, x.contenido)).toList();

void main() {
  group('SeccionLegal.desdeTexto', () {
    test('un párrafo sin saltos se reparte por oración', () {
      final s = SeccionLegal.desdeTexto(
        'Vivimos en C.P. 43000 de Huejutla. ¿Dudas? Escríbenos. Gracias.',
      );
      expect(_pares(s), [
        ('', 'Vivimos en C.P. 43000 de Huejutla.'),
        ('', '¿Dudas?'),
        ('', 'Escríbenos.'),
        ('', 'Gracias.'),
      ]);
    });

    test('bloques con título corto, sin dos puntos finales', () {
      final s = SeccionLegal.desdeTexto(
        'Datos que recopilamos:\nNombre y correo.\r\n\r\n'
        '- Viñeta suelta\n- Otra viñeta\n\n'
        'Texto largo que termina en punto.\nSegunda línea.',
      );
      expect(_pares(s), [
        ('Datos que recopilamos', 'Nombre y correo.'),
        ('', '- Viñeta suelta\n- Otra viñeta'),
        ('', 'Texto largo que termina en punto.\nSegunda línea.'),
      ]);
    });

    test('sin líneas en blanco hace una tarjeta por línea', () {
      final s = SeccionLegal.desdeTexto('Primera línea\nSegunda línea');
      expect(_pares(s), [('', 'Primera línea'), ('', 'Segunda línea')]);
    });
  });

  group('ConfiguracionRepository.legales', () {
    test('lee los 3 textos; vacíos quedan en null', () async {
      final api = _backendCon({
        'privacidad': 'Cuidamos tus datos.',
        'terminos': '   ',
        'reembolsos': 'Mismo día.',
      });

      final t = await ConfiguracionRepositoryRemote(api: api).legales();

      expect(t.privacidad, 'Cuidamos tus datos.');
      expect(t.terminos, isNull);
      expect(t.reembolsos, 'Mismo día.');
      expect(api.llamo(_endpoint, metodo: 'GET'), isTrue);
    });

    test('si el backend falla lanza ApiException', () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Sección no encontrada');
      await expectLater(
        ConfiguracionRepositoryRemote(api: api).legales(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('LegalViewModel', () {
    test('arranca con las secciones por defecto', () {
      final vm = _vm(FakeApiClient());
      expect(vm.privacidad, hasLength(5));
      expect(vm.terminos, hasLength(4));
      expect(vm.devoluciones, hasLength(3));
    });

    test('el texto del panel reemplaza solo la pestaña capturada', () async {
      final vm = _vm(
        _backendCon({'privacidad': 'Uno. Dos.', 'reembolsos': 'Mismo día.'}),
      );
      var avisos = 0;
      vm.addListener(() => avisos++);
      await vm.cargar();

      expect(_pares(vm.privacidad), [('', 'Uno.'), ('', 'Dos.')]);
      expect(vm.terminos, hasLength(4));
      expect(vm.terminos.first.titulo, 'Proceso de Compra');
      expect(_pares(vm.devoluciones), [('', 'Mismo día.')]);
      expect(avisos, 1);
    });

    test('si el backend falla se quedan las secciones por defecto', () async {
      final vm = _vm(FakeApiClient()..fallar(_endpoint, 'Sin conexión'));
      await vm.cargar();
      expect(vm.privacidad.first.titulo, 'Responsable del Tratamiento');
    });
  });
}
