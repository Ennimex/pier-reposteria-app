// test/unit/edit_profile_view_model_test.dart — «Editar Perfil» (MVVM, Fase 3)
// sin red: el repositorio manda PUT /usuarios/perfil/actualizar y el ViewModel
// lleva cambios, iniciales y el guardado.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_pasteleria/ui/more/view_model/edit_profile_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _endpoint = ApiConstants.updateProfileData;

const Map<String, dynamic> _sesion = {
  'id': 7,
  'nombre': 'Ana',
  'apellido': 'López',
  'email': 'ana@pier.mx',
  'telefono': null,
};

FakeApiClient _backendOk() => FakeApiClient(
      respuestas: {
        _endpoint: {
          'success': true,
          'user': {..._sesion, 'nombre': 'Ana María', 'telefono': '7711234567'},
        },
      },
    );

EditProfileViewModel _vm(FakeApiClient api) => EditProfileViewModel(
      repo: CuentaRepositoryRemote(api: api),
      usuario: _sesion,
    );

void main() {
  group('CuentaRepository.actualizarPerfil', () {
    test('manda los 3 campos autenticado y devuelve el user', () async {
      final api = _backendOk();

      final user = await CuentaRepositoryRemote(api: api)
          .actualizarPerfil(nombre: 'Ana María', apellido: 'López');

      expect(user['nombre'], 'Ana María');
      final llamada = api.ultima(_endpoint)!;
      expect(llamada.metodo, 'PUT-Auth');
      expect(llamada.body, {
        'nombre': 'Ana María',
        'apellido': 'López',
        'telefono': null,
      });
    });

    test('si el backend falla lanza ApiException con su mensaje', () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Token inválido');
      await expectLater(
        CuentaRepositoryRemote(api: api)
            .actualizarPerfil(nombre: 'Ana', apellido: ''),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Token inválido'),
        ),
      );
    });
  });

  group('EditProfileViewModel', () {
    test('arranca con la sesión, sin cambios', () {
      final vm = _vm(FakeApiClient());
      expect(vm.nombre, 'Ana');
      expect(vm.telefono, '');
      expect(vm.email, 'ana@pier.mx');
      expect(vm.iniciales, 'AL');
      expect(vm.hayCambios, isFalse);
    });

    test('detecta cambios ignorando espacios y al volver al original', () {
      final vm = _vm(FakeApiClient())
        ..editar(nombre: ' Ana ', apellido: 'López', telefono: '');
      expect(vm.hayCambios, isFalse);

      vm.editar(nombre: 'Beto', apellido: '', telefono: '');
      expect(vm.hayCambios, isTrue);
      expect(vm.iniciales, 'B');

      vm.editar(nombre: 'Ana', apellido: 'López', telefono: '');
      expect(vm.hayCambios, isFalse);
    });

    test('sin nombre ni apellido las iniciales son U', () {
      final vm = _vm(FakeApiClient())
        ..editar(nombre: '', apellido: ' ', telefono: '');
      expect(vm.iniciales, 'U');
    });

    test('guardar recorta, devuelve el user y limpia los cambios', () async {
      final api = _backendOk();
      final vm = _vm(api)
        ..editar(nombre: ' Ana María ', apellido: 'López', telefono: ' 7711234567 ');

      final user = await vm.guardar();

      expect(user?['nombre'], 'Ana María');
      expect(api.ultima(_endpoint)!.body, {
        'nombre': 'Ana María',
        'apellido': 'López',
        'telefono': '7711234567',
      });
      expect(vm.hayCambios, isFalse);
      expect(vm.guardando, isFalse);
      expect(vm.error, isNull);
    });

    test('si falla devuelve null, expone el error y conserva los cambios',
        () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Error al actualizar perfil');
      final vm = _vm(api)
        ..editar(nombre: 'Beto', apellido: 'López', telefono: '');

      final user = await vm.guardar();

      expect(user, isNull);
      expect(vm.error, 'Error al actualizar perfil');
      expect(vm.hayCambios, isTrue);
      expect(vm.guardando, isFalse);
    });
  });
}
